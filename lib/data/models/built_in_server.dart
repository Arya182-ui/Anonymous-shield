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

  VpnConfig toVpnConfig() {
    // Note: Built-in servers should have real pre-configured keys
    // In production, these would be actual WireGuard key pairs for your servers
    return VpnConfig(
      id: id,
      name: name,
      serverAddress: serverAddress,
      port: port,
      // WARNING: These are placeholder keys - replace with real keys in production
      privateKey: _getConfiguredPrivateKey(),
      publicKey: _getConfiguredPublicKey(),
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
    // Simple distance calculation
    const double earthRadius = 6371; // km
    double dLat = (latitude - userLat) * (3.14159 / 180);
    double dLon = (longitude - userLon) * (3.14159 / 180);
    
    double a = (dLat / 2) * (dLat / 2) +
        (userLat * 3.14159 / 180) * (latitude * 3.14159 / 180) *
        (dLon / 2) * (dLon / 2);
    
    double c = 2 * earthRadius * (a < 1 ? (a / 2) : 1);
    return earthRadius * c;
  }
}