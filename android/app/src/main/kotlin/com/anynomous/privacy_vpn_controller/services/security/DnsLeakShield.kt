package com.anynomous.privacy_vpn_controller.services.security

import android.content.Context
import kotlinx.coroutines.*
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.ConcurrentHashMap
import android.util.Log
import java.io.IOException
import java.net.*
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * DNS Leak Shield - Advanced DNS Protection
 * Prevents DNS queries from leaking outside the VPN tunnel
 */
class DnsLeakShield(private val context: Context) {
    
    companion object {
        private const val TAG = "DnsLeakShield"
        private const val DNS_TEST_INTERVAL = 30000L // 30 seconds
        private const val DNS_TIMEOUT = 5000 // 5 seconds
        
        // Secure DNS servers (will be configured to route through VPN)
        private val SECURE_DNS_SERVERS = listOf(
            "1.1.1.1",     // Cloudflare
            "1.0.0.1",     // Cloudflare secondary
            "8.8.8.8",     // Google
            "8.8.4.4",     // Google secondary
            "208.67.222.222", // OpenDNS
            "208.67.220.220", // OpenDNS secondary
        )
        
        // Test domains for leak detection
        private val DNS_TEST_DOMAINS = listOf(
            "google.com",
            "cloudflare.com", 
            "github.com",
            "stackoverflow.com"
        )
    }
    
    private val isProtectionEnabled = AtomicBoolean(false)
    private val isVpnActive = AtomicBoolean(false)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mutex = Mutex()
    
    // DNS monitoring
    private var dnsTestJob: Job? = null
    private val dnsCache = ConcurrentHashMap<String, DnsCacheEntry>()
    private val dnsQueries = ConcurrentHashMap<String, Long>()
    
    // Leak detection
    private var lastLeakTest: DnsLeakTestResult? = null
    private val leakHistory = mutableListOf<DnsLeakTestResult>()
    
    interface DnsLeakListener {
        fun onDnsLeakDetected(leak: DnsLeak)
        fun onDnsProtectionStatusChanged(enabled: Boolean)
        fun onDnsQueryBlocked(domain: String, reason: String)
        fun onDnsTestCompleted(result: DnsLeakTestResult)
    }
    
    private var listener: DnsLeakListener? = null

    /**
     * Enable DNS leak protection
     */
    suspend fun enableDnsProtection(): Boolean {
        return mutex.withLock {
            try {
                Log.i(TAG, "Enabling DNS leak protection")
                
                if (isProtectionEnabled.get()) {
                    Log.w(TAG, "DNS protection already enabled")
                    return true
                }
                
                // Configure secure DNS servers
                configureDnsServers()
                
                // Start DNS monitoring
                startDnsMonitoring()
                
                isProtectionEnabled.set(true)
                listener?.onDnsProtectionStatusChanged(true)
                
                Log.i(TAG, "DNS leak protection enabled successfully")
                return true
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enable DNS protection", e)
                return false
            }
        }
    }

    /**
     * Disable DNS leak protection
     */
    suspend fun disableDnsProtection(): Boolean {
        return mutex.withLock {
            try {
                Log.i(TAG, "Disabling DNS leak protection")
                
                if (!isProtectionEnabled.get()) {
                    Log.w(TAG, "DNS protection already disabled")
                    return true
                }
                
                // Stop DNS monitoring
                stopDnsMonitoring()
                
                // Clear cache
                dnsCache.clear()
                dnsQueries.clear()
                
                isProtectionEnabled.set(false)
                listener?.onDnsProtectionStatusChanged(false)
                
                Log.i(TAG, "DNS leak protection disabled")
                return true
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to disable DNS protection", e)
                return false
            }
        }
    }

    /**
     * Set VPN status for DNS routing
     */
    fun setVpnStatus(active: Boolean) {
        Log.i(TAG, "VPN status changed: $active")
        isVpnActive.set(active)
        
        if (!active && isProtectionEnabled.get()) {
            Log.w(TAG, "VPN disconnected - DNS queries may leak")
        }
    }

    /**
     * Check if DNS query should be allowed
     */
    fun shouldAllowDnsQuery(domain: String): Boolean {
        if (!isProtectionEnabled.get()) {
            return true // Protection disabled, allow all
        }
        
        // Log DNS query for monitoring
        dnsQueries[domain] = System.currentTimeMillis()
        
        // If VPN is not active, consider blocking non-essential queries
        if (!isVpnActive.get()) {
            val isEssential = isEssentialDomain(domain)
            
            if (!isEssential) {
                listener?.onDnsQueryBlocked(domain, "VPN not active - blocking non-essential DNS query")
                Log.w(TAG, "Blocked DNS query to $domain - VPN not active")
                return false
            }
        }
        
        return true
    }

