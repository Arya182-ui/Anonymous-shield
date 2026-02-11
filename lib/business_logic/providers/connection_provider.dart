import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/connection_status.dart';
import '../../data/models/built_in_server.dart';
import '../managers/vpn_manager.dart';

// Simple connection state for the connection provider
class SimpleConnectionState {
  final SimpleConnectionStatus status;
  final BuiltInServer? selectedServer;
  final DateTime? connectionStartTime;
  final Duration? connectionDuration;
  final String? ipAddress;
  final double downloadSpeed;
  final double uploadSpeed;
  final int bytesReceived;
  final int bytesSent;
  final String? errorMessage;

  const SimpleConnectionState({
    this.status = SimpleConnectionStatus.disconnected,
    this.selectedServer,
    this.connectionStartTime,
    this.connectionDuration,
    this.ipAddress,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.bytesReceived = 0,
    this.bytesSent = 0,
    this.errorMessage,
  });

  SimpleConnectionState copyWith({
    SimpleConnectionStatus? status,
    BuiltInServer? selectedServer,
    DateTime? connectionStartTime,
    Duration? connectionDuration,
    String? ipAddress,
    double? downloadSpeed,
    double? uploadSpeed,
    int? bytesReceived,
    int? bytesSent,
    String? errorMessage,
  }) {
    return SimpleConnectionState(
      status: status ?? this.status,
      selectedServer: selectedServer ?? this.selectedServer,
      connectionStartTime: connectionStartTime ?? this.connectionStartTime,
      connectionDuration: connectionDuration ?? this.connectionDuration,
      ipAddress: ipAddress ?? this.ipAddress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesSent: bytesSent ?? this.bytesSent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Connection status provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, SimpleConnectionState>((ref) {
  return ConnectionNotifier();
});

class ConnectionNotifier extends StateNotifier<SimpleConnectionState> {
  ConnectionNotifier() : super(const SimpleConnectionState());

  Future<void> connect(BuiltInServer server) async {
    state = state.copyWith(
      status: SimpleConnectionStatus.connecting,
      selectedServer: server,
      connectionStartTime: DateTime.now(),
    );

    try {
      // Create VpnConfig from BuiltInServer
      final vpnConfig = server.toVpnConfig();
      
      // Use VPN manager to establish connection
      final vpnManager = VpnManager();
      await vpnManager.initialize();
      
      final success = await vpnManager.connect(vpnConfig);
      
      if (success) {
        state = state.copyWith(
          status: SimpleConnectionStatus.connected,
          connectionDuration: DateTime.now().difference(state.connectionStartTime ?? DateTime.now()),
          ipAddress: server.serverAddress,
        );
      } else {
        state = state.copyWith(
          status: SimpleConnectionStatus.error,
          errorMessage: 'VPN connection failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SimpleConnectionStatus.error,
        errorMessage: 'Connection failed: $e',
      );
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(status: SimpleConnectionStatus.disconnecting);
    
    try {
      // Use VPN manager to disconnect
      final vpnManager = VpnManager();
      final success = await vpnManager.disconnect();
      
      if (success) {
        state = const SimpleConnectionState();
      } else {
        state = state.copyWith(
          status: SimpleConnectionStatus.error,
          errorMessage: 'VPN disconnection failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SimpleConnectionStatus.error,
        errorMessage: 'Disconnection failed: $e',
      );
    }
  }

  void updateConnectionStats({
    required double downloadSpeed,
    required double uploadSpeed,
    required int bytesReceived,
    required int bytesSent,
  }) {
    state = state.copyWith(
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      bytesReceived: bytesReceived,
      bytesSent: bytesSent,
    );
  }
}