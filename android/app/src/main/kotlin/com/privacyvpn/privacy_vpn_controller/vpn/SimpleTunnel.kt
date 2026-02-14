package com.privacyvpn.privacy_vpn_controller.vpn

/**
 * Simple tunnel state representation.
 * The actual WireGuard tunnel is managed by wireguard_flutter_plus plugin.
 */
enum class TunnelState {
    UP,
    DOWN,
    TOGGLE
}

/**
 * Simple tunnel implementation for tracking VPN state.
 * The actual WireGuard backend is provided by the wireguard_flutter_plus plugin.
 */
class SimpleTunnel(private val name: String) {
    
    private var state: TunnelState = TunnelState.DOWN
    
    fun getName(): String {
        return name
    }
    
    fun onStateChange(newState: TunnelState) {
        this.state = newState
    }
    
    fun getState(): TunnelState {
        return state
    }
}