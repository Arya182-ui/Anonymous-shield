package com.privacyvpn.privacy_vpn_controller.tor

import android.content.Context
import kotlinx.coroutines.*
import timber.log.Timber
import java.io.*
import java.net.Socket

/**
 * Manages the Tor process lifecycle.
 *
 * Starts Tor binary, writes torrc, monitors bootstrap progress,
 * and provides circuit control (NEWNYM for IP rotation).
 *
 * Tor binary must be placed in app's native libs (jniLibs) as libtor.so
 * or extracted to filesDir at first run.
 */
class TorEngine(private val context: Context) {

    companion object {
        private const val TAG = "TorEngine"
        private const val TOR_SOCKS_PORT = 9050
        private const val TOR_CONTROL_PORT = 9051
        private const val TOR_DNS_PORT = 5400
        private const val BOOTSTRAP_TIMEOUT_MS = 60_000L
        private const val CONTROL_AUTH_COOKIE_FILE = "control_auth_cookie"
    }

    private var torProcess: Process? = null
    private var controlSocket: Socket? = null
    private val torDataDir: File get() = File(context.filesDir, "tor_data")
    private val torCacheDir: File get() = File(context.cacheDir, "tor_cache")
    private val torrcFile: File get() = File(context.filesDir, "torrc")

    @Volatile
    var bootstrapProgress: Int = 0
        private set

    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    var currentExitCountry: String? = null
        private set

    val socksPort: Int get() = TOR_SOCKS_PORT
    val dnsPort: Int get() = TOR_DNS_PORT

    /**
     * Start the Tor process with generated torrc configuration.
     * @param useBridges Whether to use pluggable transports (meek/obfs4) for censorship evasion
     * @param onBootstrapProgress Callback for bootstrap progress updates (0-100)
     * @return true if Tor bootstrapped successfully
     */
    suspend fun start(
        useBridges: Boolean = false,
        onBootstrapProgress: ((Int) -> Unit)? = null
    ): Boolean = withContext(Dispatchers.IO) {
        if (isRunning) {
            Timber.w("$TAG: Tor is already running")
            return@withContext true
        }

        try {
            Timber.i("$TAG: Starting Tor engine...")

            // Prepare directories
            torDataDir.mkdirs()
            torCacheDir.mkdirs()

            // Find Tor binary
            val torBinary = findTorBinary()
            if (torBinary == null) {
                Timber.e("$TAG: Tor binary not found!")
                return@withContext false
            }

            // Make executable
            torBinary.setExecutable(true, false)

            // Write torrc configuration
            writeTorrc(useBridges)

            // Start Tor process
            val processBuilder = ProcessBuilder(
                torBinary.absolutePath,
                "-f", torrcFile.absolutePath,
                "--DataDirectory", torDataDir.absolutePath,
                "--CacheDirectory", torCacheDir.absolutePath
            )
            processBuilder.redirectErrorStream(true)
            processBuilder.directory(context.filesDir)

            // Set environment
            processBuilder.environment()["HOME"] = context.filesDir.absolutePath
            processBuilder.environment()["LD_LIBRARY_PATH"] = 
                "${context.applicationInfo.nativeLibraryDir}:${System.getenv("LD_LIBRARY_PATH") ?: ""}"

            torProcess = processBuilder.start()
            isRunning = true

            // Monitor bootstrap progress from stdout
            val bootstrapSuccess = monitorBootstrap(
                torProcess!!.inputStream,
                onBootstrapProgress
            )

            if (bootstrapSuccess) {
                // Connect control port
                connectControlPort()
                // Read initial exit info
                updateExitCountry()
                Timber.i("$TAG: Tor bootstrapped successfully!")
            } else {
                Timber.e("$TAG: Tor bootstrap failed/timed out")
                stop()
            }

            return@withContext bootstrapSuccess
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to start Tor")
            stop()
            return@withContext false
        }
    }

