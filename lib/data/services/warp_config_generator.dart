import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/vpn_config.dart';

/// Cloudflare WARP configuration generator
/// Free, unlimited, and privacy-focused
class WarpConfigGenerator {
  static const String _warpApiUrl = 'https://api.cloudflareclient.com';
  static const String _warpEndpoint = 'engage.cloudflareclient.com:2408';
  
  final Dio _dio = Dio();
  final Logger _logger = Logger();
  
  /// Generate free WARP configuration
  Future<VpnConfig?> generateWarpConfig() async {
    try {
      _logger.i('Generating Cloudflare WARP configuration...');
      
      // Step 1: Generate key pair
      final keyPair = await _generateWireGuardKeyPair();
      
      // Step 2: Register with Cloudflare
      final registration = await _registerWithCloudflare(keyPair['public']!);
      
      if (registration == null) {
        _logger.e('Failed to register with Cloudflare WARP');
        return null;
      }
      
      // Step 3: Create VPN configuration
      final serverPubKey = registration['server_public_key'] as String? 
          ?? registration['public_key'] as String? 
          ?? '';
      
      if (serverPubKey.isEmpty) {
        _logger.e('No server public key in WARP registration response');
        return null;
      }
      
      final rawEndpoint = registration['endpoint'] as String? ?? _warpEndpoint;
      
      // Parse host and port separately to avoid duplicate port in config
      String host;
      int port;
      if (rawEndpoint.contains(':')) {
        final parts = rawEndpoint.split(':');
        host = parts[0];
        port = int.tryParse(parts.last) ?? 2408;
      } else {
        host = rawEndpoint;
        port = 2408;
      }
      
      final config = VpnConfig(
        id: 'cloudflare-warp-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Cloudflare WARP (Free)',
        serverAddress: host,
        port: port,
        privateKey: keyPair['private']!,
        publicKey: serverPubKey,
        allowedIPs: ['0.0.0.0/0', '::/0'],
        dnsServers: ['1.1.1.1', '1.0.0.1'], // Cloudflare DNS
        createdAt: DateTime.now(),
        endpoint: '$host:$port',
      );
      
      _logger.i('WARP configuration generated successfully');
      return config;
      
    } catch (e, stack) {
      _logger.e('Failed to generate WARP config', error: e, stackTrace: stack);
      return null;
    }
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
              'endpoint': peers[0]['endpoint']?['host'] ?? _warpEndpoint,
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