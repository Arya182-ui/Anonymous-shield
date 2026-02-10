package com.privacyvpn.privacy_vpn_controller.channels

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.MainActivity

class SystemMethodChannelHandler(
    private val activity: MainActivity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Timber.d("System method call: ${call.method}")
        
        when (call.method) {
            "getSystemInfo" -> getSystemInfo(call, result)
            "checkNetworkConnectivity" -> checkNetworkConnectivity(call, result)
            "getDeviceInfo" -> getDeviceInfo(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun getSystemInfo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val systemInfo = mapOf(
                "androidVersion" to Build.VERSION.RELEASE,
                "sdkVersion" to Build.VERSION.SDK_INT,
                "deviceModel" to Build.MODEL,
                "deviceManufacturer" to Build.MANUFACTURER
            )
            result.success(systemInfo)
        } catch (e: Exception) {
            Timber.e(e, "Failed to get system info")
            result.error("SYSTEM_INFO_FAILED", e.message, null)
        }
    }
    
    private fun checkNetworkConnectivity(call: MethodCall, result: MethodChannel.Result) {
        try {
            val connectivityManager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val isConnected = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
            } else {
                @Suppress("DEPRECATION")
                val networkInfo = connectivityManager.activeNetworkInfo
                networkInfo?.isConnected == true
            }
            
            result.success(mapOf("isConnected" to isConnected))
        } catch (e: Exception) {
            Timber.e(e, "Failed to check network connectivity")
            result.error("CONNECTIVITY_CHECK_FAILED", e.message, null)
        }
    }
    
    private fun getDeviceInfo(call: MethodCall, result: MethodChannel.Result) {
        try {
            val deviceInfo = mapOf(
                "brand" to Build.BRAND,
                "device" to Build.DEVICE,
                "model" to Build.MODEL,
                "manufacturer" to Build.MANUFACTURER,
                "product" to Build.PRODUCT,
                "androidId" to Build.ID
            )
            result.success(deviceInfo)
        } catch (e: Exception) {
            Timber.e(e, "Failed to get device info")
            result.error("DEVICE_INFO_FAILED", e.message, null)
        }
    }
    
    fun cleanup() {
        // Cleanup resources if needed
    }
}