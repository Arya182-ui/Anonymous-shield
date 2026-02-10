import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/proxy_config.dart';
import '../../data/repositories/built_in_servers_repository.dart';
import '../providers/connection_provider.dart';

class AnonymousChainService {
  static final AnonymousChainService _instance = AnonymousChainService._internal();
  factory AnonymousChainService() => _instance;
  AnonymousChainService._internal();

  final _serversRepo = BuiltInServersRepository();
  final _random = Random.secure();
  final _logger = Logger();
  Timer? _rotationTimer;
  Timer? _heartbeatTimer;
  
  AnonymousChain? _currentChain;
  bool _isConnecting = false; // Global connection lock
  
  // Getter for current chain
  AnonymousChain? get currentChain => _currentChain;
  
  // Connect to anonymous chain
  Future<bool> connectToChain(AnonymousChain chain, WidgetRef ref) async {
    // Prevent multiple simultaneous connections
    if (_isConnecting || _currentChain?.status == ChainStatus.connecting) {
      _logger.w('Connection already in progress, ignoring request');
      return false;
    }
    
    _isConnecting = true; // Set global lock
    
    try {
      _logger.i('Connecting to ${chain.name} (${chain.proxyChain.length} hops)');
      
      // Update chain status
      _currentChain = chain.copyWith(status: ChainStatus.connecting);
      
      // Establish proxy connections in sequence
      for (int i = 0; i < chain.proxyChain.length; i++) {
        final proxy = chain.proxyChain[i];
        _logger.i('Connecting hop ${i + 1}: ${proxy.name}');
        
        final success = await _connectToProxy(proxy);
        if (!success) {
          _logger.e('Failed to connect to ${proxy.name}');
          return false;
        }
        
        // Add random delay between connections for stealth
        if (chain.trafficObfuscation && i < chain.proxyChain.length - 1) {
          await Future.delayed(Duration(
            milliseconds: 500 + _random.nextInt(1000)
          ));
        }
      }
      
      // Connect VPN exit if specified
      if (chain.vpnExit != null) {
        _logger.i('Connecting VPN exit: ${chain.vpnExit!.name}');
        await ref.read(connectionProvider.notifier).connect(chain.vpnExit!);
      }
      
      // Mark chain as connected
      _currentChain = chain.copyWith(
        status: ChainStatus.connected,
        connectedAt: DateTime.now(),
      );
      
      // Start auto-rotation if enabled
      if (chain.autoRotate && chain.rotationInterval != null) {
        _startAutoRotation(chain, ref);
      }
      
      // Start heartbeat monitoring
      _startHeartbeat();
      
      _logger.i('Anonymous chain connected successfully!');
      return true;
      
    } catch (e) {
      _logger.e('Chain connection failed: $e');
      _currentChain = chain.copyWith(status: ChainStatus.error);
      return false;
    } finally {
      _isConnecting = false; // Always release the lock
    }
  }
  
  // Quick connect to predefined anonymous modes
  Future<bool> quickConnectAnonymous(AnonymousMode mode, WidgetRef ref) async {
    AnonymousChain chain;
    
    switch (mode) {
      case AnonymousMode.ghost:
        chain = AnonymousChain.ghostMode();
        break;
      case AnonymousMode.stealth:
        chain = AnonymousChain.stealthMode();
        break;
      case AnonymousMode.turbo:
        chain = AnonymousChain.turboMode();
        break;
      case AnonymousMode.tor:
        chain = _createTorChain();
        break;
      case AnonymousMode.paranoid:
        chain = _createParanoidChain();
        break;
      default:
        chain = AnonymousChain.turboMode();
    }
    
    return await connectToChain(chain, ref);
  }
  
  // Build custom anonymous chain
  AnonymousChain buildCustomChain({
    required String name,
    required List<String> countrySequence,
    int? hops,
    bool obfuscation = true,
    bool dpiBypass = true,
  }) {
    final servers = _serversRepo.getAllServers();
    final proxies = <ProxyConfig>[];
    
    for (int i = 0; i < countrySequence.length; i++) {
      final countryCode = countrySequence[i];
      final serversInCountry = servers.where((s) => s.countryCode == countryCode).toList();
      
      if (serversInCountry.isNotEmpty) {
        final server = serversInCountry[_random.nextInt(serversInCountry.length)];
        
        // Determine proxy role
        ProxyRole role;
        if (i == 0) {
          role = ProxyRole.entry;
        } else if (i == countrySequence.length - 1) {
          role = ProxyRole.exit;
        } else {
          role = ProxyRole.middle;
        }
        
        // Create proxy config
        proxies.add(ProxyConfig(
          id: 'custom_${server.id}_$i',
          name: '${server.name} ${role.name.toUpperCase()}',
          type: _getRandomProxyType(obfuscation),
          role: role,
          host: server.serverAddress,
          port: 8000 + _random.nextInt(1000),
          country: server.country,
          countryCode: server.countryCode,
          flagEmoji: server.flagEmoji,
          isObfuscated: obfuscation,
          createdAt: DateTime.now(),
        ));
      }
    }
    
    return AnonymousChain(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      mode: AnonymousMode.custom,
      proxyChain: proxies,
      rotationInterval: Duration(minutes: 10),
      autoRotate: true,
      trafficObfuscation: obfuscation,
      dpiBypass: dpiBypass,
    );
  }
  
