import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/vpn_config.dart';

/// Cloudflare WARP configuration generator
/// Free, unlimited, and privacy-focused
/// Uses diverse endpoint IPs to maximize IP/location rotation variety
class WarpConfigGenerator {
  static const String _warpApiUrl = 'https://api.cloudflareclient.com';
  static const String _defaultEndpoint = 'engage.cloudflareclient.com:2408';
  
  /// Pool of known Cloudflare WARP endpoint IPs across different IP ranges.
  /// Different IPs may route through different Cloudflare data centers,
  /// potentially providing different exit IPs and locations on each rotation.
  /// This is the best-effort approach for location diversity on free WARP.
  static const List<String> _endpointPool = [
    // Range: 162.159.192.0/24
    '162.159.192.1:2408',
    '162.159.192.6:2408',
    '162.159.192.12:2408',
    '162.159.192.25:2408',
    '162.159.192.50:2408',
    '162.159.192.75:2408',
    '162.159.192.100:2408',
    '162.159.192.150:2408',
    '162.159.192.200:2408',
    '162.159.192.227:2408',
    // Range: 162.159.193.0/24
    '162.159.193.1:2408',
    '162.159.193.6:2408',
    '162.159.193.12:2408',
    '162.159.193.25:2408',
    '162.159.193.50:2408',
    '162.159.193.75:2408',
    '162.159.193.100:2408',
    '162.159.193.150:2408',
    '162.159.193.200:2408',
    '162.159.193.227:2408',
    // Range: 162.159.195.0/24
    '162.159.195.1:2408',
    '162.159.195.50:2408',
    '162.159.195.100:2408',
    '162.159.195.200:2408',
    // Range: 188.114.96-99.x
    '188.114.96.1:2408',
    '188.114.96.50:2408',
    '188.114.96.100:2408',
    '188.114.97.1:2408',
    '188.114.97.50:2408',
    '188.114.97.100:2408',
    '188.114.98.1:2408',
    '188.114.98.50:2408',
    '188.114.99.1:2408',
    '188.114.99.50:2408',
  ];

  /// Track last used endpoint to avoid repeats
  String? _lastUsedEndpoint;
  
  /// Cached registration data (server public key + our private key)
  /// Reuse across rotations — no need to re-register with Cloudflare each time.
  /// WARP uses the same server public key globally; our keypair stays valid.
  String? _cachedServerPubKey;
  String? _cachedPrivateKey;
  
  final Dio _dio = Dio();
  final Logger _logger = Logger();
  final Random _random = Random.secure();

  /// Get a random endpoint different from the last used one
  String getRandomEndpoint() {
    if (_endpointPool.length <= 1) return _endpointPool.first;
    
    String endpoint;
    do {
      endpoint = _endpointPool[_random.nextInt(_endpointPool.length)];
    } while (endpoint == _lastUsedEndpoint);
    
    _lastUsedEndpoint = endpoint;
    return endpoint;
  }
  
  /// Generate free WARP configuration with a random endpoint for IP diversity
  /// Each call generates new keys AND uses a different Cloudflare endpoint,
  /// maximizing the chance of getting a different exit IP/location.
  Future<VpnConfig?> generateWarpConfig({String? overrideEndpoint}) async {
    try {
      // Pick a random endpoint for this connection
      final chosenEndpoint = overrideEndpoint ?? getRandomEndpoint();
      _logger.i('Generating WARP config with endpoint: $chosenEndpoint');
      
      String serverPubKey;
      String privateKey;
      
      // Reuse cached registration if available (avoids slow API call)
      if (_cachedServerPubKey != null && _cachedPrivateKey != null) {
        serverPubKey = _cachedServerPubKey!;
        privateKey = _cachedPrivateKey!;
        _logger.i('Reusing cached WARP registration (instant)');
      } else {
        // Step 1: Generate key pair
        final keyPair = await _generateWireGuardKeyPair();
        
        // Step 2: Register with Cloudflare
        final registration = await _registerWithCloudflare(keyPair['public']!);
        
        if (registration == null) {
          _logger.e('Failed to register with Cloudflare WARP');
          return null;
        }
        
        // Step 3: Extract server public key
        serverPubKey = registration['server_public_key'] as String? 
            ?? registration['public_key'] as String? 
            ?? '';
        
        if (serverPubKey.isEmpty) {
          _logger.e('No server public key in WARP registration response');
          return null;
        }
        
        privateKey = keyPair['private']!;
        
        // Cache for future rotations
        _cachedServerPubKey = serverPubKey;
        _cachedPrivateKey = privateKey;
        _logger.i('Cached WARP registration for future rotations');
      }
      
      // Use our chosen endpoint instead of the API-returned one.
      // WARP uses the same PKI across all DCs, so any registered key
      // works with any Cloudflare WARP endpoint IP.
      String host;
      int port;
      if (chosenEndpoint.contains(':')) {
        final parts = chosenEndpoint.split(':');
        host = parts[0];
        port = int.tryParse(parts.last) ?? 2408;
      } else {
        host = chosenEndpoint;
        port = 2408;
      }
      
      final config = VpnConfig(
        id: 'cloudflare-warp-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Cloudflare WARP (Free)',
        serverAddress: host,
        port: port,
        privateKey: privateKey,
        publicKey: serverPubKey,
        allowedIPs: ['0.0.0.0/0', '::/0'],
        dnsServers: ['1.1.1.1', '1.0.0.1'], // Cloudflare DNS
        createdAt: DateTime.now(),
        endpoint: '$host:$port',
      );
      
      _logger.i('WARP config generated: endpoint=$host:$port');
      return config;
      
    } catch (e, stack) {
      _logger.e('Failed to generate WARP config', error: e, stackTrace: stack);
      return null;
    }
  }
  
