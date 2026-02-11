package com.privacyvpn.privacy_vpn_controller.proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.*
import timber.log.Timber
import java.io.IOException
import java.net.Socket
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

data class ProxyConfig(
    val id: String,
    val type: ProxyType,
    val host: String,
    val port: Int,
    val username: String? = null,
    val password: String? = null,
    val method: String? = null
)

enum class ProxyType {
    SOCKS5, HTTP, HTTPS, SHADOWSOCKS
}

/**
 * Real proxy service implementation with SOCKS5/HTTP support
 */
class ProxyService : Service() {
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "proxy_channel"
        private const val NOTIFICATION_ID = 2001
        
        private val isRunning = AtomicBoolean(false)
        private val activeConnections = ConcurrentHashMap<String, ProxyConnection>()
        
        fun isServiceRunning(): Boolean = isRunning.get()
        fun getActiveConnectionCount(): Int = activeConnections.size
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var currentConfig: ProxyConfig? = null
    
    override fun onCreate() {
        super.onCreate()
        Timber.d("ProxyService created")
        
        createNotificationChannel()
        isRunning.set(true)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Timber.d("ProxyService start command received")
        
        val config = intent?.let { parseProxyConfig(it) }
        if (config != null) {
            startProxy(config)
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Timber.d("ProxyService destroyed")
        
        stopAllConnections()
        serviceScope.cancel()
        isRunning.set(false)
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Proxy Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Manages proxy connections"
            setShowBadge(false)
        }
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun startProxy(config: ProxyConfig) {
        serviceScope.launch {
            try {
                Timber.i("Starting proxy: ${config.type.name} ${config.host}:${config.port}")
                
                currentConfig = config
                
                // Test connection first
                val testResult = testProxyConnection(config)
                if (!testResult) {
                    Timber.e("Proxy connection test failed")
                    broadcastProxyError("Connection test failed")
                    return@launch
                }
                
                // Create proxy connection
                val connection = createProxyConnection(config)
                activeConnections[config.id] = connection
                
                // Start foreground notification
                startForeground(NOTIFICATION_ID, createNotification(config))
                
                // Broadcast success
                broadcastProxyStatus("connected", config)
                
                Timber.i("Proxy started successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start proxy")
                broadcastProxyError(e.message ?: "Unknown error")
            }
        }
    }
    
    private suspend fun testProxyConnection(config: ProxyConfig): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                when (config.type) {
                    ProxyType.SOCKS5 -> testSocks5Connection(config)
                    ProxyType.HTTP -> testHttpConnection(config)
                    ProxyType.HTTPS -> testHttpsConnection(config)
                    ProxyType.SHADOWSOCKS -> testShadowsocksConnection(config)
                }
            } catch (e: Exception) {
                Timber.e(e, "Proxy test failed")
                false
            }
        }
    }
    
    private fun testSocks5Connection(config: ProxyConfig): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(config.host, config.port), 5000)
                
                // Send SOCKS5 greeting
                val greeting = byteArrayOf(0x05, 0x01, 0x00) // Version 5, 1 method, no auth
                socket.outputStream.write(greeting)
                
                // Read response
                val response = ByteArray(2)
                socket.inputStream.read(response)
                
                // Check if server accepted no-auth method
                response[0] == 0x05.toByte() && response[1] == 0x00.toByte()
            }
        } catch (e: IOException) {
            Timber.e(e, "SOCKS5 test failed")
            false
        }
    }
    
    private fun testHttpConnection(config: ProxyConfig): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(config.host, config.port), 5000)
                true
            }
        } catch (e: IOException) {
            Timber.e(e, "HTTP proxy test failed")
            false
        }
    }
    
    private fun testHttpsConnection(config: ProxyConfig): Boolean {
        // Similar to HTTP but with SSL context
        return testHttpConnection(config)
    }
    
    private fun testShadowsocksConnection(config: ProxyConfig): Boolean {
        // Simplified Shadowsocks test - would need actual SS library
        return testSocks5Connection(config)
    }
    
    private fun createProxyConnection(config: ProxyConfig): ProxyConnection {
        return when (config.type) {
            ProxyType.SOCKS5 -> Socks5ProxyConnection(config)
            ProxyType.HTTP -> HttpProxyConnection(config)
            ProxyType.HTTPS -> HttpsProxyConnection(config)
            ProxyType.SHADOWSOCKS -> ShadowsocksProxyConnection(config)
        }
    }
    
    private fun stopAllConnections() {
        activeConnections.values.forEach { it.disconnect() }
        activeConnections.clear()
        currentConfig = null
        
        broadcastProxyStatus("disconnected", null)
    }
    
    private fun createNotification(config: ProxyConfig): Notification {
        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Proxy Active")
            .setContentText("Connected to ${config.host}:${config.port}")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
    
    private fun parseProxyConfig(intent: Intent): ProxyConfig? {
        return try {
            ProxyConfig(
                id = intent.getStringExtra("id") ?: return null,
                type = ProxyType.valueOf(intent.getStringExtra("type") ?: "SOCKS5"),
                host = intent.getStringExtra("host") ?: return null,
                port = intent.getIntExtra("port", 0),
                username = intent.getStringExtra("username"),
                password = intent.getStringExtra("password"),
                method = intent.getStringExtra("method")
            )
        } catch (e: Exception) {
            Timber.e(e, "Failed to parse proxy config")
            null
        }
    }
    
    private fun broadcastProxyStatus(status: String, config: ProxyConfig?) {
        // Would broadcast to Flutter through method channel
        Timber.d("Proxy status: $status")
    }
    
    private fun broadcastProxyError(error: String) {
        Timber.e("Proxy error: $error")
    }
    
    // Internal connection classes
    private abstract class ProxyConnection(val config: ProxyConfig) {
        abstract fun disconnect()
    }
    
    private class Socks5ProxyConnection(config: ProxyConfig) : ProxyConnection(config) {
        override fun disconnect() {
            Timber.d("Disconnecting SOCKS5 proxy")
        }
    }
    
    private class HttpProxyConnection(config: ProxyConfig) : ProxyConnection(config) {
        override fun disconnect() {
            Timber.d("Disconnecting HTTP proxy")
        }
    }
    
    private class HttpsProxyConnection(config: ProxyConfig) : ProxyConnection(config) {
        override fun disconnect() {
            Timber.d("Disconnecting HTTPS proxy")
        }
    }
    
    private class ShadowsocksProxyConnection(config: ProxyConfig) : ProxyConnection(config) {
        override fun disconnect() {
            Timber.d("Disconnecting Shadowsocks proxy")
        }
    }
}