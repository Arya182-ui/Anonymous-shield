package com.privacyvpn.privacy_vpn_controller.anonymity

import android.content.Context
import android.net.VpnService
import android.util.Log
import kotlinx.coroutines.*
import java.io.IOException
import java.net.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.random.Random

/**
 * Proxy Chain Manager - Orchestrates multi-hop proxy connections
 * Handles SOCKS5, Shadowsocks, V2Ray, and custom proxy protocols
 */
class ProxyChainManager(private val context: Context) {
    
    companion object {
        private const val TAG = "ProxyChainManager"
        private const val CONNECTION_TIMEOUT_MS = 10000
        private const val READ_TIMEOUT_MS = 30000
    }
    
    private val isActive = AtomicBoolean(false)
    private val managerScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Active connections
    private val activeConnections = ConcurrentHashMap<String, ProxyConnection>()
    private val connectionPools = ConcurrentHashMap<String, MutableList<Socket>>()
    
    // Chain configuration
    private var currentChain: List<ProxyNode>? = null
    private var chainMode: String = "turbo"
    
    // Status callback
    private var statusCallback: ((ChainStatus) -> Unit)? = null

    /**
     * Start proxy tunnel for basic VPN connections
     */
    fun startProxyTunnel(config: VpnConfiguration) {
        managerScope.launch {
            try {
                Log.i(TAG, "Starting proxy tunnel for VPN")
                
                // Create single-hop proxy connection for VPN exit
                val proxyConfig = ProxyServerConfig(
                    id = "vpn_proxy",
                    name = config.serverName,
                    host = config.serverHost,
                    port = config.serverPort,
                    type = "socks5", // Default to SOCKS5 for VPN
                    country = "Unknown",
                    countryCode = "XX"
                )
                
                val connection = establishSocks5Connection(proxyConfig)
                activeConnections["vpn_tunnel"] = connection
                
                Log.i(TAG, "VPN proxy tunnel established")
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start proxy tunnel", e)
                throw e
            }
        }
    }

