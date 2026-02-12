package com.privacyvpn.privacy_vpn_controller

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.vpn.VpnControllerService
import com.privacyvpn.privacy_vpn_controller.proxy.ProxyService
import com.privacyvpn.privacy_vpn_controller.channels.VpnMethodChannelHandler
import com.privacyvpn.privacy_vpn_controller.channels.ProxyMethodChannelHandler
import com.privacyvpn.privacy_vpn_controller.channels.SystemMethodChannelHandler
import com.privacyvpn.privacy_vpn_controller.channels.PerformanceMethodChannelHandler

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val VPN_CHANNEL = "com.privacyvpn.vpn_controller/vpn"
        private const val PROXY_CHANNEL = "com.privacyvpn.vpn_controller/proxy"
        private const val SYSTEM_CHANNEL = "com.privacyvpn.vpn_controller/system"
        private const val PERFORMANCE_CHANNEL = "privacy_vpn_controller/performance"
        private const val VPN_PERMISSION_REQUEST = 1001
    }
    
    private lateinit var vpnMethodChannel: MethodChannel
    private lateinit var proxyMethodChannel: MethodChannel
    private lateinit var systemMethodChannel: MethodChannel
    private lateinit var performanceMethodChannel: MethodChannel
    
    private lateinit var vpnChannelHandler: VpnMethodChannelHandler
    private lateinit var proxyChannelHandler: ProxyMethodChannelHandler
    private lateinit var systemChannelHandler: SystemMethodChannelHandler
    private lateinit var performanceChannelHandler: PerformanceMethodChannelHandler
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize Timber logging for debug builds only
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
        
        Timber.d("MainActivity created")
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Timber.d("Configuring Flutter engine with method channels")
        
        // Initialize method channels
        vpnMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
        proxyMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROXY_CHANNEL)  
        systemMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
        performanceMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERFORMANCE_CHANNEL)
        
        // Initialize channel handlers
        vpnChannelHandler = VpnMethodChannelHandler(this, vpnMethodChannel)
        proxyChannelHandler = ProxyMethodChannelHandler(this, proxyMethodChannel)
        systemChannelHandler = SystemMethodChannelHandler(this, systemMethodChannel)
        performanceChannelHandler = PerformanceMethodChannelHandler(this, performanceMethodChannel)
        
        // Set VPN channel notifier
        com.privacyvpn.privacy_vpn_controller.vpn.VpnChannelNotifier.setChannelHandler(vpnChannelHandler)
        
        // Set method call handlers
        vpnMethodChannel.setMethodCallHandler(vpnChannelHandler)
        proxyMethodChannel.setMethodCallHandler(proxyChannelHandler)
        systemMethodChannel.setMethodCallHandler(systemChannelHandler)
        performanceMethodChannel.setMethodCallHandler(performanceChannelHandler)
        
        Timber.d("Method channels configured successfully")
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            VPN_PERMISSION_REQUEST -> {
                val success = resultCode == Activity.RESULT_OK
                Timber.d("VPN permission result: $success")
                vpnChannelHandler.onVpnPermissionResult(success)
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Clean up channel handlers
        if (::vpnChannelHandler.isInitialized) {
            vpnChannelHandler.cleanup()
        }
        if (::proxyChannelHandler.isInitialized) {
            proxyChannelHandler.cleanup()
        }
        if (::systemChannelHandler.isInitialized) {
            systemChannelHandler.cleanup()
        }
        if (::performanceChannelHandler.isInitialized) {
            performanceChannelHandler.cleanup()
        }
        
        // Clear VPN channel notifier
        com.privacyvpn.privacy_vpn_controller.vpn.VpnChannelNotifier.clearChannelHandler()
        
        Timber.d("MainActivity destroyed")
    }
    
    /**
     * Request VPN permission from Android system
     */
    fun requestVpnPermission() {
        try {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                Timber.d("Requesting VPN permission")
                startActivityForResult(intent, VPN_PERMISSION_REQUEST)
            } else {
                Timber.d("VPN permission already granted")
                vpnChannelHandler.onVpnPermissionResult(true)
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to request VPN permission")
            vpnChannelHandler.onVpnPermissionResult(false)
        }
    }
    
    /**
     * Check if VPN permission is already granted
     */
    fun checkVpnPermission(): Boolean {
        return try {
            val intent = VpnService.prepare(this)
            intent == null
        } catch (e: Exception) {
            Timber.e(e, "Failed to check VPN permission")
            false
        }
    }
}
