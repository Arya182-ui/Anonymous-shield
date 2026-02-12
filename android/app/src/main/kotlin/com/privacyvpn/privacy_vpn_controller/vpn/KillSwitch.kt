package com.privacyvpn.privacy_vpn_controller.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import timber.log.Timber
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Kill switch implementation to block traffic when VPN is disconnected
 * Uses network callback monitoring and VpnService routing to implement traffic blocking
 */
class KillSwitch(private val context: Context) {
    
    private val isEnabled = AtomicBoolean(false)
    private val isBlocking = AtomicBoolean(false)
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var allowedNetwork: Network? = null
    
    fun enableKillSwitch(config: VpnConfiguration) {
        Timber.d("Enabling kill switch for ${config.name}")
        
        try {
            isEnabled.set(true)
            
            // Register network callback to monitor VPN connection
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .build()
            
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    // If VPN is supposed to be connected but we see non-VPN traffic,
                    // this indicates a potential leak
                    if (isEnabled.get() && allowedNetwork == null) {
                        Timber.w("Kill switch: Non-VPN network detected, potential leak")
                        blockTraffic()
                    }
                }
                
                override fun onLost(network: Network) {
                    super.onLost(network)
                    if (network == allowedNetwork) {
                        Timber.w("Kill switch: VPN network lost, blocking traffic")
                        blockTraffic()
                    }
                }
            }
            
            connectivityManager.registerNetworkCallback(networkRequest, networkCallback!!)
            
            Timber.i("Kill switch enabled successfully")
        } catch (e: Exception) {
            Timber.e(e, "Failed to enable kill switch")
            throw e
        }
    }
    
    fun disableKillSwitch() {
        Timber.d("Disabling kill switch")
        
        try {
            isEnabled.set(false)
            isBlocking.set(false)
            
            // Unregister network callback
            networkCallback?.let { callback ->
                connectivityManager.unregisterNetworkCallback(callback)
                networkCallback = null
            }
            
            allowedNetwork = null
            restoreNormalTraffic()
            
            Timber.i("Kill switch disabled successfully")
        } catch (e: Exception) {
            Timber.e(e, "Failed to disable kill switch")
            throw e
        }
    }
    
    fun setVpnNetwork(network: Network) {
        allowedNetwork = network
        if (isBlocking.get()) {
            // Restore traffic now that VPN is back
            restoreNormalTraffic()
        }
    }
    
    fun isKillSwitchEnabled(): Boolean = isEnabled.get()
    
    fun isTrafficBlocked(): Boolean = isBlocking.get()
    
    private fun blockTraffic() {
        if (!isEnabled.get() || isBlocking.get()) return
        
        isBlocking.set(true)
        Timber.w("Kill switch: Blocking all traffic - VPN connection lost")
        
        // In a VpnService context, traffic blocking is achieved by:
        // 1. Not allowing any traffic through the VPN tunnel
        // 2. The Android VPN framework blocks all other traffic by default
        // This is handled at the VpnService level, not here directly
    }
    
    private fun restoreNormalTraffic() {
        if (isBlocking.get()) {
            isBlocking.set(false)
            Timber.i("Kill switch: Restoring traffic - VPN connection established")
        }
    }
}