    /**
     * Stop the Tor process and clean up.
     */
    fun stop() {
        Timber.i("$TAG: Stopping Tor engine...")
        try {
            // Send SIGNAL SHUTDOWN via control port if available
            try {
                sendControlCommand("SIGNAL SHUTDOWN")
            } catch (_: Exception) {}

            // Close control connection
            try {
                controlSocket?.close()
            } catch (_: Exception) {}
            controlSocket = null

            // Kill process
            torProcess?.let { process ->
                process.destroy()
                try {
                    process.waitFor()
                } catch (_: Exception) {}
            }
            torProcess = null

            isRunning = false
            bootstrapProgress = 0
            currentExitCountry = null

            Timber.i("$TAG: Tor stopped")
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Error stopping Tor")
        }
    }

    /**
     * Request a new Tor circuit (SIGNAL NEWNYM).
     * This changes the exit node → different public IP and potentially different country.
     * Tor rate-limits NEWNYM to once per 10 seconds.
     */
    suspend fun requestNewCircuit(): Boolean = withContext(Dispatchers.IO) {
        try {
            val response = sendControlCommand("SIGNAL NEWNYM")
            val success = response?.contains("250 OK") == true
            if (success) {
                Timber.i("$TAG: New circuit requested (NEWNYM)")
                // Wait for circuit to be built
                delay(3000)
                updateExitCountry()
            }
            return@withContext success
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to request new circuit")
            return@withContext false
        }
    }

    /**
     * Get info about the current Tor circuit / exit node.
     */
    suspend fun getCircuitInfo(): Map<String, String?> = withContext(Dispatchers.IO) {
        val info = mutableMapOf<String, String?>()
        try {
            val circuitResponse = sendControlCommand("GETINFO circuit-status")
            info["circuits"] = circuitResponse

            val exitResponse = sendControlCommand("GETINFO ip-to-country/0.0.0.0")
            info["exit_country"] = exitResponse?.substringAfter("=")?.trim()

            val socksResponse = sendControlCommand("GETINFO net/listeners/socks")
            info["socks_addr"] = socksResponse?.substringAfter("=")?.trim()?.removeSurrounding("\"")
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to get circuit info")
        }
        return@withContext info
    }

    // ==================== Private Helpers ====================

    /**
     * Find the Tor binary by searching multiple locations:
     * 1. nativeLibraryDir (auto-picked by Android for device ABI)
     * 2. All jniLibs arch dirs (fallback if ABI mismatch)
     * 3. filesDir (previously extracted)
     * 4. assets (extract on first use)
     */
    private fun findTorBinary(): File? {
        // 1. Primary: nativeLibraryDir (Android auto-selects correct ABI)
        val nativeLib = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
        if (nativeLib.exists()) {
            nativeLib.setExecutable(true, false)
            Timber.d("$TAG: Found Tor binary at ${nativeLib.absolutePath}")
            return nativeLib
        }

        // 2. Fallback: search all possible lib directories
        //    (handles case where binary exists for different ABI)
        val libBaseDir = File(context.applicationInfo.nativeLibraryDir).parentFile
        if (libBaseDir != null && libBaseDir.exists()) {
            libBaseDir.listFiles()?.forEach { archDir ->
                val torFile = File(archDir, "libtor.so")
                if (torFile.exists()) {
                    torFile.setExecutable(true, false)
                    Timber.d("$TAG: Found Tor binary in ${archDir.name}: ${torFile.absolutePath}")
                    return torFile
                }
            }
        }

        // 3. Check filesDir (previously extracted)
        val extractedBin = File(context.filesDir, "tor")
        if (extractedBin.exists()) {
            extractedBin.setExecutable(true, false)
            Timber.d("$TAG: Found extracted Tor binary at ${extractedBin.absolutePath}")
            return extractedBin
        }

        // 4. Try to extract from assets
        try {
            context.assets.open("tor").use { input ->
                FileOutputStream(extractedBin).use { output ->
                    input.copyTo(output)
                }
            }
            extractedBin.setExecutable(true, false)
            if (extractedBin.exists()) {
                Timber.d("$TAG: Extracted Tor binary from assets")
                return extractedBin
            }
        } catch (_: Exception) {
            Timber.d("$TAG: No Tor binary in assets either")
        }

        return null
    }

