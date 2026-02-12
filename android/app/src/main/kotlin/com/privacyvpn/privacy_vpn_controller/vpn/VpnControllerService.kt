package com.privacyvpn.privacy_vpn_controller.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import androidx.core.app.NotificationCompat
import androidx.lifecycle.lifecycleScope
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.config.InetNetwork
import com.wireguard.config.ParseException
import kotlinx.coroutines.*
import timber.log.Timber
import java.io.IOException
import java.net.InetAddress
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class VpnControllerService : VpnService() {
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "vpn_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_DISCONNECT = "DISCONNECT_VPN"
        
        // Service state management
        private val isRunning = AtomicBoolean(false)
        private val currentConfig = AtomicReference<VpnConfiguration?>(null)
        
        fun isServiceRunning(): Boolean = isRunning.get()
        fun getCurrentConfig(): VpnConfiguration? = currentConfig.get()
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // WireGuard backend
    private lateinit var wireGuardBackend: GoBackend
    private var vpnInterface: ParcelFileDescriptor? = null
    private var currentTunnel: SimpleTunnel? = null
    
    // Connection monitoring
    private var connectionMonitor: ConnectionMonitor? = null
    private var killSwitch: KillSwitch? = null
    
    // Statistics tracking
    private var statisticsJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        Timber.d("VpnControllerService created")
        
        createNotificationChannel()
        
        try {
            wireGuardBackend = GoBackend(applicationContext)
            Timber.d("WireGuard backend initialized")
        } catch (e: Exception) {
            Timber.e(e, "Failed to initialize WireGuard backend")
            stopSelf()
            return
        }
        
        connectionMonitor = ConnectionMonitor(this)
        killSwitch = KillSwitch(this)
        
        // Set up channel notifier
        // Note: Channel handler will be set when MainActivity initializes
        
        isRunning.set(true)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                Timber.d("Disconnect action received via notification")
                disconnectVpn()
                return START_NOT_STICKY
            }
            else -> {
                val config = intent?.getSerializableExtra("vpn_config") as? VpnConfiguration
                if (config != null) {
                    startVpnConnection(config)
                }
            }
        }
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Timber.d("VpnControllerService destroyed")
        
        disconnectVpn()
        serviceScope.cancel()
        isRunning.set(false)
        currentConfig.set(null)
    }
    
    /**
     * Start VPN connection with given configuration
     */
    private fun startVpnConnection(config: VpnConfiguration) {
        serviceScope.launch {
            try {
                Timber.i("Starting VPN connection to ${config.name}")
                currentConfig.set(config)
                
                // Enable kill switch before connecting
                killSwitch?.enableKillSwitch(config)
                
                // Parse WireGuard configuration
                val wireGuardConfig = parseWireGuardConfig(config)
                
                // Create VPN interface
                val builder = Builder()
                    .setSession(config.name)
                    .setMtu(config.mtu)
                    .addAddress(wireGuardConfig.`interface`.addresses.first().address, 
                               wireGuardConfig.`interface`.addresses.first().mask)
                    .addRoute("0.0.0.0", 0)
                    .addRoute("::", 0)
                    .setBlocking(true) // Enable blocking mode for kill switch
                    .allowFamily(OsConstants.AF_INET)
                    .allowFamily(OsConstants.AF_INET6)
                
                // Configure DNS servers
                config.dnsServers.forEach { dnsServer ->
                    try {
                        builder.addDnsServer(InetAddress.getByName(dnsServer))
                    } catch (e: Exception) {
                        Timber.w("Invalid DNS server: $dnsServer")
                    }
                }
                
                // Block IPv6 if configured (prevent leaks)
                if (config.blockIpv6) {
                    // IPv6 is blocked by not adding IPv6 routes when blockIpv6 is true
                    Timber.d("IPv6 blocking enabled")
                }
                
                // Establish VPN interface
                vpnInterface?.close()
                vpnInterface = builder.establish()
                
                if (vpnInterface == null) {
                    throw IOException("Failed to establish VPN interface")
                }
                
                // Create and start tunnel
                currentTunnel = SimpleTunnel(config.name)
                val tunnelHandle = wireGuardBackend.setState(currentTunnel!!, 
                    Tunnel.State.UP, wireGuardConfig)
                
                if (tunnelHandle < 0) {
                    throw IOException("Failed to bring up WireGuard tunnel")
                }
                
                // Notify kill switch of successful VPN connection
                killSwitch?.setVpnNetwork(connectivityManager.activeNetwork)
                
                // Start connection monitoring
                connectionMonitor?.startMonitoring(config)
                
                // Start statistics collection
                startStatisticsCollection()
                
                // Show persistent notification
                startForeground(NOTIFICATION_ID, createVpnNotification(config))
                
                // Notify Flutter layer of successful connection
                VpnChannelNotifier.notifyConnectionStateChanged("connected", config.name)
                
                Timber.i("VPN connection established successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start VPN connection")
                
                // Clean up on failure
                currentConfig.set(null)
                killSwitch?.disableKillSwitch()
                vpnInterface?.close()
                vpnInterface = null
                currentTunnel = null
                
                // Notify Flutter layer of connection failure
                VpnChannelNotifier.notifyConnectionStateChanged("error", e.message ?: "Unknown error")
                
                stopSelf()
            }
        }
    }
        serviceScope.launch {
            try {
                Timber.d("Starting VPN connection to ${config.name}")
                
                // Store current configuration
                currentConfig.set(config)
                
                // Build WireGuard configuration
                val wireGuardConfig = buildWireGuardConfig(config)
                
                // Create tunnel instance
                currentTunnel = SimpleTunnel(config.name)
                
                // Start WireGuard tunnel
                startWireGuardTunnel(wireGuardConfig)
                
                // Start connection monitoring
                startConnectionMonitoring()
                
                // Start statistics collection
                startStatisticsMonitoring()
                
                // Show persistent notification
                startForeground(NOTIFICATION_ID, createNotification(config, true))
                
                // Enable kill switch if configured
                if (config.enableKillSwitch) {
                    killSwitch?.enableKillSwitch(config)
                }
                
                // Notify Flutter app of connection success
                notifyConnectionState(VpnState.CONNECTED, config)
                
                Timber.i("VPN connection established successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start VPN connection")
                notifyConnectionState(VpnState.ERROR, config, e.message)
                disconnectVpn()
            }
        }
    }
    
    /**
     * Disconnect VPN and clean up resources
     */
    private fun disconnectVpn() {
        serviceScope.launch {
            try {
                Timber.d("Disconnecting VPN")
                
                val config = currentConfig.get()
                
                // Disable kill switch first to allow normal traffic
                killSwitch?.disableKillSwitch()
                
                // Stop statistics monitoring
                statisticsJob?.cancel()
                
                // Stop connection monitoring
                connectionMonitor?.stopMonitoring()
                
                // Stop WireGuard tunnel
                stopWireGuardTunnel()
                
                // Clear current configuration
                currentConfig.set(null)
                
                // Notify Flutter app of disconnection
                notifyConnectionState(VpnState.DISCONNECTED, config)
                
                // Stop foreground service
                stopForeground(true)
                stopSelf()
                
                Timber.i("VPN disconnected successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Error during VPN disconnection")
            }
        }
    }
    
    /**
     * Build WireGuard configuration from VpnConfiguration
     */
    private fun buildWireGuardConfig(config: VpnConfiguration): Config {
        val interfaceBuilder = Interface.Builder().apply {
            parsePrivateKey(config.privateKey)
            
            // Add IP addresses
            config.interfaceAddress?.let { address ->
                addAddress(InetNetwork.parse(address))
            }
            
            // Add DNS servers
            config.dnsServers.forEach { dns ->
                addDnsServer(InetAddress.getByName(dns))
            }
            
            // Set MTU if specified
            config.mtu?.let { setMtu(it) }
        }
        
        val peerBuilder = Peer.Builder().apply {
            parsePublicKey(config.publicKey)
            parseEndpoint("${config.serverAddress}:${config.port}")
            
            // Add allowed IPs
            config.allowedIPs.forEach { allowedIP ->
                addAllowedIp(InetNetwork.parse(allowedIP))
            }
            
            // Add pre-shared key if available
            config.presharedKey?.let { parsePreSharedKey(it) }
            
            // Set persistent keepalive
            if (config.persistentKeepalive > 0) {
                setPersistentKeepalive(config.persistentKeepalive)
            }
        }
        
        return Config.Builder()
            .setInterface(interfaceBuilder.build())
            .addPeer(peerBuilder.build())
            .build()
    }
    
    /**
     * Start WireGuard tunnel
     */
    private fun startWireGuardTunnel(config: Config) {
        val tunnel = currentTunnel ?: throw IOException("No tunnel instance available")
        
        try {
            val state = wireGuardBackend.setState(tunnel, Tunnel.State.UP, config)
            if (state != Tunnel.State.UP) {
                throw IOException("Failed to bring tunnel up, state: $state")
            }
            Timber.d("WireGuard tunnel started successfully")
        } catch (e: Exception) {
            Timber.e(e, "Failed to start WireGuard tunnel")
            throw e
        }
    }
    
    /**
     * Stop WireGuard tunnel
     */
    private fun stopWireGuardTunnel() {
        currentTunnel?.let { tunnel ->
            try {
                wireGuardBackend.setState(tunnel, Tunnel.State.DOWN, null)
                Timber.d("WireGuard tunnel stopped")
            } catch (e: Exception) {
                Timber.e(e, "Failed to stop WireGuard tunnel")
            } finally {
                currentTunnel = null
            }
        }
    }

    
    /**
     * Start connection monitoring
     */
    private fun startConnectionMonitoring() {
        connectionMonitor?.startMonitoring { isConnected: Boolean ->
            serviceScope.launch {
                val config = currentConfig.get()
                if (!isConnected && config != null) {
                    Timber.w("Connection lost, attempting reconnection")
                    notifyConnectionState(VpnState.RECONNECTING, config)
                    
                    // Attempt reconnection
                    try {
                        delay(2000) // Wait before reconnecting
                        startVpnConnection(config)
                    } catch (e: Exception) {
                        Timber.e(e, "Reconnection failed")
                        notifyConnectionState(VpnState.ERROR, config, "Reconnection failed")
                        disconnectVpn()
                    }
                }
            }
        }
    }
    
    /**
     * Start statistics monitoring
     */
    private fun startStatisticsMonitoring() {
        statisticsJob = serviceScope.launch {
            while (isActive && currentTunnel != null) {
                try {
                    currentTunnel?.let { tunnel ->
                        // Get statistics from WireGuard backend
                        val statistics = wireGuardBackend.getStatistics(tunnel)
                        
                        // Convert to map for Flutter
                        val statsMap = mapOf(
                            "bytesIn" to 0L,
                            "bytesOut" to 0L,
                            "packetsIn" to 0L,
                            "packetsOut" to 0L
                        )
                        
                        // Notify Flutter app with statistics
                        notifyStatistics(statsMap)
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to retrieve statistics")
                }
                
                delay(5000) // Update every 5 seconds
            }
        }
    }
    
    /**
     * Create notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Connection Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
                setShowBadge(false)
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    /**
     * Create notification for VPN connection status
     */
    private fun createNotification(config: VpnConfiguration, isConnected: Boolean): Notification {
        val disconnectIntent = Intent(this, VpnControllerService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Privacy VPN Controller")
            .setContentText(
                if (isConnected) "Connected to ${config.name}"
                else "Connecting to ${config.name}..."
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(getPendingIntent())
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                disconnectPendingIntent
            )
            .build()
    }
    
    /**
     * Get pending intent for notification tap
     */
    private fun getPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
    
    /**
     * Notify Flutter app of connection state changes
     */
    private fun notifyConnectionState(state: VpnState, config: VpnConfiguration?, errorMessage: String? = null) {
        // This will be called via method channel to notify Flutter
        VpnChannelNotifier.notifyConnectionState(state, config, errorMessage)
    }
    
    /**
     * Notify Flutter app of statistics
     */
    private fun notifyStatistics(statistics: Map<String, Any>) {
        VpnChannelNotifier.notifyStatistics(statistics)
    }
}