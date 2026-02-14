import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/connection_status.dart';
import '../../data/models/built_in_server.dart';
import '../../platform/services/wireguard_vpn_service.dart';

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
    bool clearError = false,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Connection status provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, SimpleConnectionState>((ref) {
  return ConnectionNotifier();
});

class ConnectionNotifier extends StateNotifier<SimpleConnectionState> {
  ConnectionNotifier() : super(const SimpleConnectionState());

  // Use the singleton WireGuardVpnService (not creating new instances each time)
  final WireGuardVpnService _wireGuardService = WireGuardVpnService();
  bool _serviceInitialized = false;

  Future<void> _ensureServiceInitialized() async {
    if (!_serviceInitialized) {
      _serviceInitialized = await _wireGuardService.initialize();
    }
  }

  Future<void> connect(BuiltInServer server) async {
    // Clear any previous error and set connecting state
    state = SimpleConnectionState(
      status: SimpleConnectionStatus.connecting,
      selectedServer: server,
      connectionStartTime: DateTime.now(),
    );

    try {
      // Ensure WireGuard service is initialized
      await _ensureServiceInitialized();
      if (!_serviceInitialized) {
        state = state.copyWith(
          status: SimpleConnectionStatus.error,
          errorMessage: 'VPN service initialization failed. Please restart the app.',
        );
        return;
      }

      // Create VpnConfig from BuiltInServer
      final vpnConfig = server.toVpnConfig();
      
      // Use WireGuard service to establish real connection
      final success = await _wireGuardService.connect(vpnConfig);
      
      if (success) {
        state = state.copyWith(
          status: SimpleConnectionStatus.connected,
          connectionDuration: DateTime.now().difference(state.connectionStartTime ?? DateTime.now()),
          ipAddress: server.serverAddress,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          status: SimpleConnectionStatus.error,
          errorMessage: 'VPN connection failed. Please try a different server.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SimpleConnectionStatus.error,
        errorMessage: 'Connection failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(status: SimpleConnectionStatus.disconnecting, clearError: true);
    
    try {
      final success = await _wireGuardService.disconnect();
      
      if (success) {
        state = const SimpleConnectionState();
      } else {
        state = state.copyWith(
          status: SimpleConnectionStatus.error,
          errorMessage: 'Disconnection failed. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SimpleConnectionStatus.error,
        errorMessage: 'Disconnection error: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  void updateConnectionStats({
    required double downloadSpeed,
    required double uploadSpeed,
    required int bytesReceived,
    required int bytesSent,
  }) {
    if (state.status == SimpleConnectionStatus.connected) {
      state = state.copyWith(
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        bytesReceived: bytesReceived,
        bytesSent: bytesSent,
      );
    }
  }
}