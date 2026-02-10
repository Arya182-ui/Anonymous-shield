import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_logic/providers/connection_provider.dart';
import '../../data/models/connection_status.dart';
import '../../business_logic/providers/server_selection_provider.dart';

class ConnectionStatusCard extends ConsumerWidget {
  const ConnectionStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final selectedServer = ref.watch(selectedServerProvider);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(connectionState.status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getStatusColor(connectionState.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _getStatusColor(connectionState.status),
                width: 2,
              ),
            ),
            child: Icon(
              _getStatusIcon(connectionState.status),
              color: _getStatusColor(connectionState.status),
              size: 28,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Status Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(connectionState.status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getSubStatusText(connectionState, selectedServer),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (connectionState.status == SimpleConnectionStatus.connected && 
                    connectionState.connectionDuration != null) ...[
                  SizedBox(height: 8),
                  Text(
                    'Connected for ${_formatDuration(connectionState.connectionDuration!)}',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // IP Address (when connected)
          if (connectionState.status == SimpleConnectionStatus.connected)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Protected',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(SimpleConnectionStatus status) {
    switch (status) {
      case SimpleConnectionStatus.connected:
        return Colors.green;
      case SimpleConnectionStatus.connecting:
        return Colors.blue;
      case SimpleConnectionStatus.disconnected:
        return Colors.grey;
      case SimpleConnectionStatus.disconnecting:
        return Colors.orange;
      case SimpleConnectionStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SimpleConnectionStatus status) {
    switch (status) {
      case SimpleConnectionStatus.connected:
        return Icons.verified_user;
      case SimpleConnectionStatus.connecting:
        return Icons.sync;
      case SimpleConnectionStatus.disconnected:
        return Icons.security;
      case SimpleConnectionStatus.disconnecting:
        return Icons.sync_disabled;
      case SimpleConnectionStatus.error:
        return Icons.error;
    }
  }

  String _getStatusText(SimpleConnectionStatus status) {
    switch (status) {
      case SimpleConnectionStatus.connected:
        return 'Connected';
      case SimpleConnectionStatus.connecting:
        return 'Connecting...';
      case SimpleConnectionStatus.disconnected:
        return 'Disconnected';
      case SimpleConnectionStatus.disconnecting:
        return 'Disconnecting...';
      case SimpleConnectionStatus.error:
        return 'Connection Error';
    }
  }

  String _getSubStatusText(SimpleConnectionState connectionState, server) {
    switch (connectionState.status) {
      case SimpleConnectionStatus.connected:
        return server != null 
            ? 'Your traffic is encrypted and secure'
            : 'Connected to VPN server';
      case SimpleConnectionStatus.connecting:
        return server != null 
            ? 'Connecting to ${server.name}...'
            : 'Establishing secure connection...';
      case SimpleConnectionStatus.disconnected:
        return 'Your traffic is not protected';
      case SimpleConnectionStatus.disconnecting:
        return 'Disconnecting from VPN server...';
      case SimpleConnectionStatus.error:
        return connectionState.errorMessage ?? 'Failed to connect';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}