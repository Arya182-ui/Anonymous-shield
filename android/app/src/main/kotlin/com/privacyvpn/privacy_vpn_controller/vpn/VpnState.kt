package com.privacyvpn.privacy_vpn_controller.vpn

/**
 * VPN connection states
 */
enum class VpnState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    RECONNECTING,
    ERROR;
    
    fun toFlutterString(): String {
        return when (this) {
            DISCONNECTED -> "disconnected"
            CONNECTING -> "connecting"
            CONNECTED -> "connected"
            DISCONNECTING -> "disconnecting"
            RECONNECTING -> "reconnecting"
            ERROR -> "error"
        }
    }
}