    /**
     * Write the torrc configuration file.
     */
    private fun writeTorrc(useBridges: Boolean) {
        val cookieFile = File(torDataDir, CONTROL_AUTH_COOKIE_FILE)
        
        val config = buildString {
            // SOCKS port for tun2socks
            appendLine("SOCKSPort 127.0.0.1:$TOR_SOCKS_PORT")
            // Control port for circuit management
            appendLine("ControlPort 127.0.0.1:$TOR_CONTROL_PORT")
            // Cookie authentication for control port
            appendLine("CookieAuthentication 1")
            appendLine("CookieAuthFile ${cookieFile.absolutePath}")
            // DNS port
            appendLine("DNSPort 127.0.0.1:$TOR_DNS_PORT")
            // Auto-map hostnames for .onion resolution
            appendLine("AutomapHostsOnResolve 1")
            // Reduce disk writes
            appendLine("AvoidDiskWrites 1")
            // Allow connections from localhost only 
            appendLine("SOCKSPolicy accept 127.0.0.1/32")
            appendLine("SOCKSPolicy reject *")
            // Disable unused features
            appendLine("DisableDebuggerAttachment 1")
            // Client-only mode (no relay)
            appendLine("ClientOnly 1")
            // Safe logging
            appendLine("SafeLogging 1")
            // Log to stdout for monitoring
            appendLine("Log notice stdout")

            // Pluggable transports for CDN fronting (WARP-like ISP protection)
            if (useBridges) {
                appendLine("UseBridges 1")
                
                // Look for obfs4proxy binary
                val obfs4 = File(context.applicationInfo.nativeLibraryDir, "libobfs4proxy.so")
                if (obfs4.exists()) {
                    obfs4.setExecutable(true, false)
                    appendLine("ClientTransportPlugin obfs4 exec ${obfs4.absolutePath}")
                    // Default obfs4 bridges (from Tor Project)
                    appendLine("Bridge obfs4 193.11.166.194:27015 2D82C2E354D531A68469ADA8F3BE154571A5FF57 cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW1NXksMRYkyQGECLhJMe/MLajdDKlBjnstsvRezKACL iat-mode=0")
                    appendLine("Bridge obfs4 209.148.46.65:443 74FAD13168806246602538555B5521A0383A1875 cert=ssH+9rP8dG2NELN2XdFxN3v7Zj2UYQ/Oi1FZkvKjR94pJWvLNH/nyH0Y8N1DFJ4IxI0peQ iat-mode=0")
                }

                // Look for snowflake binary
                val snowflake = File(context.applicationInfo.nativeLibraryDir, "libsnowflake.so")
                if (snowflake.exists()) {
                    snowflake.setExecutable(true, false)
                    appendLine("ClientTransportPlugin snowflake exec ${snowflake.absolutePath}")
                    appendLine("Bridge snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ front=cdn.sstatic.net ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478,stun:stun.bluesip.net:3478,stun:stun.dus.net:3478,stun:stun.epygi.com:3478 utls-imitate=hellorandomizedalpn")
                }

                // Meek (Cloudflare/Azure fronting) — always available, no extra binary needed
                // meek-client is built into modern Tor binaries
                appendLine("Bridge meek_lite 0.0.2.0:2 97700DFE9F483596DDA6264C4D7DF7641E1E39CE url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com")
            }
        }

        torrcFile.writeText(config)
        Timber.d("$TAG: Wrote torrc (bridges=$useBridges)")
    }

