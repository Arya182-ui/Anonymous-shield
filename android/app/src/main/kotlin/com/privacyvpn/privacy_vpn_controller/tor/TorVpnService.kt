package com.privacyvpn.privacy_vpn_controller.tor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import timber.log.Timber
import com.privacyvpn.privacy_vpn_controller.MainActivity

/**
 * Android VpnService that routes ALL device traffic through Tor or a SOCKS5 proxy.
 *
 * Architecture:
 *   [Device Apps] → [TUN interface] → [tun2socks] → [Tor SOCKS5 127.0.0.1:9050]
 *                                                   → OR [Free SOCKS5 proxy]
 *                                                         → [Tor Network / Proxy]
 *                                                             → [Internet]
 *
 * Only ONE VpnService can be active at a time on Android.
 * When Ghost mode activates, WireGuard VPN must stop first.
 */
class TorVpnService : VpnService() {

    companion object {
        private const val TAG = "TorVpnService"
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "tor_vpn_channel"
        private const val TUN_MTU = 1500

        const val ACTION_START = "com.privacyvpn.tor.START"
        const val ACTION_STOP = "com.privacyvpn.tor.STOP"
        const val ACTION_NEW_CIRCUIT = "com.privacyvpn.tor.NEW_CIRCUIT"

        const val EXTRA_USE_BRIDGES = "use_bridges"
        const val EXTRA_SOCKS_ADDRESS = "socks_address"
        const val EXTRA_MODE = "mode" // "tor" or "proxy"

        @Volatile
        var instance: TorVpnService? = null
            private set

        @Volatile
        var isActive: Boolean = false
            private set
    }

    private var torEngine: TorEngine? = null
    private var tun2socksEngine: Tun2SocksEngine? = null
    private var tunInterface: ParcelFileDescriptor? = null
    private var serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var wakeLock: PowerManager.WakeLock? = null

    // Callbacks for Flutter via method channel
    var onBootstrapProgress: ((Int) -> Unit)? = null
    var onStateChanged: ((String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        acquireWakeLock()
        Timber.i("$TAG: Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val useBridges = intent.getBooleanExtra(EXTRA_USE_BRIDGES, false)
                val mode = intent.getStringExtra(EXTRA_MODE) ?: "tor"
                val socksAddress = intent.getStringExtra(EXTRA_SOCKS_ADDRESS)

                startForeground(NOTIFICATION_ID, buildNotification("Connecting..."))

                serviceScope.launch {
                    when (mode) {
                        "tor" -> startWithTor(useBridges)
                        "proxy" -> startWithProxy(socksAddress ?: "")
                        else -> startWithTor(useBridges)
                    }
                }
            }
            ACTION_STOP -> {
                stopTorVpn()
            }
            ACTION_NEW_CIRCUIT -> {
                serviceScope.launch {
                    torEngine?.requestNewCircuit()
                }
            }
        }
        return START_STICKY
    }

