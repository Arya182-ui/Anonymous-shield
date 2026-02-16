import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/connection_status.dart';

/// Native VPN Method Channel
/// Handles Flutter <-> Native Android VPN Service communication
class VpnMethodChannel {
  static const String _channelName = 'com.privacyvpn.privacy_vpn_controller/vpn';
  static const MethodChannel _channel = MethodChannel(_channelName);
  static final Logger _logger = Logger();

  /// Request VPN permission from user
  static Future<Map<String, dynamic>> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod('requestVpnPermission');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to request VPN permission: $e');
      return {'permissionRequired': true, 'error': e.toString()};
    }
  }

  /// Start VPN connection
  static Future<Map<String, dynamic>> startVpn(VpnConfig config) async {
    try {
      _logger.i('Starting VPN: ${config.serverName}');
      
      final configMap = {
        'serverName': config.serverName,
        'serverHost': config.serverHost,
        'serverPort': config.serverPort,
        'protocol': config.protocol,
        'clientIpv4': config.clientIpv4,
        'dnsServers': config.dnsServers,
        'mtu': config.mtu,
        'killSwitchEnabled': config.killSwitchEnabled,
        'privateKey': config.privateKey,
        'publicKey': config.publicKey,
        'presharedKey': config.presharedKey,
        'customConfig': config.customConfig,
      };

      final result = await _channel.invokeMethod('startVpn', configMap);
      _logger.i('VPN start result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start VPN: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Stop VPN connection
  static Future<Map<String, dynamic>> stopVpn() async {
    try {
      _logger.i('Stopping VPN connection');
      
      final result = await _channel.invokeMethod('stopVpn');
      _logger.i('VPN stop result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to stop VPN: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get current VPN status
  static Future<ConnectionStatus> getVpnStatus() async {
    try {
      final result = await _channel.invokeMethod('getVpnStatus');
      final statusMap = Map<String, dynamic>.from(result);
      
      return ConnectionStatus(
        vpnStatus: statusMap['isConnected'] == true ? VpnStatus.connected : VpnStatus.disconnected,
        currentServerName: statusMap['serverName'] ?? '',
        connectedAt: DateTime.fromMillisecondsSinceEpoch(
          statusMap['connectionTime'] ?? 0
        ),
        bytesReceived: statusMap['bytesIn'] ?? 0,
        bytesSent: statusMap['bytesOut'] ?? 0,
        currentIpAddress: statusMap['publicIp'] ?? '0.0.0.0',
        currentCountry: statusMap['country'] ?? 'Unknown',
      );
      
    } catch (e) {
      _logger.e('Failed to get VPN status: $e');
      return ConnectionStatus.disconnected();
    }
  }

  /// Enable/disable kill switch
  static Future<Map<String, dynamic>> enableKillSwitch(bool enabled) async {
    try {
      _logger.i('${enabled ? 'Enabling' : 'Disabling'} kill switch');
      
      final result = await _channel.invokeMethod('enableKillSwitch', enabled);
      _logger.i('Kill switch result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to configure kill switch: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get detailed connection information
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    try {
      final result = await _channel.invokeMethod('getConnectionInfo');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to get connection info: $e');
      return {
        'publicIp': '0.0.0.0',
        'country': 'Unknown',
        'city': 'Unknown',
        'error': e.toString(),
      };
    }
  }

  /// Registered method call handlers
  static final List<Future<dynamic> Function(MethodCall call)> _handlers = [];
  static bool _dispatcherRegistered = false;

  /// Register a method call handler
  static void setMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _handlers.add(handler);
    if (!_dispatcherRegistered) {
      _channel.setMethodCallHandler(_dispatchToAllHandlers);
      _dispatcherRegistered = true;
    }
  }

  /// Remove a handler
  static void removeMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _handlers.remove(handler);
  }

  /// Dispatch to all handlers
  static Future<dynamic> _dispatchToAllHandlers(MethodCall call) async {
    dynamic lastResult;
    for (final handler in List.of(_handlers)) {
      try {
        lastResult = await handler(call);
      } catch (e) {
        _logger.e('Handler error for ${call.method}: $e');
      }
    }
    return lastResult;
  }

  /// Start WireGuard Tunnel
  static Future<Map<String, dynamic>> startWireGuardTunnel(Map<String, dynamic> configMap) async {
    try {
      _logger.i('Starting WireGuard tunnel');
      final result = await _channel.invokeMethod('startWireGuardTunnel', configMap);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to start WireGuard tunnel: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Stop WireGuard Tunnel
  static Future<Map<String, dynamic>> stopWireGuardTunnel() async {
    try {
      _logger.i('Stopping WireGuard tunnel');
      final result = await _channel.invokeMethod('stopWireGuardTunnel');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to stop WireGuard tunnel: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generate WireGuard Keys
  static Future<Map<String, dynamic>> generateWireGuardKeys() async {
    try {
      _logger.d('Generating WireGuard keys');
      final result = await _channel.invokeMethod('generateWireGuardKeys');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to generate WireGuard keys: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check WireGuard Health
  static Future<Map<String, dynamic>> checkWireGuardHealth() async {
    try {
      final result = await _channel.invokeMethod('checkWireGuardHealth');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to check WireGuard health: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get WireGuard Stats
  static Future<Map<String, dynamic>> getWireGuardStats() async {
    try {
      final result = await _channel.invokeMethod('getWireGuardStats');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      _logger.e('Failed to get WireGuard stats: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle status updates from native
  static Future<void> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatusUpdate':
        _logger.d('VPN status update: ${call.arguments}');
        break;
      case 'onError':
        _logger.e('Native VPN error: ${call.arguments}');
        break;
      default:
        _logger.w('Unknown method call from native: ${call.method}');
    }
  }
}
