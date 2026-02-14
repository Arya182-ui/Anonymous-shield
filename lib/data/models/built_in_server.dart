import 'dart:math';
import 'package:json_annotation/json_annotation.dart';
import 'vpn_config.dart';

part 'built_in_server.g.dart';

@JsonSerializable()
class BuiltInServer {
  final String id;
  final String name;
  final String country;
  final String countryCode;
  final String city;
  final String serverAddress;
  final int port;
  final double latitude;
  final double longitude;
  final bool isFree;
  final int maxSpeedMbps;
  final String flagEmoji;
  final bool isRecommended;
  final int loadPercentage;
  
  const BuiltInServer({
    required this.id,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.serverAddress,
    required this.port,
    required this.latitude,
    required this.longitude,
    this.isFree = true,
    this.maxSpeedMbps = 100,
    required this.flagEmoji,
    this.isRecommended = false,
    this.loadPercentage = 50,
  });

  factory BuiltInServer.fromJson(Map<String, dynamic> json) => _$BuiltInServerFromJson(json);
  Map<String, dynamic> toJson() => _$BuiltInServerToJson(this);

  // Compatibility getter for method channels
  String get host => serverAddress;

  VpnConfig toVpnConfig() {
    // Note: Built-in servers should have real pre-configured keys
    // In production, these would be actual WireGuard key pairs for your servers
    final privateKey = _getConfiguredPrivateKey();
    final publicKey = _getConfiguredPublicKey();
    
    // Validate that we have real keys before creating config
    if (privateKey.startsWith('REPLACE_WITH') || publicKey.startsWith('REPLACE_WITH')) {
      throw StateError(
        'Server "$name" has placeholder WireGuard keys. '
        'Configure real keys in built_in_servers.json or use auto-generated WARP configs.'
      );
    }
    
    return VpnConfig(
      id: id,
      name: name,
      serverAddress: serverAddress,
      port: port,
      privateKey: privateKey,
      publicKey: publicKey,
      allowedIPs: ['0.0.0.0/0'],
      dnsServers: ['1.1.1.1', '1.0.0.1'],
      createdAt: DateTime.now(),
    );
  }
  
  String _getConfiguredPrivateKey() {
    // PRODUCTION TODO: Replace with actual WireGuard private keys
    // These should be loaded from a secure configuration file or environment
    // Example: Load from encrypted assets or secure remote configuration
    
    // For now, return a warning placeholder
    return 'REPLACE_WITH_REAL_PRIVATE_KEY_FOR_SERVER_$id';
  }
  
  String _getConfiguredPublicKey() {
    // PRODUCTION TODO: Replace with actual WireGuard public keys  
    // These should correspond to the private keys above
    
    // For now, return a warning placeholder
    return 'REPLACE_WITH_REAL_PUBLIC_KEY_FOR_SERVER_$id';
  }
  
  double distanceFrom(double userLat, double userLon) {
    // Haversine formula for accurate distance calculation
    const double earthRadius = 6371; // km
    double dLat = (latitude - userLat) * (pi / 180);
    double dLon = (longitude - userLon) * (pi / 180);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180) * cos(latitude * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}