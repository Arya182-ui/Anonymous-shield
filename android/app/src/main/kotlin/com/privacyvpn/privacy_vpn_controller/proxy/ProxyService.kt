package com.privacyvpn.privacy_vpn_controller.proxy

import android.app.Service
import android.content.Intent
import android.os.IBinder
import timber.log.Timber

/**
 * Proxy service for SOCKS5/Shadowsocks connections
 */
class ProxyService : Service() {
    
    override fun onCreate() {
        super.onCreate()
        Timber.d("ProxyService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Timber.d("ProxyService start command received")
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Timber.d("ProxyService destroyed")
    }
}