    /**
     * Start VPN routing through Tor.
     */
    private suspend fun startWithTor(useBridges: Boolean) {
        try {
            onStateChanged?.invoke("starting_tor")
            updateNotification("Starting Tor...")

            // Initialize Tor engine
            torEngine = TorEngine(this)
            val bootstrapped = torEngine!!.start(
                useBridges = useBridges,
                onBootstrapProgress = { progress ->
                    onBootstrapProgress?.invoke(progress)
                    updateNotification("Tor: $progress% bootstrapped")
                }
            )

            if (!bootstrapped) {
                onError?.invoke("Tor failed to bootstrap")
                onStateChanged?.invoke("error")
                stopSelf()
                return
            }

            // Create TUN and start tun2socks → Tor SOCKS5
            val socksAddr = "127.0.0.1:${torEngine!!.socksPort}"
            val dnsAddr = "127.0.0.1:${torEngine!!.dnsPort}"

            val started = setupTunAndTun2Socks(socksAddr, dnsAddr)
            if (started) {
                isActive = true
                onStateChanged?.invoke("connected")
                updateNotification("Ghost Mode Active — Protected via Tor 🧅")
            } else {
                onError?.invoke("Failed to setup VPN tunnel")
                onStateChanged?.invoke("error")
                stopTorVpn()
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to start Tor VPN")
            onError?.invoke(e.message ?: "Unknown error")
            onStateChanged?.invoke("error")
            stopTorVpn()
        }
    }

    /**
     * Start VPN routing through a free SOCKS5 proxy (fallback).
     */
    private suspend fun startWithProxy(socksAddress: String) {
        try {
            if (socksAddress.isBlank()) {
                onError?.invoke("No proxy address provided")
                stopSelf()
                return
            }

            onStateChanged?.invoke("starting_proxy")
            updateNotification("Connecting to proxy...")

            val started = setupTunAndTun2Socks(socksAddress, "")
            if (started) {
                isActive = true
                onStateChanged?.invoke("connected")
                updateNotification("Ghost Mode Active — Proxy 🛡️")
            } else {
                onError?.invoke("Failed to setup proxy VPN tunnel")
                onStateChanged?.invoke("error")
                stopTorVpn()
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to start proxy VPN")
            onError?.invoke(e.message ?: "Unknown error")
            stopTorVpn()
        }
    }

    /**
     * Create TUN interface and start tun2socks to proxy all traffic.
     */
    private fun setupTunAndTun2Socks(socksAddress: String, dnsAddress: String): Boolean {
        try {
            Timber.i("$TAG: Setting up TUN → tun2socks → $socksAddress")

            // Build TUN interface
            val builder = Builder()
                .setSession("GhostMode")
                .setMtu(TUN_MTU)
                .addAddress("10.0.0.2", 30) // TUN IP
                .addRoute("0.0.0.0", 0) // Route ALL IPv4
                .addDnsServer("1.1.1.1") // DNS through tunnel

            // For Tor mode, also route IPv6 if supported
            try {
                builder.addAddress("fd00::2", 126)
                builder.addRoute("::", 0) // Route ALL IPv6
            } catch (_: Exception) {
                Timber.d("$TAG: IPv6 not available, skipping")
            }

            // Exclude Tor's own connection from the VPN to prevent loops
            // Tor connects to guard nodes on the real network
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
                Timber.w("$TAG: Could not exclude own package from VPN")
            }

            tunInterface = builder.establish()
            if (tunInterface == null) {
                Timber.e("$TAG: Failed to establish TUN interface (VPN permission denied?)")
                return false
            }

            // Initialize and start tun2socks as a subprocess
            // The Go binary runs as: libtun2socks.so -device fd://N -proxy socks5://HOST:PORT
            tun2socksEngine = Tun2SocksEngine(this)
            val tunFd = tunInterface!!.fd
            val started = tun2socksEngine!!.start(
                tunFd = tunFd,
                socksAddress = socksAddress,
                dnsAddress = dnsAddress,
                tunMtu = TUN_MTU
            )

            if (!started) {
                Timber.e("$TAG: tun2socks failed to start")
                tunInterface?.close()
                tunInterface = null
                return false
            }

            Timber.i("$TAG: TUN + tun2socks running, all traffic routed through $socksAddress")
            return true
        } catch (e: Throwable) {
            Timber.e(e, "$TAG: Failed to setup TUN + tun2socks")
            return false
        }
    }

    /**
     * Stop everything and clean up.
     */
    fun stopTorVpn() {
        Timber.i("$TAG: Stopping Tor VPN...")
        
        serviceScope.cancel()
        serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

        // Stop tun2socks
        tun2socksEngine?.stop()
        tun2socksEngine = null

        // Close TUN
        try {
            tunInterface?.close()
        } catch (_: Exception) {}
        tunInterface = null

        // Stop Tor
        torEngine?.stop()
        torEngine = null

        isActive = false
        onStateChanged?.invoke("disconnected")

        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()

        Timber.i("$TAG: Tor VPN stopped")
    }

    override fun onDestroy() {
        // Only clean up instance reference; don't stop VPN if still active
        // (service may be restarted via START_STICKY)
        if (!isActive) {
            stopTorVpn()
        }
        instance = null
        super.onDestroy()
        Timber.i("$TAG: Service destroyed (isActive=$isActive)")
    }

    override fun onRevoke() {
        Timber.w("$TAG: VPN revoked by system or another VPN app")
        stopTorVpn()
    }

    /**
     * Called when user swipes the app from recent tasks.
     * Keep VPN running in the background — don't stop.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Timber.i("$TAG: App task removed, VPN continues running in background")
        // Do NOT call stopTorVpn — let the foreground service keep running
        super.onTaskRemoved(rootIntent)
    }

    // ==================== Wake Lock ====================

    /**
     * Acquire a partial wake lock to keep CPU running while Ghost mode is active.
     * Without this, Android may suspend the CPU and kill Tor/tun2socks processes.
     */
    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GhostMode::TorVpnWakeLock"
            ).apply {
                // Acquire with 24-hour timeout as safety net
                acquire(24 * 60 * 60 * 1000L)
            }
            Timber.i("$TAG: Wake lock acquired for background operation")
        } catch (e: Exception) {
            Timber.w(e, "$TAG: Failed to acquire wake lock")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Timber.i("$TAG: Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Timber.w(e, "$TAG: Failed to release wake lock")
        }
    }

    // ==================== Notification ====================

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ghost Mode VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Ghost Mode (Tor) is active"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val stopIntent = Intent(this, TorVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghost Mode")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }
}