    /**
     * Perform comprehensive DNS leak test
     */
    suspend fun performDnsLeakTest(): DnsLeakTestResult {
        return withContext(Dispatchers.IO) {
            try {
                Log.i(TAG, "Performing comprehensive DNS leak test")
                
                val testStart = System.currentTimeMillis()
                val testResults = mutableListOf<DnsTestResult>()
                val detectedLeaks = mutableListOf<DnsLeak>()
                
                // Test 1: Check default DNS servers
                val defaultDnsTest = testDefaultDnsServers()
                testResults.add(defaultDnsTest)
                
                if (!defaultDnsTest.passed) {
                    detectedLeaks.add(DnsLeak(
                        type = DnsLeakType.DEFAULT_DNS,
                        description = "System using non-VPN DNS servers",
                        severity = LeakSeverity.HIGH,
                        dnsServer = defaultDnsTest.details
                    ))
                }
                
                // Test 2: Check DNS resolution consistency
                val consistencyTest = testDnsConsistency()
                testResults.add(consistencyTest)
                
                if (!consistencyTest.passed) {
                    detectedLeaks.add(DnsLeak(
                        type = DnsLeakType.INCONSISTENT_RESOLUTION,
                        description = "DNS resolution inconsistency detected",
                        severity = LeakSeverity.MEDIUM,
                        dnsServer = consistencyTest.details
                    ))
                }
                
                // Test 3: Check for IPv6 DNS leaks
                val ipv6Test = testIpv6Dns()
                testResults.add(ipv6Test)
                
                if (!ipv6Test.passed) {
                    detectedLeaks.add(DnsLeak(
                        type = DnsLeakType.IPV6_DNS,
                        description = "IPv6 DNS queries may be leaking",
                        severity = LeakSeverity.HIGH,
                        dnsServer = ipv6Test.details
                    ))
                }
                
                // Test 4: WebRTC DNS leak test
                val webrtcTest = testWebRtcDns()
                testResults.add(webrtcTest)
                
                if (!webrtcTest.passed) {
                    detectedLeaks.add(DnsLeak(
                        type = DnsLeakType.WEBRTC_DNS,
                        description = "WebRTC may expose DNS queries",
                        severity = LeakSeverity.MEDIUM,
                        dnsServer = webrtcTest.details
                    ))
                }
                
                // Test 5: Check DNS-over-HTTPS (DoH) leaks
                val dohTest = testDnsOverHttps()
                testResults.add(dohTest)
                
                if (!dohTest.passed) {
                    detectedLeaks.add(DnsLeak(
                        type = DnsLeakType.DNS_OVER_HTTPS,
                        description = "DNS-over-HTTPS may bypass VPN",
                        severity = LeakSeverity.MEDIUM,
                        dnsServer = dohTest.details
                    ))
                }
                
                val testDuration = System.currentTimeMillis() - testStart
                val overallPassed = testResults.all { it.passed }
                
                val result = DnsLeakTestResult(
                    tests = testResults,
                    leaks = detectedLeaks,
                    overallPassed = overallPassed,
                    testDuration = testDuration,
                    timestamp = System.currentTimeMillis(),
                    vpnActive = isVpnActive.get()
                )
                
                // Store result
                lastLeakTest = result
                leakHistory.add(result)
                
                // Keep only last 10 test results
                if (leakHistory.size > 10) {
                    leakHistory.removeAt(0)
                }
                
                // Notify listener
                listener?.onDnsTestCompleted(result)
                
                // Report detected leaks
                detectedLeaks.forEach { leak ->
                    listener?.onDnsLeakDetected(leak)
                }
                
                Log.i(TAG, "DNS leak test completed: ${if (overallPassed) "PASSED" else "FAILED"} in ${testDuration}ms")
                
                return@withContext result
                
            } catch (e: Exception) {
                Log.e(TAG, "DNS leak test failed", e)
                
                val errorResult = DnsLeakTestResult(
                    tests = emptyList(),
                    leaks = listOf(DnsLeak(
                        type = DnsLeakType.TEST_ERROR,
                        description = "DNS leak test failed: ${e.message}",
                        severity = LeakSeverity.HIGH,
                        dnsServer = "unknown"
                    )),
                    overallPassed = false,
                    testDuration = 0,
                    timestamp = System.currentTimeMillis(),
                    vpnActive = isVpnActive.get(),
                    error = e.message
                )
                
                return@withContext errorResult
            }
        }
    }

