package com.anynomous.privacy_vpn_controller.services.security

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.*
import java.net.InetAddress
import java.net.SocketException
import java.util.concurrent.atomic.AtomicBoolean
import android.util.Log
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

/**
 * Kill Switch Manager - Advanced Network Protection
 * Blocks all traffic when VPN is not connected to prevent leaks
 */
class KillSwitchManager(private val context: Context) {
    
    companion object {
        private const val TAG = "KillSwitchManager"
        private const val CONNECTIVITY_CHECK_INTERVAL = 5000L // 5 seconds
        private const val MAX_ALLOWED_NETWORKS = 2 // VPN + Loopback
    }
    
    private val isKillSwitchEnabled = AtomicBoolean(false)
    private val isVpnConnected = AtomicBoolean(false)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val handler = Handler(Looper.getMainLooper())
    
    // Network monitoring
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var connectivityCheckJob: Job? = null
    private val allowedNetworks = ConcurrentHashMap<Network, Boolean>()
    
    // Kill switch state
    private val blockedConnections = ConcurrentHashMap<String, Long>()
    
    interface KillSwitchListener {
        fun onKillSwitchActivated(reason: String)
        fun onKillSwitchDeactivated()
        fun onTrafficBlocked(destination: String, reason: String)
        fun onNetworkLeakDetected(networkType: String)
    }
    
    private var listener: KillSwitchListener? = null

    /**
     * Enable kill switch protection
     */
    suspend fun enableKillSwitch(): Boolean {
        return withContext(Dispatchers.Main) {
            try {
                Log.i(TAG, "Enabling kill switch protection")
                
                if (isKillSwitchEnabled.get()) {
                    Log.w(TAG, "Kill switch already enabled")
                    return@withContext true
                }
                
                // Register network callback
                registerNetworkCallback()
                
                // Start connectivity monitoring
                startConnectivityMonitoring()
                
                // Block all traffic if VPN not connected
                if (!isVpnConnected.get()) {
                    activateKillSwitch("VPN not connected")
                }
                
                isKillSwitchEnabled.set(true)
                Log.i(TAG, "Kill switch enabled successfully")
                return@withContext true
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enable kill switch", e)
                return@withContext false
            }
        }
    }

    /**
     * Disable kill switch protection
     */
    suspend fun disableKillSwitch(): Boolean {
        return withContext(Dispatchers.Main) {
            try {
                Log.i(TAG, "Disabling kill switch protection")
                
                if (!isKillSwitchEnabled.get()) {
                    Log.w(TAG, "Kill switch already disabled")
                    return@withContext true
                }
                
                // Stop monitoring
                stopConnectivityMonitoring()
                
                // Unregister network callback
                unregisterNetworkCallback()
                
                // Deactivate kill switch
                deactivateKillSwitch()
                
                isKillSwitchEnabled.set(false)
                Log.i(TAG, "Kill switch disabled successfully")
                return@withContext true
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to disable kill switch", e)
                return@withContext false
            }
        }
    }

    /**
     * Set VPN connection status
     */
    fun setVpnConnectionStatus(connected: Boolean, vpnNetwork: Network? = null) {
        Log.i(TAG, "VPN connection status changed: $connected")
        
        val wasConnected = isVpnConnected.getAndSet(connected)
        
        // Handle VPN connection changes
        if (connected && !wasConnected) {
            // VPN just connected
            if (vpnNetwork != null) {
                allowedNetworks[vpnNetwork] = true
                Log.i(TAG, "Added VPN network to allowed list")
            }
            
            if (isKillSwitchEnabled.get()) {
                deactivateKillSwitch()
            }
            
        } else if (!connected && wasConnected) {
            // VPN just disconnected
            if (vpnNetwork != null) {
                allowedNetworks.remove(vpnNetwork)
                Log.i(TAG, "Removed VPN network from allowed list")
            }
            
            if (isKillSwitchEnabled.get()) {
                activateKillSwitch("VPN disconnected")
            }
        }
    }

    /**
     * Check if connection should be allowed
     */
    fun shouldAllowConnection(destination: String, port: Int): Boolean {
        if (!isKillSwitchEnabled.get()) {
            return true // Kill switch disabled, allow all
        }
        
        if (isVpnConnected.get()) {
            return true // VPN connected, allow all
        }
        
        // Kill switch active - block most connections
        val shouldAllow = isConnectionAllowed(destination, port)
        
        if (!shouldAllow) {
            val key = "$destination:$port"
            blockedConnections[key] = System.currentTimeMillis()
            listener?.onTrafficBlocked(destination, "Kill switch active - VPN not connected")
            Log.d(TAG, "Blocked connection to $destination:$port - Kill switch active")
        }
        
        return shouldAllow
    }

