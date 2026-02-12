import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/proxy_config.dart';

/// Anonymous Chain Method Channel
/// विशेष रूप से anonymous modes (Ghost, Stealth, Paranoid) के लिए native communication
class AnonymousMethodChannel {
  static const String _channelName = 'com.privacyvpn.privacy_vpn_controller/anonymous';
  static const MethodChannel _channel = MethodChannel(_channelName);
  static final Logger _logger = Logger();

  /// Start Ghost Mode - 5+ hop maximum anonymity
  static Future<Map<String, dynamic>> startGhostMode({
    required List<ProxyConfig> proxyServers,
    int hopCount = 5,
    bool autoRotate = true,
    Duration rotationInterval = const Duration(minutes: 10),
  }) async {
    try {
      _logger.i('Starting Ghost Mode with $hopCount hops');
      
      final ghostConfig = {
        'mode': 'ghost',
        'hopCount': hopCount,
        'proxyServers': proxyServers.map((proxy) => proxy.toMap()).toList(),
        'autoRotate': autoRotate,
        'rotationInterval': rotationInterval.inMilliseconds,
        'trafficObfuscation': true,
        'dpiBypass': true,
        'securitySettings': {
          'maxHops': 7,
          'minLatency': 200,
          'encryptionLevel': 'maximum',
          'dnsLeakProtection': true,
          'ipv6Blocking': true,
          'webrtcBlocking': true,
        },
      };

      final result = await _channel.invokeMethod('startGhostMode', ghostConfig);
      _logger.i('Ghost Mode result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start Ghost Mode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Start Stealth Mode - DPI evasion and censorship bypass
  static Future<Map<String, dynamic>> startStealthMode({
    required List<ProxyConfig> proxyServers,
    int hopCount = 3,
    String obfuscationType = 'https',
  }) async {
    try {
      _logger.i('Starting Stealth Mode with DPI evasion');
      
      final stealthConfig = {
        'mode': 'stealth',
        'hopCount': hopCount,
        'proxyServers': proxyServers
            .where((proxy) => proxy.isObfuscated || proxy.type == ProxyType.shadowsocks)
            .map((proxy) => proxy.toMap())
            .toList(),
        'obfuscationType': obfuscationType,
        'trafficObfuscation': true,
        'dpiBypass': true,
        'securitySettings': {
          'dpiEvasion': 'advanced',
          'protocolMimicry': 'https',
          'packetObfuscation': true,
          'timingRandomization': true,
          'censorshipResistance': 'maximum',
        },
      };

      final result = await _channel.invokeMethod('startStealthMode', stealthConfig);
      _logger.i('Stealth Mode result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start Stealth Mode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Start Paranoid Mode - NSA-proof maximum security
  static Future<Map<String, dynamic>> startParanoidMode({
    required List<ProxyConfig> proxyServers,
    int hopCount = 6,
    Duration rotationInterval = const Duration(minutes: 3),
  }) async {
    try {
      _logger.i('Starting Paranoid Mode - NSA-proof anonymity');
      
      // Filter out Five Eyes countries for paranoid mode
      final fiveEyesCountries = {'US', 'UK', 'CA', 'AU', 'NZ'};
      final safeServers = proxyServers
          .where((proxy) => !fiveEyesCountries.contains(proxy.countryCode))
          .toList();

      if (safeServers.length < hopCount) {
        throw Exception('Not enough safe servers for Paranoid Mode (need $hopCount, found ${safeServers.length})');
      }

      final paranoidConfig = {
        'mode': 'paranoid',
        'hopCount': hopCount,
        'proxyServers': safeServers.map((proxy) => proxy.toMap()).toList(),
        'rotationInterval': rotationInterval.inMilliseconds,
        'autoRotate': true,
        'trafficObfuscation': true,
        'securitySettings': {
          'nsaProof': true,
          'maximalEncryption': true,
          'geographicDistribution': true,
          'excludeFiveEyes': true,
          'randomExitNodes': true,
          'advancedObfuscation': true,
        },
      };

      final result = await _channel.invokeMethod('startParanoidMode', paranoidConfig);
      _logger.i('Paranoid Mode result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start Paranoid Mode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Start Turbo Mode - Fast 2-3 hop anonymity
  static Future<Map<String, dynamic>> startTurboMode({
    required List<ProxyConfig> proxyServers,
    int hopCount = 2,
  }) async {
    try {
      _logger.i('Starting Turbo Mode with optimized routing');
      
      // Select fastest servers for turbo mode
      final fastServers = proxyServers
          .where((proxy) => proxy.type == ProxyType.shadowsocks || proxy.type == ProxyType.socks5)
          .take(hopCount)
          .toList();

      final turboConfig = {
        'mode': 'turbo',
        'hopCount': hopCount,
        'proxyServers': fastServers.map((proxy) => proxy.toMap()).toList(),
        'trafficObfuscation': false, // Disabled for speed
        'rotationInterval': 900000, // 15 minutes
        'securitySettings': {
          'optimizeSpeed': true,
          'preferLowLatency': true,
          'minimumEncryption': false,
        },
      };

      final result = await _channel.invokeMethod('startTurboMode', turboConfig);
      _logger.i('Turbo Mode result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to start Turbo Mode: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Enable traffic obfuscation
  static Future<Map<String, dynamic>> enableTrafficObfuscation({
    String pattern = 'https',
    bool fakeTraffic = true,
    bool timingObfuscation = true,
  }) async {
    try {
      _logger.i('Enabling traffic obfuscation: $pattern');
      
      final obfuscationConfig = {
        'pattern': pattern,
        'fakeTraffic': fakeTraffic,
        'timingObfuscation': timingObfuscation,
        'packetMangling': true,
        'dpiEvasion': true,
      };

      final result = await _channel.invokeMethod('enableTrafficObfuscation', obfuscationConfig);
      _logger.i('Traffic obfuscation result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to enable traffic obfuscation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Disable traffic obfuscation
  static Future<Map<String, dynamic>> disableTrafficObfuscation() async {
    try {
      _logger.i('Disabling traffic obfuscation');
      
      final result = await _channel.invokeMethod('disableTrafficObfuscation');
      _logger.i('Traffic obfuscation disabled: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to disable traffic obfuscation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get obfuscation statistics
  static Future<Map<String, dynamic>> getObfuscationStats() async {
    try {
      final result = await _channel.invokeMethod('getObfuscationStats');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to get obfuscation stats: $e');
      return {
        'packetsObfuscated': 0,
        'bytesObfuscated': 0,
        'isActive': false,
        'error': e.toString(),
      };
    }
  }

  /// Force immediate chain rotation
  static Future<Map<String, dynamic>> forceChainRotation() async {
    try {
      _logger.i('Force rotating anonymous chain');
      
      final result = await _channel.invokeMethod('forceChainRotation');
      _logger.i('Chain rotation result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to rotate chain: $e');
      return {'success': false, 'error': e.toString()};  
    }
  }

  /// Get detailed chain information
  static Future<AnonymousChainInfo> getChainInfo() async {
    try {
      final result = await _channel.invokeMethod('getChainInfo');
      final infoMap = Map<String, dynamic>.from(result);
      return AnonymousChainInfo.fromMap(infoMap);
      
    } catch (e) {
      _logger.e('Failed to get chain info: $e');
      return AnonymousChainInfo.empty();
    }
  }

  /// Test chain connectivity
  static Future<Map<String, dynamic>> testChainConnectivity() async {
    try {
      _logger.i('Testing anonymous chain connectivity');
      
      final result = await _channel.invokeMethod('testChainConnectivity');
      _logger.i('Chain connectivity test result: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to test chain connectivity: $e');
      return {
        'success': false,
        'latency': 9999,
        'hopsReachable': 0,
        'error': e.toString(),
      };
    }
  }

  /// Stop all anonymous chain activities
  static Future<Map<String, dynamic>> stopAnonymousChain() async {
    try {
      _logger.i('Stopping anonymous chain');
      
      final result = await _channel.invokeMethod('stopAnonymousChain');
      _logger.i('Anonymous chain stopped: $result');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      _logger.e('Failed to stop anonymous chain: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Set up method call handler for anonymous chain updates
  static void setMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _channel.setMethodCallHandler(handler);
  }

  /// Handle anonymous updates from native Android service
  static Future<void> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onChainConnectionUpdate':
        _logger.d('Chain connection update: ${call.arguments}');
        // Handle chain connection status updates
        break;
      case 'onChainRotation':
        _logger.d('Chain rotation event: ${call.arguments}');
        // Handle chain rotation notifications
        break;
      case 'onObfuscationUpdate':
        _logger.d('Obfuscation update: ${call.arguments}');
        // Handle traffic obfuscation status updates
        break;
      case 'onSecurityAlert':
        _logger.w('Security alert: ${call.arguments}');
        // Handle security alerts (potential leaks, etc.)
        break;
      case 'onAnonymityLevelUpdate':
        _logger.d('Anonymity level update: ${call.arguments}');
        // Handle anonymity level changes
        break;
      default:
        _logger.w('Unknown anonymous method call: ${call.method}');
    }
  }
}

/// Detailed anonymous chain information
class AnonymousChainInfo {
  final String mode;
  final int hopCount;
  final int activeHops;
  final List<String> hopCountries;
  final Duration uptime;
  final int rotationCount;
  final bool isObfuscated;
  final String securityLevel;
  final Map<String, dynamic> performance;

  AnonymousChainInfo({
    required this.mode,
    required this.hopCount,
    required this.activeHops,
    required this.hopCountries,
    required this.uptime,
    required this.rotationCount,
    required this.isObfuscated,
    required this.securityLevel,
    required this.performance,
  });

  factory AnonymousChainInfo.fromMap(Map<String, dynamic> map) {
    return AnonymousChainInfo(
      mode: map['mode'] ?? 'inactive',
      hopCount: map['hopCount'] ?? 0,
      activeHops: map['activeHops'] ?? 0,
      hopCountries: List<String>.from(map['hopCountries'] ?? []),
      uptime: Duration(milliseconds: map['uptime'] ?? 0),
      rotationCount: map['rotationCount'] ?? 0,
      isObfuscated: map['isObfuscated'] ?? false,
      securityLevel: map['securityLevel'] ?? 'none',
      performance: Map<String, dynamic>.from(map['performance'] ?? {}),
    );
  }

  factory AnonymousChainInfo.empty() {
    return AnonymousChainInfo(
      mode: 'inactive',
      hopCount: 0,
      activeHops: 0,
      hopCountries: [],
      uptime: Duration.zero,
      rotationCount: 0,
      isObfuscated: false,
      securityLevel: 'none',
      performance: {},
    );
  }

  bool get isActive => mode != 'inactive' && activeHops > 0;
  bool get isFullyConnected => activeHops == hopCount;
  String get anonymityLevel {
    if (hopCount >= 5) return 'Maximum (NSA-Proof)';
    if (hopCount >= 3) return 'High';
    if (hopCount >= 2) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'hopCount': hopCount,
      'activeHops': activeHops,
      'hopCountries': hopCountries,
      'uptime': uptime.inMilliseconds,
      'rotationCount': rotationCount,
      'isObfuscated': isObfuscated,
      'securityLevel': securityLevel,
      'performance': performance,
    };
  }
}

// Additional methods for testing compatibility
extension AnonymousMethodChannelTesting on AnonymousMethodChannel {
  /// Start anonymous chain (test compatibility method)
  static Future<Map<String, dynamic>> startAnonymousChain(AnonymousChain chain) async {
    try {
      AnonymousMethodChannel._logger.i('Starting anonymous chain via test method');
      
      // Route to appropriate method based on chain type
      switch (chain.mode) {
        case AnonymousMode.ghost:
          return await AnonymousMethodChannel.startGhostMode(proxyServers: chain.proxyChain);
        case AnonymousMode.stealth:
          return await AnonymousMethodChannel.startStealthMode(proxyServers: chain.proxyChain);
        case AnonymousMode.paranoid:
          return await AnonymousMethodChannel.startParanoidMode(proxyServers: chain.proxyChain);
        case AnonymousMode.turbo:
          return await AnonymousMethodChannel.startTurboMode(proxyServers: chain.proxyChain);
        case AnonymousMode.tor:
        case AnonymousMode.custom:
          return {'success': false, 'error': 'Unsupported chain mode: ${chain.mode.name}'};
      }
      
    } catch (e) {
      AnonymousMethodChannel._logger.e('Failed to start anonymous chain: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Rotate chain (test compatibility)
  static Future<Map<String, dynamic>> rotateChain(int chainId) async {
    try {
      AnonymousMethodChannel._logger.i('Rotating chain: $chainId');
      
      final result = await AnonymousMethodChannel._channel.invokeMethod('rotateChain', {
        'chainId': chainId,
        'forceRotation': true,
      });
      
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      AnonymousMethodChannel._logger.e('Failed to rotate chain: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get chain status (test compatibility)
  static Future<Map<String, dynamic>> getChainStatus() async {
    try {
      final result = await AnonymousMethodChannel._channel.invokeMethod('getChainStatus');
      return Map<String, dynamic>.from(result);
      
    } catch (e) {
      AnonymousMethodChannel._logger.e('Failed to get chain status: $e');
      return {
        'success': false, 
        'error': e.toString(),
        'status': AnonymousChainInfo.empty().toMap(),
      };
    }
  }
}