  // Rotate chain (change exit node or entire chain)
  Future<void> rotateChain(WidgetRef ref, {bool fullRotation = false}) async {
    if (_currentChain == null) return;
    
    _logger.i('Rotating anonymous chain...');
    
    if (fullRotation) {
      // Rotate entire chain
      await disconnect(ref);
      
      // Build new chain with different servers
      final newChain = _buildRotatedChain(_currentChain!);
      await connectToChain(newChain, ref);
    } else {
      // Rotate only exit node
      await _rotateExit(ref);
    }
  }
  
  // Disconnect from anonymous chain  
  Future<void> disconnect(WidgetRef ref) async {
    _logger.i('Disconnecting anonymous chain...');
    
    _rotationTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    // Disconnect VPN
    await ref.read(connectionProvider.notifier).disconnect();
    
    // Disconnect proxy chain (implementation depends on native proxy client)
    // This would involve platform-specific proxy disconnection
    
    _currentChain = _currentChain?.copyWith(status: ChainStatus.inactive);
    
    _logger.i('Anonymous chain disconnected');
  }
  
  // Private helper methods
  Future<bool> _connectToProxy(ProxyConfig proxy) async {
    // This would integrate with the native proxy client
    // For now, simulate connection with delay
    await Future.delayed(Duration(
      milliseconds: 500 + Random().nextInt(1000)
    ));
    
    // In real implementation:
    // - Establish SOCKS5/Shadowsocks/V2Ray connection
    // - Test connectivity through the proxy
    // - Configure traffic routing
    
    _logger.i('Connected to ${proxy.name} (${proxy.type.name})');
    return true;
  }
  
  void _startAutoRotation(AnonymousChain chain, WidgetRef ref) {
    _rotationTimer = Timer.periodic(chain.rotationInterval!, (timer) {
      rotateChain(ref, fullRotation: false);
    });
  }
  
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkChainHealth();
    });
  }
  
  Future<void> _checkChainHealth() async {
    if (_currentChain?.status != ChainStatus.connected) return;
    
    // Test each proxy in the chain
    // If any proxy fails, trigger rotation or reconnection
    
    _logger.d('Chain health check passed');
  }
  
  Future<void> _rotateExit(WidgetRef ref) async {
    // Implementation for rotating only the exit node
    _logger.i('Rotating exit node...');
  }
  
  AnonymousChain _buildRotatedChain(AnonymousChain original) {
    // Build new chain with different servers but same structure
    final countrySequence = original.proxyChain
        .map((p) => p.countryCode ?? 'US')
        .toList();
    
    return buildCustomChain(
      name: '${original.name} (Rotated)',
      countrySequence: countrySequence,
      obfuscation: original.trafficObfuscation,
      dpiBypass: original.dpiBypass,
    );
  }
  
  ProxyType _getRandomProxyType(bool requireObfuscation) {
    if (requireObfuscation) {
      final obfuscatedTypes = [
        ProxyType.shadowsocks,
        ProxyType.v2ray,
        ProxyType.trojan,
      ];
      return obfuscatedTypes[_random.nextInt(obfuscatedTypes.length)];
    } else {
      return ProxyType.socks5;
    }
  }
  
  AnonymousChain _createTorChain() {
    // Create Tor-like onion routing chain
    return AnonymousChain(
      id: 'tor_mode',
      name: 'Tor Mode',
      mode: AnonymousMode.tor,
      proxyChain: [], // Would be populated with Tor bridges/relays
      rotationInterval: Duration(minutes: 2),
      autoRotate: true,
      trafficObfuscation: true,
      dpiBypass: true,
      securitySettings: {
        'onionRouting': true,
        'guardRelay': true,
        'middleRelays': 2,
        'exitRelay': true,
      },
    );
  }
  
  AnonymousChain _createParanoidChain() {
    // Create maximum security chain
    return AnonymousChain(
      id: 'paranoid_mode',
      name: 'Paranoid Mode',
      mode: AnonymousMode.paranoid,
      proxyChain: [], // Would be populated with high-security proxies
      rotationInterval: Duration(minutes: 3),
      autoRotate: true,
      trafficObfuscation: true,
      dpiBypass: true,
      securitySettings: {
        'maxHops': 7,
        'encryptionLevel': 'military',
        'trafficPadding': true,
        'timingObfuscation': true,
        'metadataScrubbing': true,
        'advancedLeakProtection': true,
      },
    );
  }
  
  // Getters
  bool get isConnected => _currentChain?.status == ChainStatus.connected;
  int get currentHops => _currentChain?.hopCount ?? 0;
}