  /// Generate a rotated config INSTANTLY by reusing cached keys with a new endpoint.
  /// No API call needed — just swaps the Cloudflare endpoint IP.
  /// Returns null if no cached registration exists (call generateWarpConfig first).
  VpnConfig? generateRotatedConfig() {
    if (_cachedServerPubKey == null || _cachedPrivateKey == null) {
      _logger.w('No cached WARP registration, cannot rotate instantly');
      return null;
    }
    
    final chosenEndpoint = getRandomEndpoint();
    _logger.i('Instant WARP rotation to endpoint: $chosenEndpoint');
    
    String host;
    int port;
    if (chosenEndpoint.contains(':')) {
      final parts = chosenEndpoint.split(':');
      host = parts[0];
      port = int.tryParse(parts.last) ?? 2408;
    } else {
      host = chosenEndpoint;
      port = 2408;
    }
    
    return VpnConfig(
      id: 'cloudflare-warp-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Cloudflare WARP (Free)',
      serverAddress: host,
      port: port,
      privateKey: _cachedPrivateKey!,
      publicKey: _cachedServerPubKey!,
      allowedIPs: ['0.0.0.0/0', '::/0'],
      dnsServers: ['1.1.1.1', '1.0.0.1'],
      createdAt: DateTime.now(),
      endpoint: '$host:$port',
    );
  }
  
  /// Clear cached registration (forces fresh registration on next call)
  void clearCache() {
    _cachedServerPubKey = null;
    _cachedPrivateKey = null;
    _logger.i('WARP registration cache cleared');
  }
  
  /// Register device with Cloudflare WARP API
  Future<Map<String, dynamic>?> _registerWithCloudflare(String publicKey) async {
    try {
      // Use the current Cloudflare WARP client API endpoint
      final response = await _dio.post(
        '$_warpApiUrl/v0a2169/reg',
        data: {
          'key': publicKey,
          'install_id': _generateInstallId(),
          'fcm_token': '',
          'tos': DateTime.now().toUtc().toIso8601String(),
          'model': 'Android',
          'type': 'Android',
          'locale': 'en_US',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'CF-Client-Version': 'a-6.11-2223',
            'User-Agent': 'okhttp/3.12.1',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('config')) {
          final config = data['config'];
          final peers = config?['peers'];
          if (peers is List && peers.isNotEmpty) {
            return {
              'server_public_key': peers[0]['public_key'],
              'endpoint': peers[0]['endpoint']?['host'] ?? _defaultEndpoint,
            };
          }
        }
        // Fallback: return data directly if structure is different
        if (data is Map<String, dynamic> && data.containsKey('result')) {
          return Map<String, dynamic>.from(data['result']);
        }
        return data is Map<String, dynamic> ? data : null;
      }
      
      _logger.w('WARP registration returned status: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('Cloudflare registration failed', error: e);
      return null;
    }
  }
  
  /// Generate WireGuard key pair using proper Curve25519
  Future<Map<String, String>> _generateWireGuardKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    
    // Extract raw private key bytes - copy to mutable Uint8List
    // (SensitiveBytes from cryptography package are unmodifiable)
    final immutableBytes = await keyPair.extractPrivateKeyBytes();
    final privateKeyBytes = Uint8List.fromList(immutableBytes);
    
    // Clamp for WireGuard X25519
    privateKeyBytes[0] &= 248;
    privateKeyBytes[31] &= 127;
    privateKeyBytes[31] |= 64;
    final privateKey = base64Encode(privateKeyBytes);
    
    // Extract public key bytes - also copy to mutable list
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyB64 = base64Encode(Uint8List.fromList(publicKey.bytes));
    
    return {
      'private': privateKey,
      'public': publicKeyB64,
    };
  }
  
  /// Generate unique install ID
  String _generateInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}