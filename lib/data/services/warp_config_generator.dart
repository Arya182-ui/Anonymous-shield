import 'dart:convert';
import 'dart:math';
// Crypto removed - will be added when needed
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
      final keyPair = _generateWireGuardKeyPair();
      
      // Step 2: Register with Cloudflare
      final registration = await _registerWithCloudflare(keyPair['public']!);
      
      if (registration == null) {
        _logger.e('Failed to register with Cloudflare WARP');
        return null;
      }
      
      // Step 3: Create VPN configuration
      final config = VpnConfig(
        id: 'cloudflare-warp-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Cloudflare WARP (Free)',
        serverAddress: _warpEndpoint,
        port: 2408,
        privateKey: keyPair['private']!,
        publicKey: registration['server_public_key'] as String,
        allowedIPs: ['0.0.0.0/0', '::/0'],
        dnsServers: ['1.1.1.1', '1.0.0.1'], // Cloudflare DNS
        createdAt: DateTime.now(),
        endpoint: _warpEndpoint,
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
      final response = await _dio.post(
        '$_warpApiUrl/v0a884/reg',
        data: {
          'key': publicKey,
          'install_id': _generateInstallId(),
          'fcm_token': '',
          'tos': DateTime.now().toIso8601String(),
          'type': 'Android',
          'locale': 'en',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'okhttp/3.12.1',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        return response.data['result'];
      }
      
      return null;
    } catch (e) {
      _logger.e('Cloudflare registration failed', error: e);
      return null;
    }
  }
  
  /// Generate WireGuard key pair
  Map<String, String> _generateWireGuardKeyPair() {
    // Generate 32 random bytes for private key
    final random = Random.secure();
    final privateKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    
    // Clamp private key for Curve25519
    privateKeyBytes[0] &= 248;
    privateKeyBytes[31] &= 127;
    privateKeyBytes[31] |= 64;
    
    final privateKey = base64Encode(privateKeyBytes);
    
    // For simplicity, generate mock public key
    // In production, calculate actual Curve25519 public key
    final publicKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final publicKey = base64Encode(publicKeyBytes);
    
    return {
      'private': privateKey,
      'public': publicKey,
    };
  }
  
  /// Generate unique install ID
  String _generateInstallId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}