    /**
     * Determine if specific connection should be allowed during kill switch
     */
    private fun isConnectionAllowed(destination: String, port: Int): Boolean {
        // Allow localhost connections
        if (destination == "127.0.0.1" || destination == "::1" || destination == "localhost") {
            return true
        }
        
        // Allow DNS to system resolvers (for VPN reconnection)
        if (port == 53) {
            // Only allow to known safe DNS servers
            val safeDnsServers = setOf(
                "8.8.8.8", "8.8.4.4", // Google
                "1.1.1.1", "1.0.0.1", // Cloudflare  
                "208.67.222.222", "208.67.220.220" // OpenDNS
            )
            return destination in safeDnsServers
        }
        
        // Block all other connections during kill switch
        return false
    }

    /**
     * Register network connectivity callback
     */
    private fun registerNetworkCallback() {
        try {
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d(TAG, "Network available: $network")
                    checkNetworkLeak(network)
                }
                
                override fun onLost(network: Network) {
                    Log.d(TAG, "Network lost: $network")
                    allowedNetworks.remove(network)
                    
                    // If lost network was VPN, activate kill switch
                    if (isVpnNetwork(network) && isKillSwitchEnabled.get()) {
                        setVpnConnectionStatus(false, network)
                    }
                }
                
                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    if (networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                        Log.d(TAG, "VPN network capabilities changed: $network")
                        allowedNetworks[network] = true
                    }
                }
            }
            
            connectivityManager.registerNetworkCallback(request, networkCallback!!)
            Log.i(TAG, "Network callback registered")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to register network callback - permission denied", e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    /**
     * Unregister network callback
     */
    private fun unregisterNetworkCallback() {
        try {
            networkCallback?.let { callback ->
                connectivityManager.unregisterNetworkCallback(callback)
                Log.i(TAG, "Network callback unregistered")
            }
            networkCallback = null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister network callback", e)
        }
    }

    /**
     * Start connectivity monitoring
     */
    private fun startConnectivityMonitoring() {
        connectivityCheckJob = scope.launch {
            while (isActive && isKillSwitchEnabled.get()) {
                try {
                    checkConnectivityStatus()
                    delay(CONNECTIVITY_CHECK_INTERVAL)
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Connectivity check error", e)
                    delay(CONNECTIVITY_CHECK_INTERVAL)
                }
            }
        }
        Log.i(TAG, "Connectivity monitoring started")
    }

    /**
     * Stop connectivity monitoring
     */
    private fun stopConnectivityMonitoring() {
        connectivityCheckJob?.cancel()
        connectivityCheckJob = null
        Log.i(TAG, "Connectivity monitoring stopped")
    }

    /**
     * Check current connectivity status
     */
    private suspend fun checkConnectivityStatus() {
        try {
            val activeNetwork = connectivityManager.activeNetwork
            val capabilities = activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }
            
            if (capabilities == null) {
                Log.w(TAG, "No active network connection")
                if (isVpnConnected.get()) {
                    setVpnConnectionStatus(false)
                }
                return
            }
            
            // Check if active network is VPN
            val isVpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            
            if (isVpn != isVpnConnected.get()) {
                Log.i(TAG, "VPN status changed via connectivity check: $isVpn")
                setVpnConnectionStatus(isVpn, activeNetwork)
            }
            
            // Detect potential leaks
            detectNetworkLeaks()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check connectivity status", e)
        }
    }

    /**
     * Check if network might be leaking
     */
    private fun checkNetworkLeak(network: Network) {
        try {
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            if (capabilities == null) {
                Log.w(TAG, "Cannot get capabilities for network: $network")
                return
            }
            
            val isVpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            val isWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            val isCellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
            
            // If VPN is supposed to be connected but we detect non-VPN traffic
            if (isVpnConnected.get() && !isVpn && (isWifi || isCellular)) {
                val networkType = when {
                    isWifi -> "WiFi"
                    isCellular -> "Cellular"
                    else -> "Unknown"
                }
                
                Log.w(TAG, "Potential network leak detected - $networkType network active while VPN connected")
                listener?.onNetworkLeakDetected(networkType)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check network leak", e)
        }
    }

    /**
     * Detect multiple active networks that could cause leaks
     */
    private fun detectNetworkLeaks() {
        try {
            val allNetworks = connectivityManager.allNetworks
            val activeNetworks = allNetworks.filter { network ->
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
            }
            
            if (activeNetworks.size > MAX_ALLOWED_NETWORKS) {
                Log.w(TAG, "Multiple networks detected: ${activeNetworks.size} (max allowed: $MAX_ALLOWED_NETWORKS)")
                
                // Check for non-VPN networks when VPN should be active
                if (isVpnConnected.get()) {
                    val nonVpnNetworks = activeNetworks.filter { network ->
                        val capabilities = connectivityManager.getNetworkCapabilities(network)
                        capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) != true
                    }
                    
                    if (nonVpnNetworks.isNotEmpty()) {
                        Log.w(TAG, "Non-VPN networks active while VPN connected: ${nonVpnNetworks.size}")
                        listener?.onNetworkLeakDetected("Multiple")
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to detect network leaks", e)
        }
    }

    /**
     * Check if network is a VPN network
     */
    private fun isVpnNetwork(network: Network): Boolean {
        return try {
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check if network is VPN", e)
            false
        }
    }

    /**
     * Activate kill switch - block all traffic
     */
    private fun activateKillSwitch(reason: String) {
        Log.w(TAG, "Kill switch activated: $reason")
        
        // Clear allowed networks (except VPN if still connected)
        allowedNetworks.clear()
        
        listener?.onKillSwitchActivated(reason)
    }

    /**
     * Deactivate kill switch - allow traffic
     */
    private fun deactivateKillSwitch() {
        Log.i(TAG, "Kill switch deactivated - VPN connected")
        
        // Clear blocked connections history
        blockedConnections.clear()
        
        listener?.onKillSwitchDeactivated()
    }

    /**
     * Get kill switch status
     */
    fun getKillSwitchStatus(): Map<String, Any> {
        return mapOf(
            "enabled" to isKillSwitchEnabled.get(),
            "vpnConnected" to isVpnConnected.get(),
            "blockedConnections" to blockedConnections.size,
            "allowedNetworks" to allowedNetworks.size,
            "monitoringActive" to (connectivityCheckJob?.isActive == true)
        )
    }

    /**
     * Get blocked connections statistics
     */
    fun getBlockedConnectionsStats(): Map<String, Any> {
        val now = System.currentTimeMillis()
        val recentBlocks = blockedConnections.count { (_, timestamp) ->
            (now - timestamp) < 60000 // Last minute
        }
        
        return mapOf(
            "totalBlocked" to blockedConnections.size,
            "recentBlocks" to recentBlocks,
            "lastBlockTime" to (blockedConnections.values.maxOrNull() ?: 0L)
        )
    }

    /**
     * Set kill switch listener
     */
    fun setListener(listener: KillSwitchListener?) {
        this.listener = listener
    }

    /**
     * Test kill switch functionality
     */
    suspend fun testKillSwitch(): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            try {
                Log.i(TAG, "Testing kill switch functionality")
                
                val testResults = mutableMapOf<String, Any>()
                
                // Test 1: Check if kill switch blocks traffic when VPN disconnected
                val originalVpnStatus = isVpnConnected.get()
                setVpnConnectionStatus(false)
                
                val shouldBlock = !shouldAllowConnection("8.8.8.8", 80)
                testResults["trafficBlockedWhenVpnDown"] = shouldBlock
                
                // Test 2: Check if kill switch allows traffic when VPN connected
                setVpnConnectionStatus(true)
                
                val shouldAllow = shouldAllowConnection("8.8.8.8", 80)
                testResults["trafficAllowedWhenVpnUp"] = shouldAllow
                
                // Restore original status
                setVpnConnectionStatus(originalVpnStatus)
                
                testResults["testPassed"] = shouldBlock && shouldAllow
                testResults["testTimestamp"] = System.currentTimeMillis()
                
                Log.i(TAG, "Kill switch test completed: ${testResults["testPassed"]}")
                
                return@withContext testResults
                
            } catch (e: Exception) {
                Log.e(TAG, "Kill switch test failed", e)
                return@withContext mutableMapOf<String, Any>(
                    "testPassed" to false,
                    "error" to (e.message ?: "Unknown error"),
                    "testTimestamp" to System.currentTimeMillis()
                )
            }
        }
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up kill switch manager")
        
        scope.launch {
            disableKillSwitch()
            scope.cancel()
        }
    }
}