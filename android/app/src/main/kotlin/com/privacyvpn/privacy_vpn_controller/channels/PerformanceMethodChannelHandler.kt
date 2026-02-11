package com.privacyvpn.privacy_vpn_controller.channels

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.StatFs
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import timber.log.Timber
import java.io.File
import java.io.FileReader
import java.io.BufferedReader
import java.util.*
import kotlin.collections.HashMap

/**
 * Method channel handler for performance monitoring functionality
 */
class PerformanceMethodChannelHandler(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {
    
    companion object {
        private const val TAG = "PerformanceChannel"
    }
    
    private val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getMemoryUsage" -> {
                    getMemoryUsage(result)
                }
                "getCpuUsage" -> {
                    getCpuUsage(result)
                }
                "getBatteryInfo" -> {
                    getBatteryInfo(result)
                }
                "getStorageInfo" -> {
                    getStorageInfo(result)
                }
                "getNetworkInfo" -> {
                    getNetworkInfo(result)
                }
                else -> {
                    Timber.w("$TAG: Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Error handling method call: ${call.method}")
            result.error("PERFORMANCE_ERROR", "Failed to execute ${call.method}", e.message)
        }
    }
    
    /**
     * Get current memory usage information
     */
    private fun getMemoryUsage(result: MethodChannel.Result) {
        try {
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            val totalMemoryMB = memoryInfo.totalMem / 1024 / 1024
            val availableMemoryMB = memoryInfo.availMem / 1024 / 1024
            val usedMemoryMB = totalMemoryMB - availableMemoryMB
            
            // Get app-specific memory info
            val runtime = Runtime.getRuntime()
            val appTotalMemoryMB = runtime.totalMemory() / 1024 / 1024
            val appFreeMemoryMB = runtime.freeMemory() / 1024 / 1024
            val appUsedMemoryMB = appTotalMemoryMB - appFreeMemoryMB
            val appMaxMemoryMB = runtime.maxMemory() / 1024 / 1024
            
            val memoryData = hashMapOf<String, Any>(
                "total" to totalMemoryMB,
                "used" to usedMemoryMB,
                "available" to availableMemoryMB,
                "lowMemory" to memoryInfo.lowMemory,
                "threshold" to memoryInfo.threshold / 1024 / 1024,
                "appUsed" to appUsedMemoryMB,
                "appTotal" to appTotalMemoryMB,
                "appMax" to appMaxMemoryMB,
                "appFree" to appFreeMemoryMB
            )
            
            Timber.d("$TAG: Memory usage - System: $usedMemoryMB/$totalMemoryMB MB, App: $appUsedMemoryMB/$appMaxMemoryMB MB")
            result.success(memoryData)
            
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get memory usage")
            result.error("MEMORY_ERROR", "Failed to get memory usage", e.message)
        }
    }
    
    /**
     * Get current CPU usage percentage
     */
    private fun getCpuUsage(result: MethodChannel.Result) {
        try {
            val cpuUsage = getCurrentCpuUsage()
            Timber.d("$TAG: CPU usage: ${cpuUsage}%")
            result.success(cpuUsage)
            
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get CPU usage")
            result.error("CPU_ERROR", "Failed to get CPU usage", e.message)
        }
    }
    
    /**
     * Calculate current CPU usage
     */
    private fun getCurrentCpuUsage(): Double {
        return try {
            val statFile = File("/proc/stat")
            if (!statFile.exists()) {
                return 0.0
            }
            
            val reader = BufferedReader(FileReader(statFile))
            val firstLine = reader.readLine()
            reader.close()
            
            if (firstLine == null || !firstLine.startsWith("cpu ")) {
                return 0.0
            }
            
            val cpuTimes = firstLine.substring(4).trim().split("\\s+".toRegex())
                .map { it.toLongOrNull() ?: 0L }
            
            if (cpuTimes.size < 4) {
                return 0.0
            }
            
            val user = cpuTimes[0]
            val nice = cpuTimes[1] 
            val system = cpuTimes[2]
            val idle = cpuTimes[3]
            
            val totalCpuTime = user + nice + system + idle
            val workingTime = user + nice + system
            
            if (totalCpuTime == 0L) return 0.0
            
            (workingTime.toDouble() / totalCpuTime.toDouble() * 100.0)
            
        } catch (e: Exception) {
            Timber.w(e, "$TAG: Failed to calculate CPU usage from /proc/stat")
            0.0
        }
    }
    
    /**
     * Get current battery information
     */
    private fun getBatteryInfo(result: MethodChannel.Result) {
        try {
            val batteryIntentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, batteryIntentFilter)
            
            if (batteryStatus == null) {
                result.error("BATTERY_ERROR", "Failed to get battery information", null)
                return
            }
            
            val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val batteryLevel = if (level >= 0 && scale > 0) {
                (level.toFloat() / scale.toFloat() * 100).toInt()
            } else {
                -1
            }
            
            val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                           status == BatteryManager.BATTERY_STATUS_FULL
            
            val plugged = batteryStatus.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
            val chargingMethod = when (plugged) {
                BatteryManager.BATTERY_PLUGGED_USB -> "USB"
                BatteryManager.BATTERY_PLUGGED_AC -> "AC"
                BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
                else -> "None"
            }
            
            val temperature = batteryStatus.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
            val voltage = batteryStatus.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)
            
            val batteryData = hashMapOf<String, Any>(
                "level" to batteryLevel,
                "charging" to isCharging,
                "chargingMethod" to chargingMethod,
                "temperature" to temperature / 10.0, // Convert from tenths of degrees Celsius
                "voltage" to voltage, // in millivolts
                "status" to getStatusString(status)
            )
            
            Timber.d("$TAG: Battery info - Level: $batteryLevel%, Charging: $isCharging")
            result.success(batteryData)
            
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get battery info")
            result.error("BATTERY_ERROR", "Failed to get battery information", e.message)
        }
    }
    
    /**
     * Convert battery status integer to readable string
     */
    private fun getStatusString(status: Int): String {
        return when (status) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "Full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not Charging"
            BatteryManager.BATTERY_STATUS_UNKNOWN -> "Unknown"
            else -> "Unknown"
        }
    }
    
    /**
     * Get storage information
     */
    private fun getStorageInfo(result: MethodChannel.Result) {
        try {
            val internalDir = context.filesDir
            val statFs = StatFs(internalDir.absolutePath)
            
            val blockSize = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                statFs.blockSizeLong
            } else {
                @Suppress("DEPRECATION")
                statFs.blockSize.toLong()
            }
            
            val totalBlocks = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                statFs.blockCountLong
            } else {
                @Suppress("DEPRECATION")
                statFs.blockCount.toLong()
            }
            
            val availableBlocks = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                statFs.availableBlocksLong
            } else {
                @Suppress("DEPRECATION")
                statFs.availableBlocks.toLong()
            }
            
            val totalSpaceMB = (totalBlocks * blockSize) / 1024 / 1024
            val availableSpaceMB = (availableBlocks * blockSize) / 1024 / 1024
            val usedSpaceMB = totalSpaceMB - availableSpaceMB
            
            val storageData = hashMapOf<String, Any>(
                "totalMB" to totalSpaceMB,
                "usedMB" to usedSpaceMB,
                "availableMB" to availableSpaceMB,
                "usagePercent" to if (totalSpaceMB > 0) (usedSpaceMB.toDouble() / totalSpaceMB.toDouble() * 100.0) else 0.0
            )
            
            Timber.d("$TAG: Storage info - Used: $usedSpaceMB/$totalSpaceMB MB")
            result.success(storageData)
            
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get storage info")
            result.error("STORAGE_ERROR", "Failed to get storage information", e.message)
        }
    }
    
    /**
     * Get network information
     */
    private fun getNetworkInfo(result: MethodChannel.Result) {
        try {
            // Basic network info - could be extended with actual network statistics
            val networkData = hashMapOf<String, Any>(
                "available" to true,
                "type" to "Unknown" // Could be enhanced to detect WiFi/Mobile/etc
            )
            
            result.success(networkData)
            
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get network info")
            result.error("NETWORK_ERROR", "Failed to get network information", e.message)
        }
    }
    
    /**
     * Clean up resources
     */
    fun cleanup() {
        Timber.d("$TAG: Cleaning up performance channel handler")
    }
}