package com.privacyvpn.privacy_vpn_controller.channels

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
            "isBatteryOptimizationExempted" -> isBatteryOptimizationExempted(result)
            "requestBatteryOptimizationExemption" -> requestBatteryOptimizationExemption(result)
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
    
    /**
     * Check if the app is exempted from battery optimization.
     * If not exempted, Android may kill background services (Ghost mode).
     */
    private fun isBatteryOptimizationExempted(result: MethodChannel.Result) {
        try {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = activity.packageName
            val isExempted = pm.isIgnoringBatteryOptimizations(packageName)
            result.success(mapOf("exempted" to isExempted))
        } catch (e: Exception) {
            Timber.e(e, "Failed to check battery optimization")
            result.success(mapOf("exempted" to false))
        }
    }

    /**
     * Request the user to exempt this app from battery optimization.
     * This opens the system dialog directly asking to allow background activity.
     */
    private fun requestBatteryOptimizationExemption(result: MethodChannel.Result) {
        try {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = activity.packageName
            
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                activity.startActivity(intent)
                result.success(mapOf("requested" to true))
            } else {
                // Already exempted
                result.success(mapOf("requested" to false, "alreadyExempted" to true))
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to request battery optimization exemption")
            result.success(mapOf("requested" to false, "error" to e.message))
        }
    }

    fun cleanup() {
        // Cleanup resources if needed
    }
}