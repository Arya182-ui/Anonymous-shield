package com.privacyvpn.privacy_vpn_controller.tor

import android.content.Context
import timber.log.Timber
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/**
 * Manages tun2socks — routes all VPN TUN traffic through a SOCKS5 proxy.
 *
 * tun2socks takes a TUN file descriptor and a SOCKS5 address,
 * and transparently proxies all TCP/UDP through the SOCKS5 server.
 *
 * The Go binary (libtun2socks.so) is placed in jniLibs/arm64-v8a/
 * and runs as a **process** (NOT loaded via JNI/System.loadLibrary).
 *
 * We use the Go-based tun2socks v2 (github.com/xjasonlyu/tun2socks).
 *
 * CLI usage: libtun2socks.so -device fd://FD -proxy socks5://HOST:PORT
 */
class Tun2SocksEngine(private val context: Context) {

    companion object {
        private const val TAG = "Tun2SocksEngine"
    }

    @Volatile
    var isRunning: Boolean = false
        private set

    private var tun2socksProcess: Process? = null
    private var monitorThread: Thread? = null

    /**
     * Start tun2socks routing by launching the Go binary as a subprocess.
     *
     * The TUN file descriptor (from VpnService.Builder.establish()) is
     * inherited by the child process — tun2socks accesses it via fd://N.
     *
     * @param tunFd The raw TUN file descriptor number
     * @param socksAddress SOCKS5 proxy address (e.g., "127.0.0.1:9050" for Tor)
     * @param dnsAddress DNS server address (unused for process mode, DNS is routed via TUN)
     * @param tunMtu MTU for the TUN interface
     */
    fun start(
        tunFd: Int,
        socksAddress: String,
        dnsAddress: String = "",
        tunMtu: Int = 1500
    ): Boolean {
        if (isRunning) {
            Timber.w("$TAG: tun2socks already running")
            return true
        }

        val binary = findBinary()
        if (binary == null) {
            Timber.e("$TAG: libtun2socks.so binary not found!")
            return false
        }

        return try {
            binary.setExecutable(true, false)

            Timber.i("$TAG: Starting tun2socks process (fd=$tunFd, socks=$socksAddress, binary=${binary.absolutePath})")

            // Build command: tun2socks v2 (Go) CLI arguments
            val args = mutableListOf(
                binary.absolutePath,
                "-device", "fd://$tunFd",
                "-proxy", "socks5://$socksAddress",
                "-loglevel", "info"
            )

            val processBuilder = ProcessBuilder(args)
            processBuilder.redirectErrorStream(true)
            processBuilder.directory(context.filesDir)

            // Set LD_LIBRARY_PATH so tun2socks can find any dependent libs
            processBuilder.environment()["LD_LIBRARY_PATH"] =
                "${context.applicationInfo.nativeLibraryDir}:${System.getenv("LD_LIBRARY_PATH") ?: ""}"

            tun2socksProcess = processBuilder.start()
            isRunning = true

            // Monitor process stdout/stderr in background
            monitorThread = Thread({
                try {
                    val reader = BufferedReader(
                        InputStreamReader(tun2socksProcess?.inputStream)
                    )
                    var line: String?
                    while (true) {
                        line = reader.readLine() ?: break
                        Timber.d("$TAG: $line")

                        // Detect successful start
                        if (line.contains("started") || line.contains("running") || line.contains("INFO")) {
                            Timber.i("$TAG: tun2socks appears to be running")
                        }

                        // Detect errors
                        if (line.contains("error") || line.contains("fatal")) {
                            Timber.e("$TAG: tun2socks error: $line")
                        }
                    }
                } catch (_: Exception) {
                    // Process was killed or reader closed
                } finally {
                    isRunning = false
                    Timber.d("$TAG: tun2socks monitor thread exited")
                }
            }, "tun2socks-monitor").also {
                it.isDaemon = true
                it.start()
            }

            // Give tun2socks a moment to start up
            Thread.sleep(1000)

            // Check if process is still alive
            val alive = tun2socksProcess?.isAlive == true
            if (alive) {
                Timber.i("$TAG: tun2socks process started successfully (pid active)")
                true
            } else {
                val exitCode = try { tun2socksProcess?.exitValue() } catch (_: Exception) { null }
                Timber.e("$TAG: tun2socks process died immediately (exit=$exitCode)")
                isRunning = false
                false
            }
        } catch (e: Throwable) {
            Timber.e(e, "$TAG: Failed to start tun2socks")
            isRunning = false
            false
        }
    }

    /**
     * Stop tun2socks process and clean up.
     */
    fun stop() {
        Timber.i("$TAG: Stopping tun2socks...")
        try {
            tun2socksProcess?.let { process ->
                // Send SIGTERM first for graceful shutdown
                process.destroy()
                try {
                    // Wait up to 3 seconds for graceful exit
                    monitorThread?.join(3000)
                } catch (_: Exception) {}

                // Force kill if still alive
                if (process.isAlive) {
                    process.destroyForcibly()
                    Timber.w("$TAG: Force-killed tun2socks process")
                }
            }
            tun2socksProcess = null
            monitorThread = null
            isRunning = false

            Timber.i("$TAG: tun2socks stopped")
        } catch (e: Throwable) {
            Timber.e(e, "$TAG: Error stopping tun2socks")
            isRunning = false
        }
    }

    /**
     * Check if the tun2socks binary is available on disk.
     */
    fun isAvailable(): Boolean = findBinary() != null

    // ==================== Private Helpers ====================

    /**
     * Find the tun2socks binary by searching multiple locations:
     * 1. nativeLibraryDir (extracted from APK for device ABI)
     * 2. All sibling arch directories (fallback)
     * 3. filesDir (manually placed)
     */
    private fun findBinary(): File? {
        // 1. Primary: nativeLibraryDir (Android auto-selects correct ABI)
        val nativeLib = File(context.applicationInfo.nativeLibraryDir, "libtun2socks.so")
        if (nativeLib.exists()) {
            Timber.d("$TAG: Found tun2socks at ${nativeLib.absolutePath}")
            return nativeLib
        }

        // 2. Fallback: search all arch directories
        val libBaseDir = File(context.applicationInfo.nativeLibraryDir).parentFile
        if (libBaseDir != null && libBaseDir.exists()) {
            libBaseDir.listFiles()?.forEach { archDir ->
                val binary = File(archDir, "libtun2socks.so")
                if (binary.exists()) {
                    Timber.d("$TAG: Found tun2socks in ${archDir.name}: ${binary.absolutePath}")
                    return binary
                }
            }
        }

        // 3. Check filesDir
        val extracted = File(context.filesDir, "tun2socks")
        if (extracted.exists()) {
            Timber.d("$TAG: Found extracted tun2socks at ${extracted.absolutePath}")
            return extracted
        }

        Timber.w("$TAG: libtun2socks.so not found in any location")
        return null
    }
}
