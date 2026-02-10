package com.privacyvpn.privacy_vpn_controller.vpn

import java.io.Serializable

/**
 * VPN Configuration data class for WireGuard
 */
data class VpnConfiguration(
    val id: String,
    val name: String,
    val serverAddress: String,
    val port: Int,
    val privateKey: String,
    val publicKey: String,
    val presharedKey: String? = null,
    val allowedIPs: List<String> = listOf("0.0.0.0/0", "::/0"),
    val dnsServers: List<String> = listOf("1.1.1.1", "1.0.0.1"),
    val interfaceAddress: String? = null,
    val mtu: Int? = 1420,
    val persistentKeepalive: Int = 25,
    val enableKillSwitch: Boolean = true,
    val blockIPv6: Boolean = true
) : Serializable {
    
    companion object {
        /**
         * Create VpnConfiguration from map data (from Flutter)
         */
        fun fromMap(map: Map<String, Any?>): VpnConfiguration {
            return VpnConfiguration(
                id = map["id"] as String,
                name = map["name"] as String,
                serverAddress = map["serverAddress"] as String,
                port = map["port"] as Int,
                privateKey = map["privateKey"] as String,
                publicKey = map["publicKey"] as String,
                presharedKey = map["presharedKey"] as String?,
                allowedIPs = (map["allowedIPs"] as? List<String>) ?: listOf("0.0.0.0/0"),
                dnsServers = (map["dnsServers"] as? List<String>) ?: listOf("1.1.1.1", "1.0.0.1"),
                interfaceAddress = map["interfaceAddress"] as String?,
                mtu = map["mtu"] as Int?,
                persistentKeepalive = (map["persistentKeepalive"] as? Int) ?: 25,
                enableKillSwitch = (map["enableKillSwitch"] as? Boolean) ?: true,
                blockIPv6 = (map["blockIPv6"] as? Boolean) ?: true
            )
        }
    }
    
    /**
     * Convert to map for sending to Flutter
     */
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name,
            "serverAddress" to serverAddress,
            "port" to port,
            "privateKey" to privateKey,
            "publicKey" to publicKey,
            "presharedKey" to presharedKey,
            "allowedIPs" to allowedIPs,
            "dnsServers" to dnsServers,
            "interfaceAddress" to interfaceAddress,
            "mtu" to mtu,
            "persistentKeepalive" to persistentKeepalive,
            "enableKillSwitch" to enableKillSwitch,
            "blockIPv6" to blockIPv6
        )
    }
}