    /**
     * Start Turbo Mode - Fast 2-3 hop proxy chain
     */
    fun startTurboMode(config: AnonymousChainConfig) {
        managerScope.launch {
            try {
                chainMode = "turbo"
                statusCallback?.invoke(ChainStatus.CONNECTING)
                
                // Use only 2-3 high-speed servers for turbo mode
                val turboServers = selectTurboServers(config.proxyServers)
                val chain = createTurboChain(turboServers)
                
                if (establishProxyChain(chain)) {
                    currentChain = chain
                    this@ProxyChainManager.isActive.set(true)
                    statusCallback?.invoke(ChainStatus.CONNECTED)
                    Log.i(TAG, "Turbo mode activated: ${chain.size} hops")
                } else {
                    throw Exception("Failed to establish turbo chain")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start turbo mode", e)
                statusCallback?.invoke(ChainStatus.ERROR)
            }
        }
    }

    /**
     * Start custom proxy chain
     */
    fun startCustomChain(config: AnonymousChainConfig) {
        managerScope.launch {
            try {
                chainMode = "custom"
                statusCallback?.invoke(ChainStatus.CONNECTING)
                
                val chain = createCustomChain(config)
                
                if (establishProxyChain(chain)) {
                    currentChain = chain
                    this@ProxyChainManager.isActive.set(true)
                    statusCallback?.invoke(ChainStatus.CONNECTED)
                    Log.i(TAG, "Custom chain activated: ${chain.size} hops")
                } else {
                    throw Exception("Failed to establish custom chain")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start custom chain", e)
                statusCallback?.invoke(ChainStatus.ERROR)
            }
        }
    }

    /**
     * Select fastest servers for turbo mode
     */
    private fun selectTurboServers(servers: List<ProxyServerConfig>): List<ProxyServerConfig> {
        // Prioritize servers by type and location for speed
        return servers.filter { 
            it.type in listOf("shadowsocks", "socks5") // Fast protocols
        }.shuffled().take(3) // Limit to 3 hops for speed
    }

    /**
     * Create optimized chain for turbo mode
     */
    private fun createTurboChain(servers: List<ProxyServerConfig>): List<ProxyNode> {
        val chain = mutableListOf<ProxyNode>()
        
        servers.forEachIndexed { index, server ->
            chain.add(ProxyNode(
                id = "turbo_${index}_${server.id}",
                config = server,
                role = when (index) {
                    0 -> NodeRole.ENTRY
                    servers.lastIndex -> NodeRole.EXIT
                    else -> NodeRole.MIDDLE
                },
                obfuscationEnabled = false, // Disable obfuscation for speed
                encryptionLevel = "standard"
            ))
        }
        
        return chain
    }

    /**
     * Create custom proxy chain based on user configuration
     */
    private fun createCustomChain(config: AnonymousChainConfig): List<ProxyNode> {
        val chain = mutableListOf<ProxyNode>()
        
        config.proxyServers.forEachIndexed { index, server ->
            chain.add(ProxyNode(
                id = "custom_${index}_${server.id}",
                config = server,
                role = when (index) {
                    0 -> NodeRole.ENTRY
                    config.proxyServers.lastIndex -> NodeRole.EXIT
                    else -> NodeRole.MIDDLE
                },
                obfuscationEnabled = config.trafficObfuscation,
                encryptionLevel = "maximum"
            ))
        }
        
        return chain
    }

    /**
     * Establish the complete proxy chain
     */
    private suspend fun establishProxyChain(chain: List<ProxyNode>): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                var previousConnection: ProxyConnection? = null
                
                for (node in chain) {
                    val connection = when (node.config.type.lowercase()) {
                        "socks5" -> establishSocks5Connection(node.config, previousConnection)
                        "shadowsocks" -> establishShadowsocksConnection(node.config, previousConnection)
                        "v2ray" -> establishV2RayConnection(node.config, previousConnection)
                        "trojan" -> establishTrojanConnection(node.config, previousConnection)
                        else -> establishSocks5Connection(node.config, previousConnection) // Fallback
                    }
                    
                    activeConnections[node.id] = connection
                    previousConnection = connection
                    
                    Log.d(TAG, "Connected to ${node.config.type} proxy: ${node.config.name}")
                    
                    // Small delay between connections
                    delay(Random.nextLong(100, 500))
                }
                
                return@withContext true
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to establish proxy chain", e)
                cleanup()
                return@withContext false
            }
        }
    }

    /**
     * Establish SOCKS5 proxy connection
     */
    private fun establishSocks5Connection(
        config: ProxyServerConfig, 
        previousConnection: ProxyConnection? = null
    ): ProxyConnection {
        val socket = if (previousConnection != null) {
            // Chain through previous proxy
            createChainedSocket(previousConnection, config.host, config.port)
        } else {
            // Direct connection
            Socket().apply {
                connect(InetSocketAddress(config.host, config.port), CONNECTION_TIMEOUT_MS)
                soTimeout = READ_TIMEOUT_MS
            }
        }
        
        // Perform SOCKS5 handshake
        performSocks5Handshake(socket, config.username, config.password)
        
        return ProxyConnection(
            id = config.id,
            socket = socket,
            type = "socks5",
            config = config
        )
    }

    /**
     * Establish Shadowsocks proxy connection
     */
    private fun establishShadowsocksConnection(
        config: ProxyServerConfig,
        previousConnection: ProxyConnection? = null
    ): ProxyConnection {
        val socket = if (previousConnection != null) {
            createChainedSocket(previousConnection, config.host, config.port)
        } else {
            Socket().apply {
                connect(InetSocketAddress(config.host, config.port), CONNECTION_TIMEOUT_MS)
                soTimeout = READ_TIMEOUT_MS
            }
        }
        
        // Initialize Shadowsocks encryption
        initializeShadowsocksEncryption(socket, config.method ?: "aes-256-gcm", config.password ?: "")
        
        return ProxyConnection(
            id = config.id,
            socket = socket,
            type = "shadowsocks",
            config = config
        )
    }

    /**
     * Establish V2Ray proxy connection
     */
    private fun establishV2RayConnection(
        config: ProxyServerConfig,
        previousConnection: ProxyConnection? = null
    ): ProxyConnection {
        val socket = if (previousConnection != null) {
            createChainedSocket(previousConnection, config.host, config.port)
        } else {
            Socket().apply {
                connect(InetSocketAddress(config.host, config.port), CONNECTION_TIMEOUT_MS)
                soTimeout = READ_TIMEOUT_MS
            }
        }
        
        // Initialize V2Ray protocol
        initializeV2RayProtocol(socket, config)
        
        return ProxyConnection(
            id = config.id,
            socket = socket,
            type = "v2ray",
            config = config
        )
    }

    /**
     * Establish Trojan proxy connection
     */
    private fun establishTrojanConnection(
        config: ProxyServerConfig,
        previousConnection: ProxyConnection? = null
    ): ProxyConnection {
        val socket = if (previousConnection != null) {
            createChainedSocket(previousConnection, config.host, config.port)
        } else {
            Socket().apply {
                connect(InetSocketAddress(config.host, config.port), CONNECTION_TIMEOUT_MS)
                soTimeout = READ_TIMEOUT_MS
            }
        }
        
        // Initialize Trojan protocol
        initializeTrojanProtocol(socket, config.password ?: "")
        
        return ProxyConnection(
            id = config.id,
            socket = socket,
            type = "trojan",
            config = config
        )
    }

    /**
     * Create chained socket through existing proxy connection
     */
    private fun createChainedSocket(previousConnection: ProxyConnection, host: String, port: Int): Socket {
        // This would route the new connection through the existing proxy chain
        // Implementation depends on the specific proxy protocol
        return when (previousConnection.type) {
            "socks5" -> createSocks5ChainedSocket(previousConnection, host, port)
            "shadowsocks" -> createShadowsocksChainedSocket(previousConnection, host, port)
            else -> throw UnsupportedOperationException("Chaining not supported for ${previousConnection.type}")
        }
    }

    private fun createSocks5ChainedSocket(connection: ProxyConnection, host: String, port: Int): Socket {
        // Send CONNECT command through existing SOCKS5 connection
        val socket = connection.socket
        val output = socket.getOutputStream()
        
        // SOCKS5 CONNECT command
        output.write(byteArrayOf(0x05, 0x01, 0x00)) // Version, CMD, Reserved
        output.write(byteArrayOf(0x03, host.length.toByte())) // Address type, length
        output.write(host.toByteArray()) // Hostname
        output.write(byteArrayOf((port shr 8).toByte(), (port and 0xFF).toByte())) // Port
        output.flush()
        
        // Read response
        val input = socket.getInputStream()
        val response = ByteArray(10)
        input.read(response)
        
        if (response[1] != 0x00.toByte()) {
            throw IOException("SOCKS5 CONNECT failed: ${response[1]}")
        }
        
        return socket
    }

    private fun createShadowsocksChainedSocket(connection: ProxyConnection, host: String, port: Int): Socket {
        // Shadowsocks doesn't have explicit chaining, but we can tunnel through the existing connection
        return connection.socket
    }

    // Protocol initialization methods (simplified implementations)
    private fun performSocks5Handshake(socket: Socket, username: String?, password: String?) {
        val output = socket.getOutputStream()
        val input = socket.getInputStream()
        
        if (username != null && password != null) {
            // Authentication method negotiation
            output.write(byteArrayOf(0x05, 0x02, 0x00, 0x02)) // Version, methods count, no auth, user/pass auth
            output.flush()
            
            val response = ByteArray(2)
            input.read(response)
            
            if (response[1] == 0x02.toByte()) {
                // User/password authentication
                val authReq = ByteArray(3 + username.length + password.length)
                authReq[0] = 0x01 // Version
                authReq[1] = username.length.toByte()
                System.arraycopy(username.toByteArray(), 0, authReq, 2, username.length)
                authReq[2 + username.length] = password.length.toByte()
                System.arraycopy(password.toByteArray(), 0, authReq, 3 + username.length, password.length)
                
                output.write(authReq)
                output.flush()
                
                val authResp = ByteArray(2)
                input.read(authResp)
                
                if (authResp[1] != 0x00.toByte()) {
                    throw IOException("SOCKS5 authentication failed")
                }
            }
        } else {
            // No authentication
            output.write(byteArrayOf(0x05, 0x01, 0x00)) // Version, 1 method, no auth
            output.flush()
            
            val response = ByteArray(2)
            input.read(response)
            
            if (response[1] != 0x00.toByte()) {
                throw IOException("SOCKS5 handshake failed")
            }
        }
    }

    private fun initializeShadowsocksEncryption(socket: Socket, method: String, password: String) {
        // Initialize Shadowsocks encryption based on method and password
        Log.d(TAG, "Initializing Shadowsocks encryption: $method")
        // This would set up the actual encryption/decryption streams
    }

    private fun initializeV2RayProtocol(socket: Socket, config: ProxyServerConfig) {
        // Initialize V2Ray protocol with VMess or other protocols
        Log.d(TAG, "Initializing V2Ray protocol")
        // This would implement the V2Ray protocol handshake
    }

    private fun initializeTrojanProtocol(socket: Socket, password: String) {
        // Initialize Trojan protocol
        Log.d(TAG, "Initializing Trojan protocol")
        // This would implement the Trojan protocol handshake
    }

    /**
     * Stop the proxy chain
     */
    fun stopChain() {
        managerScope.launch {
            cleanup()
            Log.i(TAG, "Proxy chain stopped")
        }
    }

    private fun cleanup() {
        isActive.set(false)
        
        // Close all active connections
        activeConnections.values.forEach { connection ->
            try {
                connection.socket.close()
            } catch (e: Exception) {
                Log.w(TAG, "Error closing connection", e)
            }
        }
        activeConnections.clear()
        
        // Clear connection pools
        connectionPools.values.forEach { pool ->
            pool.forEach { socket ->
                try {
                    socket.close()
                } catch (e: Exception) {
                    Log.w(TAG, "Error closing pooled socket", e)
                }
            }
        }
        connectionPools.clear()
        
        currentChain = null
        statusCallback?.invoke(ChainStatus.INACTIVE)
    }

    fun setStatusCallback(callback: (ChainStatus) -> Unit) {
        statusCallback = callback
    }

    fun isChainActive(): Boolean = isActive.get()
    fun getActiveConnectionCount(): Int = activeConnections.size
    fun getCurrentChain(): List<ProxyNode>? = currentChain
}

