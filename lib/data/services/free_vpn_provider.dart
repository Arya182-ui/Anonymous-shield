import 'package:logger/logger.dart';
import 'dart:math';
import '../models/vpn_config.dart';
import 'warp_config_generator.dart';

/// Free VPN providers integration service  
/// अब यह automatic configuration के साथ multiple free providers support करता है
class FreeVpnProvider {
  static final FreeVpnProvider _instance = FreeVpnProvider._internal();
  factory FreeVpnProvider() => _instance;
  FreeVpnProvider._internal();
  
  final Logger _logger = Logger();
  final WarpConfigGenerator _warpGenerator = WarpConfigGenerator();
  
  /// Get free VPN configurations from multiple providers
  /// अब automatic configuration के साथ multiple providers से configs मिलते हैं
  Future<List<VpnConfig>> getFreeVpnConfigs() async {
    final configs = <VpnConfig>[];
    
    try {
      // 1. Cloudflare WARP (Best free option - Unlimited)
      _logger.i('Fetching Cloudflare WARP configuration...');
      final warpConfig = await generateWarpConfig();
      if (warpConfig != null) {
        configs.add(warpConfig);
      }
      
      // 2. Outline VPN (Free servers)
      final outlineConfigs = await _getOutlineFreeConfigs();
      configs.addAll(outlineConfigs);
      
      // 3. ProtonVPN Free servers
      configs.addAll(_getProtonVpnFreeConfigs());
      
      // 4. Windscribe Free servers (10GB/month)
      configs.addAll(_getWindscribeFreeConfigs());
      
      // 5. Hide.me Free servers (10GB/month)
      configs.addAll(_getHideMeFreeConfigs());
      
      // 6. TunnelBear Free (500MB/month)
      configs.addAll(_getTunnelBearFreeConfigs());
      
      _logger.i('Retrieved ${configs.length} free VPN configurations');
      return configs;
      
    } catch (e, stack) {
      _logger.e('Failed to get free VPN configs', error: e, stackTrace: stack);
      return configs;
    }
  }
  
  /// Generate Cloudflare WARP config with optional endpoint override
  /// Each call uses new keys + a random endpoint for IP diversity
  Future<VpnConfig?> generateWarpConfig({String? overrideEndpoint}) async {
    try {
      return await _warpGenerator.generateWarpConfig(overrideEndpoint: overrideEndpoint);
    } catch (e, stack) {
      _logger.e('Failed to generate WARP config', error: e, stackTrace: stack);
      return null;
    }
  }
  
  /// Get multiple WARP configurations for rotation
  Future<List<VpnConfig>> getMultipleWarpConfigs({int count = 3}) async {
    final configs = <VpnConfig>[];
    
    for (int i = 0; i < count; i++) {
      try {
        final config = await generateWarpConfig();
        if (config != null) {
          final updatedConfig = VpnConfig(
            id: 'warp-${DateTime.now().millisecondsSinceEpoch}-$i',
            name: 'Cloudflare WARP ${i + 1}',
            serverAddress: config.serverAddress,
            port: config.port,
            privateKey: config.privateKey,
            publicKey: config.publicKey,
            presharedKey: config.presharedKey,
            allowedIPs: config.allowedIPs,
            dnsServers: config.dnsServers,
            mtu: config.mtu,
            endpoint: config.endpoint,
            createdAt: DateTime.now(),
          );
          configs.add(updatedConfig);
          
          // Small delay between generations
          await Future.delayed(Duration(seconds: 1));
        }
      } catch (e) {
        _logger.w('Failed to generate WARP config ${i + 1}', error: e);
      }
    }
    
    return configs;
  }
  
