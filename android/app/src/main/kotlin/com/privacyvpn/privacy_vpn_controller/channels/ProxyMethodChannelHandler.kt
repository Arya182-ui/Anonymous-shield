package com.privacyvpn.privacy_vpn_controller.channels

import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.MainActivity
import com.privacyvpn.privacy_vpn_controller.proxy.ProxyService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ProxyMethodChannelHandler(
    private val activity: MainActivity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {
    
    private val scope = CoroutineScope(Dispatchers.Main)
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Timber.d("Proxy method call: ${call.method}")
        
        when (call.method) {
            "startProxy" -> startProxy(call, result)
            "stopProxy" -> stopProxy(call, result)
            "getProxyStatus" -> getProxyStatus(call, result)
            "testProxy" -> testProxy(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun startProxy(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val configMap = call.arguments as? Map<String, Any?>
                    ?: throw IllegalArgumentException("Invalid proxy configuration")
                
                // Create intent with proxy configuration
                val intent = Intent(activity, ProxyService::class.java).apply {
                    putExtra("id", configMap["id"] as? String ?: "proxy_${System.currentTimeMillis()}")
                    putExtra("type", (configMap["type"] as? String)?.uppercase() ?: "SOCKS5")
                    putExtra("host", configMap["host"] as? String ?: "")
                    putExtra("port", configMap["port"] as? Int ?: 0)
                    putExtra("username", configMap["username"] as? String)
                    putExtra("password", configMap["password"] as? String)
                    putExtra("method", configMap["method"] as? String)
                }
                
                // Start proxy service
                activity.startForegroundService(intent)
                
                result.success(true)
                Timber.i("Proxy start initiated")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start proxy")
                result.error("START_FAILED", e.message, null)
            }
        }
    }
    
    private fun stopProxy(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Stop proxy service
                val intent = Intent(activity, ProxyService::class.java)
                activity.stopService(intent)
                
                result.success(true)
                Timber.i("Proxy stop initiated")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to stop proxy")
                result.error("STOP_FAILED", e.message, null)
            }
        }
    }
    
    private fun getProxyStatus(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val isRunning = ProxyService.isServiceRunning()
                val connectionCount = ProxyService.getActiveConnectionCount()
                
                val status = mapOf(
                    "proxyStatus" to if (isRunning) "enabled" else "disabled",
                    "activeConnections" to connectionCount,
                    "isHealthy" to isRunning
                )
                
                result.success(status)
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to get proxy status")
                result.error("STATUS_FAILED", e.message, null)
            }
        }
    }
    
    private fun testProxy(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val configMap = call.arguments as? Map<String, Any?>
                    ?: throw IllegalArgumentException("Invalid proxy configuration for test")
                
                // For now, return true for basic validation
                // In production, would create a test connection
                val host = configMap["host"] as? String ?: ""
                val port = configMap["port"] as? Int ?: 0
                
                val isValid = host.isNotEmpty() && port > 0 && port < 65536
                
                result.success(isValid)
                Timber.i("Proxy test result: $isValid")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to test proxy")
                result.error("TEST_FAILED", e.message, null)
            }
        }
    }
    
    // Method to send status updates back to Flutter
    fun sendProxyStatusUpdate(status: String, config: Map<String, Any?>? = null) {
        scope.launch {
            try {
                val statusData = mapOf(
                    "status" to status,
                    "config" to config,
                    "timestamp" to System.currentTimeMillis()
                )
                
                channel.invokeMethod("onProxyStatusChanged", statusData)
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to send proxy status update")
            }
        }
    }
    
    // Method to send proxy errors back to Flutter
    fun sendProxyError(error: String) {
        scope.launch {
            try {
                val errorData = mapOf(
                    "error" to error,
                    "timestamp" to System.currentTimeMillis()
                )
                
                channel.invokeMethod("onProxyError", errorData)
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to send proxy error")
            }
        }
    }
    
    fun cleanup() {
        // Cleanup resources if needed
    }
}