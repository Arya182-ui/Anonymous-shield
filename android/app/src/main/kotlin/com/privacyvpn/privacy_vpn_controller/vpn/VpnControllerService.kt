package com.privacyvpn.privacy_vpn_controller.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import timber.log.Timber
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * VPN Controller Service for Privacy VPN Controller.
 * This service manages VPN connections using the wireguard_flutter_plus plugin.
 * The actual WireGuard tunnel management is delegated to the Flutter plugin.
 */
class VpnControllerService : VpnService() {
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "vpn_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_DISCONNECT = "DISCONNECT_VPN"
        
        // Service state management
        private val isRunning = AtomicBoolean(false)
        private val currentConfig = AtomicReference<VpnConfiguration?>(null)
        
        fun isServiceRunning(): Boolean = isRunning.get()
        fun getCurrentConfig(): VpnConfiguration? = currentConfig.get()
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // VPN interface descriptor (managed by WireGuard plugin)
    private var vpnInterface: ParcelFileDescriptor? = null
    
    // Connection monitoring
    private var connectionMonitor: ConnectionMonitor? = null
    private var killSwitch: KillSwitch? = null
    
    // Statistics tracking
    private var statisticsJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        Timber.d("VpnControllerService created")
        
        createNotificationChannel()
        
        connectionMonitor = ConnectionMonitor(this)
        killSwitch = KillSwitch(this)
        
        isRunning.set(true)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                Timber.d("Disconnect action received via notification")
                disconnectVpn()
                return START_NOT_STICKY
            }
            else -> {
                @Suppress("DEPRECATION")
                val config = intent?.getSerializableExtra("vpn_config") as? VpnConfiguration
                if (config != null) {
                    startVpnConnection(config)
                }
            }
        }
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Timber.d("VpnControllerService destroyed")
        
        disconnectVpn()
        serviceScope.cancel()
        isRunning.set(false)
        currentConfig.set(null)
    }
    
    /**
     * Start VPN connection with given configuration.
     * The actual WireGuard tunnel is managed by wireguard_flutter_plus plugin.
     */
    private fun startVpnConnection(config: VpnConfiguration) {
        serviceScope.launch {
            try {
                Timber.d("Starting VPN connection to ${config.name}")
                
                // Store current configuration
                currentConfig.set(config)
                
                // Start connection monitoring
                startConnectionMonitoring()
                
                // Start statistics collection
                startStatisticsMonitoring()
                
                // Show persistent notification
                startForeground(NOTIFICATION_ID, createNotification(config, true))
                
                // Enable kill switch if configured
                if (config.enableKillSwitch) {
                    killSwitch?.enableKillSwitch(config)
                }
                
                // Notify Flutter app of connection success
                notifyConnectionState(VpnState.CONNECTED, config)
                
                Timber.i("VPN connection established successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Failed to start VPN connection")
                notifyConnectionState(VpnState.ERROR, config, e.message)
                disconnectVpn()
            }
        }
    }
    
    /**
     * Disconnect VPN and clean up resources
     */
    private fun disconnectVpn() {
        serviceScope.launch {
            try {
                Timber.d("Disconnecting VPN")
                
                val config = currentConfig.get()
                
                // Disable kill switch first to allow normal traffic
                killSwitch?.disableKillSwitch()
                
                // Stop statistics monitoring
                statisticsJob?.cancel()
                
                // Stop connection monitoring
                connectionMonitor?.stopMonitoring()
                
                // Clear current configuration
                currentConfig.set(null)
                
                // Notify Flutter app of disconnection
                notifyConnectionState(VpnState.DISCONNECTED, config)
                
                // Stop foreground service
                @Suppress("DEPRECATION")
                stopForeground(true)
                stopSelf()
                
                Timber.i("VPN disconnected successfully")
                
            } catch (e: Exception) {
                Timber.e(e, "Error during VPN disconnection")
            }
        }
    }
    
    /**
     * Start connection monitoring
     */
    private fun startConnectionMonitoring() {
        connectionMonitor?.startMonitoring { isConnected: Boolean ->
            serviceScope.launch {
                val config = currentConfig.get()
                if (!isConnected && config != null) {
                    Timber.w("Connection lost, attempting reconnection")
                    notifyConnectionState(VpnState.RECONNECTING, config)
                    
                    // Attempt reconnection
                    try {
                        delay(2000) // Wait before reconnecting
                        startVpnConnection(config)
                    } catch (e: Exception) {
                        Timber.e(e, "Reconnection failed")
                        notifyConnectionState(VpnState.ERROR, config, "Reconnection failed")
                        disconnectVpn()
                    }
                }
            }
        }
    }
    
    /**
     * Start statistics monitoring
     */
    private fun startStatisticsMonitoring() {
        statisticsJob = serviceScope.launch {
            while (isActive) {
                try {
                    // Basic statistics - actual stats come from wireguard_flutter_plus plugin
                    val statsMap = mapOf(
                        "bytesIn" to 0L,
                        "bytesOut" to 0L,
                        "packetsIn" to 0L,
                        "packetsOut" to 0L
                    )
                    
                    // Notify Flutter app with statistics
                    notifyStatistics(statsMap)
                } catch (e: Exception) {
                    Timber.e(e, "Failed to retrieve statistics")
                }
                
                delay(5000) // Update every 5 seconds
            }
        }
    }
    
    /**
     * Create notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Connection Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
                setShowBadge(false)
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    /**
     * Create notification for VPN connection status
     */
    private fun createNotification(config: VpnConfiguration, isConnected: Boolean): Notification {
        val disconnectIntent = Intent(this, VpnControllerService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Privacy VPN Controller")
            .setContentText(
                if (isConnected) "Connected to ${config.name}"
                else "Connecting to ${config.name}..."
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(getPendingIntent())
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Disconnect",
                disconnectPendingIntent
            )
            .build()
    }
    
    /**
     * Get pending intent for notification tap
     */
    private fun getPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
    
    /**
     * Notify Flutter app of connection state changes
     */
    private fun notifyConnectionState(state: VpnState, config: VpnConfiguration?, errorMessage: String? = null) {
        // This will be called via method channel to notify Flutter
        VpnChannelNotifier.notifyConnectionState(state, config, errorMessage)
    }
    
    /**
     * Notify Flutter app of statistics
     */
    private fun notifyStatistics(statistics: Map<String, Any>) {
        VpnChannelNotifier.notifyStatistics(statistics)
    }
}