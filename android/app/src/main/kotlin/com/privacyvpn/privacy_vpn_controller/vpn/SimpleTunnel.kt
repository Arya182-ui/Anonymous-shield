package com.privacyvpn.privacy_vpn_controller.vpn

import com.wireguard.android.backend.Tunnel

/**
 * Simple tunnel implementation for WireGuard backend
 */
class SimpleTunnel(private val name: String) : Tunnel {
    
    private var state: Tunnel.State = Tunnel.State.DOWN
    
    override fun getName(): String {
        return name
    }
    
    override fun onStateChange(newState: Tunnel.State) {
        this.state = newState
    }
    
    fun getState(): Tunnel.State {
        return state
    }
}