import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/connection_status.dart';

/// Native VPN Method Channel
/// यह Flutter और Native Android VPN Service के बीच communication handle करता है
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

  /// Start anonymous chain (Ghost/Stealth/Paranoid modes)
  static Future<Map<String, dynamic>> startAnonymousChain(AnonymousChain chain) async {
    try {
      _logger.i('Starting anonymous chain: ${chain.mode} with ${chain.hopCount} hops');
      
      final chainMap = {
        'chainId': chain.id,
        'mode': chain.mode.name,
        'hopCount': chain.hopCount,
        'proxyServers': chain.proxyChain.map((proxy) => {
          'id': proxy.id,
          'name': proxy.name,
          'host': proxy.host,
          'port': proxy.port,
          'type': proxy.type.name,
          'username': proxy.username,
          'password': proxy.password,
          'method': proxy.method,
          'country': proxy.country,
          'countryCode': proxy.countryCode,
          'isObfuscated': proxy.isObfuscated,
        }).toList(),
        'vpnExit': chain.vpnExit != null ? {
          'serverName': chain.vpnExit!.name,
          'serverHost': chain.vpnExit!.host,
          'serverPort': chain.vpnExit!.port,
          'protocol': 'wireguard',
          'clientIpv4': '10.0.0.2',
          'dnsServers': ['1.1.1.1', '1.0.0.1'],
        } : null,
        'trafficObfuscation': chain.trafficObfuscation,
        'obfuscationType': 'https',
        'rotationInterval': chain.rotationInterval?.inMilliseconds ?? 600000,
        'autoRotate': chain.autoRotate,
      };

      final result = await _channel.invokeMethod('startAnonymousChain', chainMap);
      _logger.i('Anonymous chain start result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start anonymous chain: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Stop anonymous chain
  static Future<Map<String, dynamic>> stopAnonymousChain() async {
    try {
      _logger.i('Stopping anonymous chain');
      
      final result = await _channel.invokeMethod('stopAnonymousChain');
      _logger.i('Anonymous chain stop result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to stop anonymous chain: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get anonymous chain status
  static Future<Map<String, dynamic>> getChainStatus() async {
    try {
      final result = await _channel.invokeMethod('getChainStatus');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to get chain status: $e');
      return {
        'isActive': false,
        'mode': 'inactive',
        'hopCount': 0,
        'currentHop': 0,
        'error': e.toString(),
      };
    }
  }

  /// Force chain rotation
  static Future<Map<String, dynamic>> rotateChain() async {
    try {
      _logger.i('Rotating anonymous chain');
      
      final result = await _channel.invokeMethod('rotateChain');
      _logger.i('Chain rotation result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to rotate chain: $e');
      return {'success': false, 'error': e.toString()};
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

  /// Get detailed connection information (IP, location, leak tests)
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

  /// Set up method call handler for status updates from native side
  static void setMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _channel.setMethodCallHandler(handler);
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

  /// Handle status updates from native Android service
  static Future<void> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatusUpdate':
        _logger.d('VPN status update: ${call.arguments}');
        // Handle VPN status updates
        break;
      case 'onChainStatusUpdate':
        _logger.d('Chain status update: ${call.arguments}');
        // Handle anonymous chain status updates
        break;
      case 'onError':
        _logger.e('Native VPN error: ${call.arguments}');
        // Handle errors from native side
        break;
      default:
        _logger.w('Unknown method call from native: ${call.method}');
    }
  }
}

/// Connection info details
class ConnectionInfo {
  final String publicIp;
  final String country;
  final String city;
  final String isp;
  final double latitude;
  final double longitude;
  final String dnsLeakTest;
  final String ipv6LeakTest;
  final String webrtcLeakTest;

  ConnectionInfo({
    required this.publicIp,
    required this.country,
    required this.city,
    required this.isp,
    required this.latitude,
    required this.longitude,
    required this.dnsLeakTest,
    required this.ipv6LeakTest,
    required this.webrtcLeakTest,
  });

  factory ConnectionInfo.fromMap(Map<String, dynamic> map) {
    return ConnectionInfo(
      publicIp: map['publicIp'] ?? '0.0.0.0',
      country: map['country'] ?? 'Unknown',
      city: map['city'] ?? 'Unknown',
      isp: map['isp'] ?? 'Unknown',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      dnsLeakTest: map['dnsLeakTest'] ?? 'unknown',
      ipv6LeakTest: map['ipv6LeakTest'] ?? 'unknown',
      webrtcLeakTest: map['webrtcLeakTest'] ?? 'unknown',
    );
  }

  bool get hasDnsLeak => dnsLeakTest != 'passed';
  bool get hasIpv6Leak => ipv6LeakTest != 'passed';
  bool get hasWebrtcLeak => webrtcLeakTest != 'passed';
  bool get hasAnyLeaks => hasDnsLeak || hasIpv6Leak || hasWebrtcLeak;
}

/// Chain status information
class ChainStatusInfo {
  final bool isActive;
  final String mode;
  final int hopCount;
  final int currentHop;
  final int bytesObfuscated;
  final int rotationCount;
  final String status;

  ChainStatusInfo({
    required this.isActive,
    required this.mode,
    required this.hopCount,
    required this.currentHop,
    required this.bytesObfuscated,
    required this.rotationCount,
    required this.status,
  });

  factory ChainStatusInfo.fromMap(Map<String, dynamic> map) {
    return ChainStatusInfo(
      isActive: map['isActive'] ?? false,
      mode: map['mode'] ?? 'inactive',
      hopCount: map['hopCount'] ?? 0,
      currentHop: map['currentHop'] ?? 0,
      bytesObfuscated: map['bytesObfuscated'] ?? 0,
      rotationCount: map['rotationCount'] ?? 0,
      status: map['status'] ?? 'inactive',
    );
  }

  bool get isConnected => status == 'connected';
  bool get isConnecting => status == 'connecting';
  bool get isRotating => status == 'rotating';
}