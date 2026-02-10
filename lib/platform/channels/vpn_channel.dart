import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/connection_status.dart';

class VpnMethodChannel {
  static final VpnMethodChannel _instance = VpnMethodChannel._internal();
  factory VpnMethodChannel() => _instance;
  VpnMethodChannel._internal();

  static const MethodChannel _channel = MethodChannel(AppConstants.vpnChannelName);
  final Logger _logger = Logger();

  StreamController<ConnectionStatus>? _statusController;
  Stream<ConnectionStatus>? _statusStream;

  /// Initialize the VPN method channel
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    _statusController = StreamController<ConnectionStatus>.broadcast();
    _statusStream = _statusController!.stream;
    
    _logger.i('VPN method channel initialized');
  }

  /// Get the status update stream
  Stream<ConnectionStatus> get statusStream {
    _statusStream ??= _statusController!.stream;
    return _statusStream!;
  }

  /// Handle incoming method calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _logger.d('Received method call: ${call.method}');
    
    switch (call.method) {
      case 'onVpnStatusChanged':
        _handleVpnStatusChange(call.arguments);
        break;
      case 'onConnectionStatistics':
        _handleConnectionStats(call.arguments);
        break;
      case 'onVpnError':
        _handleVpnError(call.arguments);
        break;
      case 'onKillSwitchTriggered':
        _handleKillSwitchTrigger(call.arguments);
        break;
      default:
        _logger.w('Unknown method call: ${call.method}');
    }
  }

  /// Start VPN connection with configuration
  Future<bool> startVpn(VpnConfig config) async {
    try {
      _logger.i('Starting VPN connection to ${config.name}');
      
      final configData = {
        'id': config.id,
        'name': config.name,
        'serverAddress': config.serverAddress,
        'port': config.port,
        'privateKey': config.privateKey,
        'publicKey': config.publicKey,
        'presharedKey': config.presharedKey,
        'allowedIPs': config.allowedIPs,
        'dnsServers': config.dnsServers,
        'mtu': config.mtu,
      };
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodStartVpn,
        configData,
      );
      
      _logger.i('VPN start result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to start VPN', error: e, stackTrace: stack);
      _handleVpnError({'error': e.toString(), 'timestamp': DateTime.now().millisecondsSinceEpoch});
      return false;
    }
  }

  /// Stop VPN connection
  Future<bool> stopVpn() async {
    try {
      _logger.i('Stopping VPN connection');
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodStopVpn,
      );
      
      _logger.i('VPN stop result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to stop VPN', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get current VPN status
  Future<ConnectionStatus> getVpnStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<String, dynamic>>(
        AppConstants.methodGetVpnStatus,
      );
      
      if (result != null) {
        return _parseConnectionStatus(result);
      }
      
      return const ConnectionStatus();
    } catch (e, stack) {
      _logger.e('Failed to get VPN status', error: e, stackTrace: stack);
      return const ConnectionStatus(vpnStatus: VpnStatus.error);
    }
  }

  /// Enable kill switch
  Future<bool> enableKillSwitch() async {
    try {
      _logger.i('Enabling kill switch');
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodEnableKillSwitch,
      );
      
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to enable kill switch', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Disable kill switch
  Future<bool> disableKillSwitch() async {
    try {
      _logger.i('Disabling kill switch');
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodDisableKillSwitch,
      );
      
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to disable kill switch', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Request VPN permission
  Future<bool> requestVpnPermission() async {
    try {
      _logger.i('Requesting VPN permission');
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodRequestVpnPermission,
      );
      
      _logger.i('VPN permission result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to request VPN permission', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Check if VPN permission is granted
  Future<bool> checkVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodCheckVpnPermission,
      );
      
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to check VPN permission', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Handle VPN status changes from native code
  void _handleVpnStatusChange(dynamic arguments) {
    try {
      final statusData = arguments as Map<String, dynamic>;
      final status = _parseConnectionStatus(statusData);
      _statusController?.add(status);
      
      _logger.d('VPN status changed: ${status.vpnStatus}');
    } catch (e, stack) {
      _logger.e('Failed to handle VPN status change', error: e, stackTrace: stack);
    }
  }

  /// Handle connection statistics updates
  void _handleConnectionStats(dynamic arguments) {
    try {
      final statsData = arguments as Map<String, dynamic>;
      final currentStatus = _statusController?.hasListener == true 
          ? null  // Would need to get current status
          : const ConnectionStatus();
      
      final updatedStatus = (currentStatus ?? const ConnectionStatus()).copyWith(
        bytesReceived: statsData['bytesReceived'] as int? ?? 0,
        bytesSent: statsData['bytesSent'] as int? ?? 0,
        connectionDuration: Duration(milliseconds: statsData['durationMs'] as int? ?? 0),
      );
      
      _statusController?.add(updatedStatus);
    } catch (e, stack) {
      _logger.e('Failed to handle connection stats', error: e, stackTrace: stack);
    }
  }

  /// Handle VPN errors from native code
  void _handleVpnError(dynamic arguments) {
    try {
      final errorData = arguments as Map<String, dynamic>;
      final errorMessage = errorData['error'] as String? ?? 'Unknown VPN error';
      final timestamp = errorData['timestamp'] as int?;
      
      final errorStatus = ConnectionStatus(
        vpnStatus: VpnStatus.error,
        lastErrorMessage: errorMessage,
        lastErrorAt: timestamp != null 
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now(),
      );
      
      _statusController?.add(errorStatus);
      _logger.e('VPN error received: $errorMessage');
    } catch (e, stack) {
      _logger.e('Failed to handle VPN error', error: e, stackTrace: stack);
    }
  }

  /// Handle kill switch triggers
  void _handleKillSwitchTrigger(dynamic arguments) {
    try {
      final triggerData = arguments as Map<String, dynamic>;
      final isActive = triggerData['active'] as bool? ?? false;
      
      final status = ConnectionStatus(
        killSwitchActive: isActive,
        lastErrorMessage: isActive ? 'Kill switch activated - blocking traffic' : null,
      );
      
      _statusController?.add(status);
      _logger.w('Kill switch ${isActive ? 'activated' : 'deactivated'}');
    } catch (e, stack) {
      _logger.e('Failed to handle kill switch trigger', error: e, stackTrace: stack);
    }
  }

  /// Parse connection status from native data
  ConnectionStatus _parseConnectionStatus(Map<String, dynamic> data) {
    VpnStatus vpnStatus = VpnStatus.disconnected;
    final statusString = data['vpnStatus'] as String?;
    
    switch (statusString) {
      case 'connected':
        vpnStatus = VpnStatus.connected;
        break;
      case 'connecting':
        vpnStatus = VpnStatus.connecting;
        break;
      case 'disconnecting':
        vpnStatus = VpnStatus.disconnecting;
        break;
      case 'reconnecting':
        vpnStatus = VpnStatus.reconnecting;
        break;
      case 'error':
        vpnStatus = VpnStatus.error;
        break;
      default:
        vpnStatus = VpnStatus.disconnected;
    }
    
    return ConnectionStatus(
      vpnStatus: vpnStatus,
      currentServerId: data['serverId'] as String?,
      currentServerName: data['serverName'] as String?,
      currentIpAddress: data['ipAddress'] as String?,
      currentCountry: data['country'] as String?,
      currentCity: data['city'] as String?,
      connectedAt: data['connectedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['connectedAt'] as int)
          : null,
      bytesReceived: data['bytesReceived'] as int? ?? 0,
      bytesSent: data['bytesSent'] as int? ?? 0,
      killSwitchActive: data['killSwitchActive'] as bool? ?? false,
      dnsLeakProtectionActive: data['dnsLeakProtectionActive'] as bool? ?? false,
      ipv6Blocked: data['ipv6Blocked'] as bool? ?? false,
    );
  }

  /// Dispose resources
  void dispose() {
    _statusController?.close();
    _statusController = null;
    _statusStream = null;
  }
}