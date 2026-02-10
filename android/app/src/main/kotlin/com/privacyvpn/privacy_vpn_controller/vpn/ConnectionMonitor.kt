package com.privacyvpn.privacy_vpn_controller.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import kotlinx.coroutines.*
import timber.log.Timber

/**
 * Monitors VPN connection status and network changes
 */
class ConnectionMonitor(private val context: Context) {
    
    private var monitoringJob: Job? = null
    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    fun startMonitoring(callback: (Boolean) -> Unit) {
        Timber.d("Starting connection monitoring")
        
        monitoringJob = CoroutineScope(Dispatchers.IO).launch {
            while (isActive) {
                try {
                    val isConnected = checkNetworkConnectivity()
                    withContext(Dispatchers.Main) {
                        callback(isConnected)
                    }
                    delay(5000) // Check every 5 seconds
                } catch (e: Exception) {
                    Timber.e(e, "Error during connection monitoring")
                }
            }
        }
        
        // Also register for network changes
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            connectivityCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Timber.d("Network available: $network")
                    callback(true)
                }
                
                override fun onLost(network: Network) {
                    Timber.d("Network lost: $network")
                    callback(false)
                }
            }
            
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            
            connectivityManager.registerNetworkCallback(networkRequest, connectivityCallback!!)
        }
    }
    
    fun stopMonitoring() {
        Timber.d("Stopping connection monitoring")
        monitoringJob?.cancel()
        connectivityCallback?.let { callback ->
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (e: Exception) {
                Timber.e(e, "Error unregistering network callback")
            }
        }
    }
    
    private fun checkNetworkConnectivity(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
            } else {
                @Suppress("DEPRECATION")
                val networkInfo = connectivityManager.activeNetworkInfo
                networkInfo?.isConnected == true
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to check network connectivity")
            false
        }
    }
}