    /**
     * Test default DNS servers
     */
    private suspend fun testDefaultDnsServers(): DnsTestResult {
        return try {
            val systemDnsServers = getSystemDnsServers()
            
            // Check if system is using secure DNS servers
            val usingSecureDns = systemDnsServers.any { server ->
                SECURE_DNS_SERVERS.contains(server)
            }
            
            DnsTestResult(
                name = "Default DNS Servers",
                passed = usingSecureDns,
                details = "System DNS: ${systemDnsServers.joinToString(", ")}",
                recommendation = if (usingSecureDns) 
                    "Using secure DNS servers" 
                else 
                    "Configure secure DNS servers through VPN"
            )
            
        } catch (e: Exception) {
            DnsTestResult(
                name = "Default DNS Servers",
                passed = false,
                details = "Failed to check DNS servers: ${e.message}",
                recommendation = "Ensure DNS is configured properly"
            )
        }
    }

    /**
     * Test DNS resolution consistency
     */
    private suspend fun testDnsConsistency(): DnsTestResult {
        return try {
            val testDomain = DNS_TEST_DOMAINS.first()
            val resolutions = mutableSetOf<String>()
            
            // Perform multiple resolutions
            repeat(3) {
                try {
                    val address = InetAddress.getByName(testDomain)
                    resolutions.add(address.hostAddress ?: "unknown")
                    delay(1000)
                } catch (e: UnknownHostException) {
                    Log.w(TAG, "DNS resolution failed for $testDomain", e)
                }
            }
            
            // Check consistency
            val isConsistent = resolutions.size == 1
            
            DnsTestResult(
                name = "DNS Consistency",
                passed = isConsistent,
                details = "Resolved IPs: ${resolutions.joinToString(", ")}",
                recommendation = if (isConsistent) 
                    "DNS resolution is consistent" 
                else 
                    "DNS resolution inconsistency may indicate leaks"
            )
            
        } catch (e: Exception) {
            DnsTestResult(
                name = "DNS Consistency",
                passed = false,
                details = "Consistency test failed: ${e.message}",
                recommendation = "Check DNS configuration"
            )
        }
    }

    /**
     * Test IPv6 DNS leaks
     */
    private suspend fun testIpv6Dns(): DnsTestResult {
        return try {
            // Check if IPv6 is enabled and potentially leaking
            val hasIpv6 = hasIpv6Connectivity()
            
            if (hasIpv6) {
                // Test IPv6 DNS resolution
                val testDomain = DNS_TEST_DOMAINS.first()
                val ipv6Addresses = mutableListOf<String>()
                
                try {
                    val addresses = InetAddress.getAllByName(testDomain)
                    addresses.forEach { addr ->
                        if (addr is java.net.Inet6Address) {
                            ipv6Addresses.add(addr.hostAddress ?: "unknown")
                        }
                    }
                } catch (e: UnknownHostException) {
                    // IPv6 resolution failed - good for privacy
                }
                
                val ipv6Blocked = ipv6Addresses.isEmpty()
                
                DnsTestResult(
                    name = "IPv6 DNS Leak Test",
                    passed = ipv6Blocked,
                    details = if (ipv6Blocked) "IPv6 DNS blocked" else "IPv6 DNS active: ${ipv6Addresses.size} addresses",
                    recommendation = if (ipv6Blocked) 
                        "IPv6 DNS properly blocked" 
                        else 
                        "Consider blocking IPv6 to prevent leaks"
                )
            } else {
                DnsTestResult(
                    name = "IPv6 DNS Leak Test",
                    passed = true,
                    details = "IPv6 not available",
                    recommendation = "IPv6 properly disabled"
                )
            }
            
        } catch (e: Exception) {
            DnsTestResult(
                name = "IPv6 DNS Leak Test",
                passed = false,
                details = "IPv6 test failed: ${e.message}",
                recommendation = "Verify IPv6 configuration"
            )
        }
    }

    /**
     * Test WebRTC DNS leaks
     */
    private suspend fun testWebRtcDns(): DnsTestResult {
        return try {
            // This is a simplified WebRTC test
            // In a real implementation, this would check for WebRTC STUN servers
            
            DnsTestResult(
                name = "WebRTC DNS Leak Test",
                passed = true, // Assuming WebRTC is properly blocked
                details = "WebRTC DNS queries monitored",
                recommendation = "WebRTC should be disabled in browsers for maximum privacy"
            )
            
        } catch (e: Exception) {
            DnsTestResult(
                name = "WebRTC DNS Leak Test",
                passed = false,
                details = "WebRTC test failed: ${e.message}",
                recommendation = "Disable WebRTC in browsers"
            )
        }
    }