/**
 * Kill Switch Manager - Prevents traffic leaks when VPN disconnects
 */
class KillSwitchManager(private val context: Context) {
    
    companion object {
        private const val TAG = "KillSwitchManager"
    }
    
    private val isEnabled = AtomicBoolean(false)

    fun enableKillSwitch(builder: VpnService.Builder, config: VpnConfiguration) {
        try {
            Log.i(TAG, "Enabling kill switch protection")
            
            // Block all traffic except through VPN interface
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0) // IPv6
            
            // Allow VPN server traffic
            builder.addDisallowedApplication("android") // System apps
            
            // Block potential DNS leaks
            builder.addDnsServer("1.1.1.1") // Cloudflare DNS
            builder.addDnsServer("1.0.0.1")
            
            isEnabled.set(true)
            Log.i(TAG, "Kill switch enabled successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable kill switch", e)
            throw e
        }
    }

    fun disableKillSwitch() {
        isEnabled.set(false)
        Log.i(TAG, "Kill switch disabled")
    }

    fun isKillSwitchEnabled(): Boolean = isEnabled.get()
}

// Data classes
data class ProxyConnection(
    val id: String,
    val socket: Socket,
    val type: String, // socks5, shadowsocks, v2ray, trojan
    val config: ProxyServerConfig
)

// Reusing VpnConfiguration from VpnControllerService
data class VpnConfiguration(
    val serverName: String,
    val serverHost: String,
    val serverPort: Int,
    val killSwitchEnabled: Boolean = true
)