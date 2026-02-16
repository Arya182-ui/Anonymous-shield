package com.privacyvpn.privacy_vpn_controller.channels

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.tor.TorEngine
import com.privacyvpn.privacy_vpn_controller.tor.TorVpnService

/**
 * Flutter ↔ Android method channel handler for Tor/Ghost mode.
 * Channel: "com.privacyvpn.privacy_vpn_controller/tor"
 */
class TorMethodChannelHandler(
    private val activity: Activity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "TorChannelHandler"
        private const val VPN_PREPARE_REQUEST = 9901
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Pending result for VPN permission callback
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingVpnIntent: Intent? = null

    init {
        // Listen for TorVpnService callbacks and forward to Flutter
        setupServiceCallbacks()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTorVpn" -> handleStartTorVpn(call, result)
            "startProxyVpn" -> handleStartProxyVpn(call, result)
            "stopTorVpn" -> handleStopTorVpn(result)
            "requestNewCircuit" -> handleNewCircuit(result)
            "getStatus" -> handleGetStatus(result)
            "getCircuitInfo" -> handleGetCircuitInfo(result)
            "isTorAvailable" -> handleIsTorAvailable(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Start Tor VPN (Ghost Mode with Tor).
     * Params: { "useBridges": bool }
     */
    private fun handleStartTorVpn(call: MethodCall, result: MethodChannel.Result) {
        val useBridges = call.argument<Boolean>("useBridges") ?: false

        Timber.i("$TAG: startTorVpn (bridges=$useBridges)")

        // Ensure VPN permission is granted first
        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            Timber.d("$TAG: VPN permission needed, requesting...")
            val intent = Intent(activity, TorVpnService::class.java).apply {
                action = TorVpnService.ACTION_START
                putExtra(TorVpnService.EXTRA_USE_BRIDGES, useBridges)
                putExtra(TorVpnService.EXTRA_MODE, "tor")
            }
            pendingVpnResult = result
            pendingVpnIntent = intent
            activity.startActivityForResult(prepareIntent, VPN_PREPARE_REQUEST)
            return
        }

        try {
            val intent = Intent(activity, TorVpnService::class.java).apply {
                action = TorVpnService.ACTION_START
                putExtra(TorVpnService.EXTRA_USE_BRIDGES, useBridges)
                putExtra(TorVpnService.EXTRA_MODE, "tor")
            }
            activity.startForegroundService(intent)

            // Wait for actual connection confirmation instead of returning immediately
            scope.launch {
                var connected = false
                for (i in 1..16) { // 16 x 500ms = 8 seconds max
                    delay(500)
                    if (TorVpnService.isActive) {
                        connected = true
                        break
                    }
                    if (TorVpnService.instance == null && i > 4) break
                }
                if (connected) {
                    Timber.i("$TAG: Tor VPN confirmed connected")
                    result.success(mapOf("success" to true))
                } else {
                    Timber.e("$TAG: Tor VPN failed to connect within timeout")
                    result.success(mapOf("success" to false, "error" to "Tor VPN tunnel failed to establish"))
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to start Tor VPN")
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    /**
     * Start Proxy VPN (Ghost Mode with free SOCKS5 proxy fallback).
     * Params: { "socksAddress": "host:port" }
     *
     * IMPORTANT: We now wait for the actual VPN connection result from TorVpnService
     * before returning success/failure to Flutter. Previously this returned success
     * immediately after firing the Intent, causing a "fake connected" state.
     */
    private fun handleStartProxyVpn(call: MethodCall, result: MethodChannel.Result) {
        val socksAddress = call.argument<String>("socksAddress") ?: ""

        Timber.i("$TAG: startProxyVpn (socks=$socksAddress)")

        if (socksAddress.isBlank()) {
            result.success(mapOf("success" to false, "error" to "No socks address"))
            return
        }

        // Ensure VPN permission is granted first
        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            Timber.d("$TAG: VPN permission needed, requesting...")
            val intent = Intent(activity, TorVpnService::class.java).apply {
                action = TorVpnService.ACTION_START
                putExtra(TorVpnService.EXTRA_MODE, "proxy")
                putExtra(TorVpnService.EXTRA_SOCKS_ADDRESS, socksAddress)
            }
            pendingVpnResult = result
            pendingVpnIntent = intent
            activity.startActivityForResult(prepareIntent, VPN_PREPARE_REQUEST)
            return
        }

        try {
            val intent = Intent(activity, TorVpnService::class.java).apply {
                action = TorVpnService.ACTION_START
                putExtra(TorVpnService.EXTRA_MODE, "proxy")
                putExtra(TorVpnService.EXTRA_SOCKS_ADDRESS, socksAddress)
            }
            activity.startForegroundService(intent)

            // Wait for the actual connection result instead of returning immediately.
            // Poll TorVpnService.isActive for up to 8 seconds to confirm the tunnel
            // was established successfully (tun2socks started, TUN interface created).
            scope.launch {
                var connected = false
                for (i in 1..16) { // 16 x 500ms = 8 seconds max
                    delay(500)
                    if (TorVpnService.isActive) {
                        connected = true
                        break
                    }
                    // If the service instance already died/stopped, fail early
                    if (TorVpnService.instance == null && i > 4) {
                        Timber.w("$TAG: TorVpnService instance is null after ${i * 500}ms")
                        break
                    }
                }
                if (connected) {
                    Timber.i("$TAG: Proxy VPN confirmed connected")
                    result.success(mapOf("success" to true))
                } else {
                    Timber.e("$TAG: Proxy VPN failed to connect within timeout")
                    result.success(mapOf("success" to false, "error" to "VPN tunnel failed to establish (tun2socks not available or proxy unreachable)"))
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to start proxy VPN")
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    /**
     * Stop Tor/Proxy VPN.
     */
    private fun handleStopTorVpn(result: MethodChannel.Result) {
        Timber.i("$TAG: stopTorVpn")
        try {
            TorVpnService.instance?.stopTorVpn()
                ?: run {
                    // Service might not be running, try sending stop intent anyway
                    val intent = Intent(activity, TorVpnService::class.java).apply {
                        action = TorVpnService.ACTION_STOP
                    }
                    activity.startService(intent)
                }
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to stop Tor VPN")
            result.success(mapOf("success" to false, "error" to e.message))
        }
    }

    /**
     * Request new Tor circuit (SIGNAL NEWNYM) → new exit IP.
     */
    private fun handleNewCircuit(result: MethodChannel.Result) {
        scope.launch {
            try {
                val torEngine = getTorEngine()
                if (torEngine != null) {
                    val success = torEngine.requestNewCircuit()
                    result.success(mapOf(
                        "success" to success,
                        "exitCountry" to torEngine.currentExitCountry
                    ))
                } else {
                    result.success(mapOf("success" to false, "error" to "Tor not running"))
                }
            } catch (e: Exception) {
                result.success(mapOf("success" to false, "error" to e.message))
            }
        }
    }

    /**
     * Get current Tor VPN status.
     */
    private fun handleGetStatus(result: MethodChannel.Result) {
        val service = TorVpnService.instance
        result.success(mapOf(
            "isActive" to TorVpnService.isActive,
            "isRunning" to (service != null),
            "bootstrapProgress" to (getTorEngine()?.bootstrapProgress ?: 0),
            "exitCountry" to (getTorEngine()?.currentExitCountry)
        ))
    }

    /**
     * Get detailed Tor circuit info.
     */
    private fun handleGetCircuitInfo(result: MethodChannel.Result) {
        scope.launch {
            try {
                val torEngine = getTorEngine()
                if (torEngine != null) {
                    val info = torEngine.getCircuitInfo()
                    result.success(info)
                } else {
                    result.success(mapOf("error" to "Tor not running"))
                }
            } catch (e: Exception) {
                result.success(mapOf("error" to e.message))
            }
        }
    }

    /**
     * Check if Tor binary is available on device.
     */
    private fun handleIsTorAvailable(result: MethodChannel.Result) {
        val nativeLibDir = activity.applicationInfo.nativeLibraryDir
        var torAvailable = false
        var torPath = ""
        var tun2socksAvailable = false
        var tun2socksPath = ""

        // Search for libtor.so and libtun2socks.so
        // 1. Primary: nativeLibraryDir
        val torNative = java.io.File(nativeLibDir, "libtor.so")
        val tun2Native = java.io.File(nativeLibDir, "libtun2socks.so")
        if (torNative.exists()) { torAvailable = true; torPath = torNative.absolutePath }
        if (tun2Native.exists()) { tun2socksAvailable = true; tun2socksPath = tun2Native.absolutePath }

        // 2. Check filesDir (extracted)
        if (!torAvailable) {
            val extractedTor = java.io.File(activity.filesDir, "tor")
            if (extractedTor.exists()) { torAvailable = true; torPath = extractedTor.absolutePath }
        }
        if (!tun2socksAvailable) {
            val extractedTun2 = java.io.File(activity.filesDir, "tun2socks")
            if (extractedTun2.exists()) { tun2socksAvailable = true; tun2socksPath = extractedTun2.absolutePath }
        }

        // 3. Fallback: search all arch directories
        if (!torAvailable || !tun2socksAvailable) {
            val libBaseDir = java.io.File(nativeLibDir).parentFile
            if (libBaseDir != null && libBaseDir.exists()) {
                libBaseDir.listFiles()?.forEach { archDir ->
                    if (!torAvailable) {
                        val torFile = java.io.File(archDir, "libtor.so")
                        if (torFile.exists()) { torAvailable = true; torPath = torFile.absolutePath }
                    }
                    if (!tun2socksAvailable) {
                        val tun2File = java.io.File(archDir, "libtun2socks.so")
                        if (tun2File.exists()) { tun2socksAvailable = true; tun2socksPath = tun2File.absolutePath }
                    }
                }
            }
        }

        // Both binaries needed for full Ghost/Tor mode
        val fullyAvailable = torAvailable && tun2socksAvailable

        // Debug logging
        timber.log.Timber.d("TorAvail: tor=$torAvailable ($torPath), tun2socks=$tun2socksAvailable ($tun2socksPath), nativeLibDir=$nativeLibDir")

        result.success(mapOf(
            "available" to fullyAvailable,
            "torAvailable" to torAvailable,
            "tun2socksAvailable" to tun2socksAvailable,
            "nativeLibPath" to torPath,
            "tun2socksPath" to tun2socksPath,
            "nativeLibDir" to nativeLibDir,
            "exists" to fullyAvailable
        ))
    }

    /**
     * Setup callbacks from TorVpnService → Flutter.
     */
    private fun setupServiceCallbacks() {
        // We poll the service state since it might start after this handler
        scope.launch {
            while (isActive) {
                delay(500) // Check every 500ms
                val service = TorVpnService.instance ?: continue

                // Set up callbacks if not already set
                if (service.onBootstrapProgress == null) {
                    service.onBootstrapProgress = { progress ->
                        activity.runOnUiThread {
                            channel.invokeMethod("onBootstrapProgress", mapOf("progress" to progress))
                        }
                    }
                }
                if (service.onStateChanged == null) {
                    service.onStateChanged = { state ->
                        activity.runOnUiThread {
                            channel.invokeMethod("onStateChanged", mapOf("state" to state))
                        }
                    }
                }
                if (service.onError == null) {
                    service.onError = { error ->
                        activity.runOnUiThread {
                            channel.invokeMethod("onError", mapOf("error" to error))
                        }
                    }
                }

                // If service is connected, we can stop polling so frequent
                if (TorVpnService.isActive) {
                    delay(5000)
                }
            }
        }
    }

    /**
     * Get TorEngine from the running service.
     */
    private fun getTorEngine(): TorEngine? {
        return try {
            // Access via reflection since TorEngine is private in TorVpnService
            val service = TorVpnService.instance ?: return null
            val field = service.javaClass.getDeclaredField("torEngine")
            field.isAccessible = true
            field.get(service) as? TorEngine
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Handle VPN permission result from system dialog.
     * Call this from MainActivity.onActivityResult()
     */
    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode == VPN_PREPARE_REQUEST) {
            val result = pendingVpnResult
            val intent = pendingVpnIntent
            pendingVpnResult = null
            pendingVpnIntent = null

            if (resultCode == Activity.RESULT_OK && intent != null) {
                try {
                    activity.startForegroundService(intent)
                    result?.success(mapOf("success" to true))
                } catch (e: Exception) {
                    Timber.e(e, "$TAG: Failed to start VPN after permission granted")
                    result?.success(mapOf("success" to false, "error" to e.message))
                }
            } else {
                Timber.w("$TAG: VPN permission denied by user")
                result?.success(mapOf("success" to false, "error" to "VPN permission denied"))
            }
        }
    }

    fun cleanup() {
        scope.cancel()
        Timber.d("$TAG: Cleaned up")
    }
}