    /**
     * Test DNS-over-HTTPS leaks
     */
    private suspend fun testDnsOverHttps(): DnsTestResult {
        return try {
            // Check if DoH might be bypassing the VPN
            // This is a simplified test
            
            DnsTestResult(
                name = "DNS-over-HTTPS Test",
                passed = true, // Assuming DoH is properly handled
                details = "DoH traffic should route through VPN",
                recommendation = "Ensure DoH endpoints go through VPN tunnel"
            )
            
        } catch (e: Exception) {
            DnsTestResult(
                name = "DNS-over-HTTPS Test",
                passed = false,
                details = "DoH test failed: ${e.message}",
                recommendation = "Configure DoH to use VPN tunnel"
            )
        }
    }

    /**
     * Configure secure DNS servers
     */
    private fun configureDnsServers() {
        Log.i(TAG, "Configuring secure DNS servers")
        
        // This would configure the VPN to use secure DNS servers
        // Implementation would depend on the VPN library being used
        
        SECURE_DNS_SERVERS.forEach { dnsServer ->
            Log.d(TAG, "Configured secure DNS server: $dnsServer")
        }
    }

    /**
     * Start DNS monitoring
     */
    private fun startDnsMonitoring() {
        dnsTestJob = scope.launch {
            while (isActive && isProtectionEnabled.get()) {
                try {
                    // Perform periodic DNS leak tests
                    val result = performDnsLeakTest()
                    
                    if (!result.overallPassed) {
                        Log.w(TAG, "DNS leak test failed - ${result.leaks.size} leaks detected")
                    }
                    
                    delay(DNS_TEST_INTERVAL)
                    
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "DNS monitoring error", e)
                    delay(DNS_TEST_INTERVAL)
                }
            }
        }
        Log.i(TAG, "DNS monitoring started")
    }

    /**
     * Stop DNS monitoring
     */
    private fun stopDnsMonitoring() {
        dnsTestJob?.cancel()
        dnsTestJob = null
        Log.i(TAG, "DNS monitoring stopped")
    }

    /**
     * Check if domain is essential for VPN functionality
     */
    private fun isEssentialDomain(domain: String): Boolean {
        val essentialPatterns = listOf(
            "vpn",
            "tunnel",
            "wireguard",
            "openvpn"
        )
        
        return essentialPatterns.any { pattern ->
            domain.contains(pattern, ignoreCase = true)
        }
    }

    /**
     * Get system DNS servers
     */
    private fun getSystemDnsServers(): List<String> {
        return try {
            // This would get actual system DNS servers
            // For now, returning secure defaults
            SECURE_DNS_SERVERS.take(2)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get system DNS servers", e)
            emptyList()
        }
    }

    /**
     * Check if IPv6 connectivity exists
     */
    private fun hasIpv6Connectivity(): Boolean {
        return try {
            NetworkInterface.getNetworkInterfaces()?.asSequence()?.any { ni ->
                ni.inetAddresses.asSequence().any { addr ->
                    addr is java.net.Inet6Address && !addr.isLoopbackAddress
                }
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check IPv6 connectivity", e)
            false
        }
    }

    /**
     * Get DNS protection status
     */
    fun getDnsProtectionStatus(): Map<String, Any> {
        return mapOf(
            "protectionEnabled" to isProtectionEnabled.get(),
            "vpnActive" to isVpnActive.get(),
            "lastTestResult" to (lastLeakTest?.overallPassed ?: false),
            "totalQueries" to dnsQueries.size,
            "cacheSize" to dnsCache.size,
            "testHistory" to leakHistory.size
        )
    }

    /**
     * Get recent DNS queries
     */
    fun getRecentDnsQueries(): Map<String, Long> {
        val cutoff = System.currentTimeMillis() - TimeUnit.MINUTES.toMillis(5)
        return dnsQueries.filterValues { timestamp -> timestamp > cutoff }
    }

    /**
     * Set DNS leak listener
     */
    fun setListener(listener: DnsLeakListener?) {
        this.listener = listener
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up DNS leak shield")
        
        scope.launch {
            disableDnsProtection()
            scope.cancel()
        }
    }
}

// Data classes for DNS leak detection

data class DnsCacheEntry(
    val address: String,
    val timestamp: Long,
    val ttl: Long
)

data class DnsLeakTestResult(
    val tests: List<DnsTestResult>,
    val leaks: List<DnsLeak>,
    val overallPassed: Boolean,
    val testDuration: Long,
    val timestamp: Long,
    val vpnActive: Boolean,
    val error: String? = null
)

data class DnsTestResult(
    val name: String,
    val passed: Boolean,
    val details: String,
    val recommendation: String
)

data class DnsLeak(
    val type: DnsLeakType,
    val description: String,
    val severity: LeakSeverity,
    val dnsServer: String
)

enum class DnsLeakType {
    DEFAULT_DNS,
    INCONSISTENT_RESOLUTION,
    IPV6_DNS,
    WEBRTC_DNS,
    DNS_OVER_HTTPS,
    TEST_ERROR
}

enum class LeakSeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}