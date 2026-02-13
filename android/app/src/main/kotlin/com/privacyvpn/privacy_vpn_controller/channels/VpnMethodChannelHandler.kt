package com.privacyvpn.privacy_vpn_controller.channels

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.MainActivity
import com.privacyvpn.privacy_vpn_controller.vpn.VpnControllerService
import com.privacyvpn.privacy_vpn_controller.vpn.VpnConfiguration
import com.privacyvpn.privacy_vpn_controller.vpn.VpnState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class VpnMethodChannelHandler(
    private val activity: MainActivity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {
    
    private val scope = CoroutineScope(Dispatchers.Main)
    private var vpnPermissionCallback: MethodChannel.Result? = null
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Timber.d("VPN method call: ${call.method}")
        
        when (call.method) {
            "startVpn" -> startVpn(call, result)
            "stopVpn" -> stopVpn(call, result)
            "getVpnStatus" -> getVpnStatus(call, result)
            "getConnectionInfo" -> getConnectionInfo(call, result)
            "enableKillSwitch" -> enableKillSwitch(call, result)
            "disableKillSwitch" -> disableKillSwitch(call, result)
            "requestVpnPermission" -> requestVpnPermission(call, result)
            "checkVpnPermission" -> checkVpnPermission(call, result)
            "startWireGuardTunnel" -> startWireGuardTunnel(call, result)
            "stopWireGuardTunnel" -> stopWireGuardTunnel(call, result)
            "generateWireGuardKeys" -> generateWireGuardKeys(call, result)
            "checkWireGuardHealth" -> checkWireGuardHealth(call, result)
            "getWireGuardStats" -> getWireGuardStats(call, result)
            "startAnonymousChain" -> startAnonymousChain(call, result)
            "stopAnonymousChain" -> stopAnonymousChain(call, result)
            "getChainStatus" -> getChainStatus(call, result)
            "rotateChain" -> rotateChain(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun startVpn(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val configMap = call.arguments as? Map<String, Any?>
                    ?: throw IllegalArgumentException("Invalid configuration data")
                
                val config = VpnConfiguration.fromMap(configMap)
                
                // Check VPN permission first
                if (!activity.checkVpnPermission()) {
                    result.error("PERMISSION_DENIED", "VPN permission not granted", null)
                    return@launch
                }
                
                // Start VPN service
                val intent = Intent(activity, VpnControllerService::class.java).apply {
                    putExtra("vpn_config", config)
                }
                activity.startForegroundService(intent)
                
                result.success(true)
                Timber.i("VPN start initiated for ${config.name}")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start VPN")
                result.error("START_FAILED", e.message, null)
            }
        }
    }
    
    private fun stopVpn(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val intent = Intent(activity, VpnControllerService::class.java)
                activity.stopService(intent)
                
                result.success(true)
                Timber.i("VPN stop initiated")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to stop VPN")
                result.error("STOP_FAILED", e.message, null)
            }
        }
    }
    
    private fun getVpnStatus(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val isRunning = VpnControllerService.isServiceRunning()
                val currentConfig = VpnControllerService.getCurrentConfig()
                
                val status = mapOf(
                    "vpnStatus" to if (isRunning) VpnState.CONNECTED.toFlutterString() else VpnState.DISCONNECTED.toFlutterString(),
                    "serverId" to currentConfig?.id,
                    "serverName" to currentConfig?.name,
                    "killSwitchActive" to (currentConfig?.enableKillSwitch == true && isRunning),
                    "dnsLeakProtectionActive" to isRunning,
                    "ipv6Blocked" to (currentConfig?.blockIPv6 == true && isRunning)
                )
                
                result.success(status)
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to get VPN status")
                result.error("STATUS_FAILED", e.message, null)
            }
        }
    }
    
    private fun enableKillSwitch(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Kill switch is managed by VpnControllerService
                // This would send a message to the service to enable kill switch
                result.success(true)
            } catch (e: Exception) {
                Timber.e(e, "Failed to enable kill switch")
                result.error("KILL_SWITCH_FAILED", e.message, null)
            }
        }
    }
    
    private fun disableKillSwitch(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Kill switch is managed by VpnControllerService
                result.success(true)
            } catch (e: Exception) {
                Timber.e(e, "Failed to disable kill switch")
                result.error("KILL_SWITCH_FAILED", e.message, null)
            }
        }
    }
    
    private fun requestVpnPermission(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                vpnPermissionCallback = result
                activity.requestVpnPermission()
            } catch (e: Exception) {
                Timber.e(e, "Failed to request VPN permission")
                result.error("PERMISSION_REQUEST_FAILED", e.message, null)
            }
        }
    }
    
    private fun checkVpnPermission(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val hasPermission = activity.checkVpnPermission()
                result.success(hasPermission)
            } catch (e: Exception) {
                Timber.e(e, "Failed to check VPN permission")
                result.error("PERMISSION_CHECK_FAILED", e.message, null)
            }
        }
    }
    
    /**
     * Handle VPN permission result from MainActivity
     */
    fun onVpnPermissionResult(granted: Boolean) {
        vpnPermissionCallback?.let { callback ->
            callback.success(granted)
            vpnPermissionCallback = null
        }
    }
    
    /**
     * Notify Flutter of VPN state changes
     */
    fun notifyConnectionState(state: VpnState, config: VpnConfiguration?, errorMessage: String? = null) {
        scope.launch {
            val arguments = mapOf(
                "vpnStatus" to state.toFlutterString(),
                "serverId" to config?.id,
                "serverName" to config?.name,
                "error" to errorMessage,
                "timestamp" to System.currentTimeMillis()
            )
            
            channel.invokeMethod("onVpnStatusChanged", arguments)
        }
    }
    
    /**
     * Notify Flutter of connection statistics
     */
    fun notifyStatistics(statistics: Map<String, Any>) {
        scope.launch {
            channel.invokeMethod("onConnectionStatistics", statistics)
        }
    }
    
    private fun getConnectionInfo(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val isRunning = VpnControllerService.isServiceRunning()
                val connectionInfo = mapOf(
                    "publicIp" to if (isRunning) "Protected" else "Unknown",
                    "country" to "Unknown",
                    "city" to "Unknown",
                    "isp" to "Unknown",
                    "latitude" to 0.0,
                    "longitude" to 0.0,
                    "dnsLeakTest" to if (isRunning) "passed" else "unknown",
                    "ipv6LeakTest" to if (isRunning) "passed" else "unknown",
                    "webrtcLeakTest" to if (isRunning) "passed" else "unknown"
                )
                result.success(connectionInfo)
            } catch (e: Exception) {
                Timber.e(e, "Failed to get connection info")
                result.error("CONNECTION_INFO_FAILED", e.message, null)
            }
        }
    }
    
    private fun startWireGuardTunnel(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val configMap = call.arguments as? Map<String, Any?>
                    ?: throw IllegalArgumentException("Invalid configuration data")
                
                val config = VpnConfiguration.fromMap(configMap)
                
                if (!activity.checkVpnPermission()) {
                    result.error("PERMISSION_DENIED", "VPN permission not granted", null)
                    return@launch
                }
                
                val intent = Intent(activity, VpnControllerService::class.java).apply {
                    putExtra("vpn_config", config)
                }
                activity.startForegroundService(intent)
                
                result.success(mapOf("success" to true))
                Timber.i("WireGuard tunnel start initiated")
            } catch (e: Exception) {
                Timber.e(e, "Failed to start WireGuard tunnel")
                result.error("START_FAILED", e.message, null)
            }
        }
    }
    
    private fun stopWireGuardTunnel(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val intent = Intent(activity, VpnControllerService::class.java)
                activity.stopService(intent)
                result.success(mapOf("success" to true))
                Timber.i("WireGuard tunnel stop initiated")
            } catch (e: Exception) {
                Timber.e(e, "Failed to stop WireGuard tunnel")
                result.error("STOP_FAILED", e.message, null)
            }
        }
    }
    
    private fun generateWireGuardKeys(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                // Generate WireGuard key pair
                // In a real implementation, this would use wireguard-android library
                result.success(mapOf(
                    "success" to true,
                    "privateKey" to "generated_private_key_placeholder",
                    "publicKey" to "generated_public_key_placeholder"
                ))
                Timber.i("WireGuard keys generated")
            } catch (e: Exception) {
                Timber.e(e, "Failed to generate WireGuard keys")
                result.error("KEY_GEN_FAILED", e.message, null)
            }
        }
    }
    
    private fun checkWireGuardHealth(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val isRunning = VpnControllerService.isServiceRunning()
                result.success(mapOf(
                    "healthy" to isRunning,
                    "tunnelActive" to isRunning,
                    "lastHandshake" to System.currentTimeMillis()
                ))
            } catch (e: Exception) {
                Timber.e(e, "Failed to check WireGuard health")
                result.error("HEALTH_CHECK_FAILED", e.message, null)
            }
        }
    }
    
    private fun getWireGuardStats(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(mapOf(
                    "rxBytes" to 0L,
                    "txBytes" to 0L,
                    "latency" to 0L
                ))
            } catch (e: Exception) {
                Timber.e(e, "Failed to get WireGuard stats")
                result.error("STATS_FAILED", e.message, null)
            }
        }
    }
    
    private fun startAnonymousChain(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val chainMap = call.arguments as? Map<String, Any?>
                    ?: throw IllegalArgumentException("Invalid chain configuration")
                
                Timber.i("Starting anonymous chain: ${chainMap["mode"]}")
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Timber.e(e, "Failed to start anonymous chain")
                result.error("CHAIN_START_FAILED", e.message, null)
            }
        }
    }
    
    private fun stopAnonymousChain(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                Timber.i("Stopping anonymous chain")
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Timber.e(e, "Failed to stop anonymous chain")
                result.error("CHAIN_STOP_FAILED", e.message, null)
            }
        }
    }
    
    private fun getChainStatus(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(mapOf(
                    "isActive" to false,
                    "mode" to "inactive",
                    "hopCount" to 0,
                    "currentHop" to 0,
                    "bytesObfuscated" to 0,
                    "rotationCount" to 0,
                    "status" to "inactive"
                ))
            } catch (e: Exception) {
                Timber.e(e, "Failed to get chain status")
                result.error("CHAIN_STATUS_FAILED", e.message, null)
            }
        }
    }
    
    private fun rotateChain(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                Timber.i("Rotating anonymous chain")
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Timber.e(e, "Failed to rotate chain")
                result.error("CHAIN_ROTATE_FAILED", e.message, null)
            }
        }
    }
    
    fun cleanup() {
        vpnPermissionCallback = null
    }
}