  /// ProtonVPN Free server configurations
  /// आपको ProtonVPN free account बनाना होगा और configs download करने होंगे
  List<VpnConfig> _getProtonVpnFreeConfigs() {
    return [
      VpnConfig(
        id: 'proton-free-us',
        name: 'ProtonVPN Free - USA',
        serverAddress: 'us-free-01.protonvpn.net',
        port: 51820,
        // NOTE: आपको ProtonVPN account से actual keys लेने होंगे
        // यह placeholder है - real production में actual keys होनी चाहिए
        privateKey: _generatePlaceholderKey('proton-us-private'),
        publicKey: _generatePlaceholderKey('proton-us-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['10.2.0.1'], // ProtonVPN DNS
        createdAt: DateTime.now(),
        metadata: {'provider': 'proton', 'datacap': 'unlimited', 'speed': 'medium'},
      ),
      VpnConfig(
        id: 'proton-free-jp',
        name: 'ProtonVPN Free - Japan', 
        serverAddress: 'jp-free-01.protonvpn.net',
        port: 51820,
        privateKey: _generatePlaceholderKey('proton-jp-private'),
        publicKey: _generatePlaceholderKey('proton-jp-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['10.2.0.1'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'proton', 'datacap': 'unlimited', 'speed': 'medium'},
      ),
      VpnConfig(
        id: 'proton-free-nl',
        name: 'ProtonVPN Free - Netherlands',
        serverAddress: 'nl-free-01.protonvpn.net',
        port: 51820,
        privateKey: _generatePlaceholderKey('proton-nl-private'),
        publicKey: _generatePlaceholderKey('proton-nl-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['10.2.0.1'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'proton', 'datacap': 'unlimited', 'speed': 'medium'},
      ),
    ];
  }
  
  /// Windscribe Free server configurations  
  /// 10GB/month free data
  List<VpnConfig> _getWindscribeFreeConfigs() {
    return [
      VpnConfig(
        id: 'windscribe-free-us',
        name: 'Windscribe Free - USA',
        serverAddress: 'us-central-wg.windscribe.com',
        port: 53,
        privateKey: _generatePlaceholderKey('windscribe-us-private'),
        publicKey: _generatePlaceholderKey('windscribe-us-public'),  
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['10.255.255.1'], // Windscribe DNS
        createdAt: DateTime.now(),
        metadata: {'provider': 'windscribe', 'datacap': '10GB', 'speed': 'medium'},
      ),
      VpnConfig(
        id: 'windscribe-free-ca',
        name: 'Windscribe Free - Canada',
        serverAddress: 'ca-wg.windscribe.com',
        port: 53,
        privateKey: _generatePlaceholderKey('windscribe-ca-private'),
        publicKey: _generatePlaceholderKey('windscribe-ca-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['10.255.255.1'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'windscribe', 'datacap': '10GB', 'speed': 'medium'},
      ),
    ];
  }

  /// Hide.me Free VPN configurations
  /// 10GB/month free data
  List<VpnConfig> _getHideMeFreeConfigs() {
    return [
      VpnConfig(
        id: 'hideme-free-nl',
        name: 'Hide.me Free - Netherlands',
        serverAddress: 'nl.hideservers.net',
        port: 51820,
        privateKey: _generatePlaceholderKey('hideme-nl-private'),
        publicKey: _generatePlaceholderKey('hideme-nl-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['1.1.1.1', '8.8.8.8'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'hideme', 'datacap': '10GB', 'speed': 'medium'},
      ),
      VpnConfig(
        id: 'hideme-free-sg',
        name: 'Hide.me Free - Singapore',
        serverAddress: 'sg.hideservers.net',
        port: 51820,
        privateKey: _generatePlaceholderKey('hideme-sg-private'),
        publicKey: _generatePlaceholderKey('hideme-sg-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['1.1.1.1', '8.8.8.8'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'hideme', 'datacap': '10GB', 'speed': 'medium'},
      ),
    ];
  }

  /// TunnelBear Free VPN configurations
  /// 500MB/month free data
  List<VpnConfig> _getTunnelBearFreeConfigs() {
    return [
      VpnConfig(
        id: 'tunnelbear-free-ca',
        name: 'TunnelBear Free - Canada',
        serverAddress: 'ca.tunnelbear.com',
        port: 51820,
        privateKey: _generatePlaceholderKey('tunnelbear-ca-private'),
        publicKey: _generatePlaceholderKey('tunnelbear-ca-public'),
        allowedIPs: ['0.0.0.0/0'],
        dnsServers: ['1.1.1.1', '8.8.8.8'],
        createdAt: DateTime.now(),
        metadata: {'provider': 'tunnelbear', 'datacap': '500MB', 'speed': 'low'},
      ),
    ];
  }

  /// Outline VPN Free servers (Community provided)
  /// ये community द्वारा provide किए गए free outline servers हैं
  Future<List<VpnConfig>> _getOutlineFreeConfigs() async {
    final configs = <VpnConfig>[];
    
    try {
      // यहाँ आप outline free servers की list fetch कर सकते हैं
      // GitHub/Reddit से community shared outline keys मिल सकती हैं
      
      // Sample outline configs (community provided)
      final sampleConfigs = [
        {
          'id': 'outline-free-1',
          'name': 'Community Outline - US',
          'server': 'outline-server1.example.com',
          'port': 443,
          'method': 'chacha20-ietf-poly1305',
          'password': 'sample-outline-key',
        },
        {
          'id': 'outline-free-2', 
          'name': 'Community Outline - EU',
          'server': 'outline-server2.example.com',
          'port': 8080,
          'method': 'chacha20-ietf-poly1305',
          'password': 'sample-outline-key-2',
        },
      ];

      for (final config in sampleConfigs) {
        final vpnConfig = VpnConfig(
          id: config['id'] as String,
          name: config['name'] as String,
          serverAddress: config['server'] as String,
          port: config['port'] as int,
          privateKey: _generatePlaceholderKey('${config['id']}-private'),
          publicKey: _generatePlaceholderKey('${config['id']}-public'),
          allowedIPs: ['0.0.0.0/0'],
          dnsServers: ['1.1.1.1', '8.8.8.8'],
          createdAt: DateTime.now(),
          metadata: {
            'provider': 'outline',
            'method': config['method'],
            'datacap': 'varies',
            'speed': 'varies',
          },
        );
        configs.add(vpnConfig);
      }
      
    } catch (e, stack) {
      _logger.w('Failed to fetch outline configs', error: e, stackTrace: stack);
    }
    
    return configs;
  }

  /// Generate placeholder keys for development/testing
  /// Production में actual keys होनी चाहिए
  String _generatePlaceholderKey(String seed) {
    final random = Random(seed.hashCode);
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    return String.fromCharCodes(Iterable.generate(
        44, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
  
  /// Generate test configuration for development
  VpnConfig createTestConfig() {
    return VpnConfig(
      id: 'test-server-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Test Server (Development Only)',
      serverAddress: '127.0.0.1', // Local testing
      port: 51820,
      privateKey: 'DEVELOPMENT_PRIVATE_KEY_FOR_TESTING_ONLY',
      publicKey: 'DEVELOPMENT_PUBLIC_KEY_FOR_TESTING_ONLY',
      allowedIPs: ['0.0.0.0/0'],
      dnsServers: ['8.8.8.8', '8.8.4.4'],
      createdAt: DateTime.now(),
    );
  }
}