    /**
     * Monitor Tor's stdout for bootstrap progress lines.
     * Returns true when bootstrap reaches 100%.
     */
    private suspend fun monitorBootstrap(
        inputStream: InputStream,
        onProgress: ((Int) -> Unit)?
    ): Boolean = withContext(Dispatchers.IO) {
        val reader = BufferedReader(InputStreamReader(inputStream))
        val startTime = System.currentTimeMillis()

        try {
            while (isRunning) {
                // Check timeout
                if (System.currentTimeMillis() - startTime > BOOTSTRAP_TIMEOUT_MS) {
                    Timber.w("$TAG: Bootstrap timeout after ${BOOTSTRAP_TIMEOUT_MS}ms")
                    return@withContext false
                }

                val line = withTimeoutOrNull(1000) {
                    withContext(Dispatchers.IO) { reader.readLine() }
                }

                if (line == null) continue

                // Parse bootstrap progress: "Bootstrapped 45% (loading_descriptors): ..."
                if (line.contains("Bootstrapped")) {
                    val match = Regex("Bootstrapped (\\d+)%").find(line)
                    if (match != null) {
                        val progress = match.groupValues[1].toIntOrNull() ?: 0
                        bootstrapProgress = progress
                        onProgress?.invoke(progress)
                        Timber.d("$TAG: Bootstrap $progress%")

                        if (progress >= 100) {
                            return@withContext true
                        }
                    }
                }

                // Detect fatal errors
                if (line.contains("[err]") || line.contains("[warn] Failing")) {
                    Timber.w("$TAG: Tor warning/error: $line")
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Error monitoring bootstrap")
        }

        return@withContext false
    }

    /**
     * Connect to Tor's control port using cookie authentication.
     */
    private fun connectControlPort() {
        try {
            controlSocket = Socket("127.0.0.1", TOR_CONTROL_PORT)
            controlSocket?.soTimeout = 5000

            // Read cookie file for authentication
            val cookieFile = File(torDataDir, CONTROL_AUTH_COOKIE_FILE)
            if (cookieFile.exists()) {
                val cookie = cookieFile.readBytes()
                val hexCookie = cookie.joinToString("") { "%02x".format(it) }
                val response = sendControlCommand("AUTHENTICATE $hexCookie")
                if (response?.contains("250 OK") == true) {
                    Timber.d("$TAG: Control port authenticated")
                } else {
                    Timber.w("$TAG: Control auth failed: $response")
                }
            } else {
                Timber.w("$TAG: Cookie file not found, trying empty auth")
                sendControlCommand("AUTHENTICATE")
            }
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to connect control port")
        }
    }

    /**
     * Send a command to the Tor control port and read the response.
     */
    private fun sendControlCommand(command: String): String? {
        return try {
            val socket = controlSocket ?: return null
            val writer = socket.getOutputStream().bufferedWriter()
            val reader = socket.getInputStream().bufferedReader()

            writer.write("$command\r\n")
            writer.flush()

            // Read response (may be multi-line, ends with "250 OK" or "5xx error")
            val response = StringBuilder()
            var line: String?
            while (true) {
                line = reader.readLine() ?: break
                response.appendLine(line)
                // Single-line response
                if (line.startsWith("250 ") || line.startsWith("5") || line.startsWith("6")) break
                // Multi-line intermediate
                if (line.startsWith("250+") || line.startsWith("250-")) continue
                // Data end
                if (line == ".") break
            }

            response.toString().trim()
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Control command failed: $command")
            null
        }
    }

    /**
     * Update the current exit node country by querying circuit status.
     */
    private fun updateExitCountry() {
        try {
            val circuitInfo = sendControlCommand("GETINFO circuit-status")
            // Parse for BUILT circuit with exit node
            // Format: "650 CIRC 1 BUILT ... $fingerprint~name"
            if (circuitInfo != null) {
                val builtCircuit = circuitInfo.lines()
                    .find { it.contains("BUILT") }
                
                if (builtCircuit != null) {
                    // The last node in a BUILT circuit is the exit
                    val nodes = builtCircuit.split(" ")
                        .filter { it.startsWith("$") || it.startsWith("~") }
                    Timber.d("$TAG: Circuit nodes: $nodes")
                }
            }
            
            // Also try GeoIP lookup from control port
            val geoResponse = sendControlCommand("GETINFO ip-to-country/me")
            currentExitCountry = geoResponse
                ?.substringAfter("=")
                ?.trim()
                ?.takeIf { it.length == 2 }
                ?.uppercase()
            
            Timber.d("$TAG: Exit country: $currentExitCountry")
        } catch (e: Exception) {
            Timber.e(e, "$TAG: Failed to update exit country")
        }
    }
}
