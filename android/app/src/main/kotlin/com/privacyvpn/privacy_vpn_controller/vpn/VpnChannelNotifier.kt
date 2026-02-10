package com.privacyvpn.privacy_vpn_controller.vpn

import com.privacyvpn.privacy_vpn_controller.channels.VpnMethodChannelHandler
import timber.log.Timber

/**
 * Static notifier to communicate VPN events to Flutter
 */
object VpnChannelNotifier {
    
    private var channelHandler: VpnMethodChannelHandler? = null
    
    /**
     * Set the channel handler instance
     */
    fun setChannelHandler(handler: VpnMethodChannelHandler) {
        channelHandler = handler
        Timber.d("VpnChannelNotifier handler set")
    }
    
    /**
     * Clear the channel handler
     */
    fun clearChannelHandler() {
        channelHandler = null
        Timber.d("VpnChannelNotifier handler cleared")
    }
    
    /**
     * Notify Flutter of VPN connection state changes
     */
    fun notifyConnectionState(state: VpnState, config: VpnConfiguration?, errorMessage: String? = null) {
        try {
            channelHandler?.notifyConnectionState(state, config, errorMessage)
            Timber.d("Notified connection state: $state")
        } catch (e: Exception) {
            Timber.e(e, "Failed to notify connection state")
        }
    }
    
    /**
     * Notify Flutter of connection statistics
     */
    fun notifyStatistics(statistics: Map<String, Any>) {
        try {
            channelHandler?.notifyStatistics(statistics)
            Timber.d("Notified statistics update")
        } catch (e: Exception) {
            Timber.e(e, "Failed to notify statistics")
        }
    }
}