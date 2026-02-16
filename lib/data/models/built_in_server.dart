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

  // ------ Real VPS WireGuard fields (null for WARP-only servers) ------
  /// Server's WireGuard public key (set for real VPS servers)
  final String? publicKey;

  /// Pre-generated client private key for this server
  final String? clientPrivateKey;

  /// Client tunnel address (e.g. "10.0.0.2/32")
  final String? clientAddress;

  /// Optional preshared key for extra security
  final String? presharedKey;

  /// Custom DNS servers for this VPS (defaults to 1.1.1.1 if null)
  final List<String>? dns;

  /// Provider tag — "oracle", "hetzner", "vultr", "warp", etc.
  final String? provider;
  
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
    // VPS fields
    this.publicKey,
    this.clientPrivateKey,
    this.clientAddress,
    this.presharedKey,
    this.dns,
    this.provider,
  });

  factory BuiltInServer.fromJson(Map<String, dynamic> json) => _$BuiltInServerFromJson(json);
  Map<String, dynamic> toJson() => _$BuiltInServerToJson(this);

  // Compatibility getter for method channels
  String get host => serverAddress;

  /// True if this server has full WireGuard keys and can connect directly
  /// without needing WARP API registration.
  bool get isRealVps =>
      publicKey != null &&
      publicKey!.isNotEmpty &&
      clientPrivateKey != null &&
      clientPrivateKey!.isNotEmpty &&
      clientAddress != null &&
      clientAddress!.isNotEmpty;

  /// Check if this server needs WARP auto-generation for keys
  bool get needsWarpGeneration => !isRealVps;

  /// Creates a VpnConfig from this server.
  /// If isRealVps → builds complete config directly (instant, no API call).
  /// If WARP → returns a template needing WARP key generation.
  VpnConfig toVpnConfig() {
    if (isRealVps) {
      // Real VPS — complete config, ready to connect
      return VpnConfig(
        id: id,
        name: name,
        serverAddress: serverAddress,
        port: port,
        privateKey: clientPrivateKey!,
        publicKey: publicKey!,
        presharedKey: presharedKey,
        allowedIPs: const ['0.0.0.0/0', '::/0'],
        dnsServers: dns ?? const ['1.1.1.1', '1.0.0.1'],
        endpoint: '$serverAddress:$port',
        clientIpv4: clientAddress,
        createdAt: DateTime.now(),
        killSwitchEnabled: true,
        metadata: {
          'server_id': id,
          'country': country,
          'city': city,
          'provider': provider ?? 'vps',
          'is_real_vps': true,
        },
      );
    }

    // WARP template — keys will be filled by WarpConfigGenerator
    return VpnConfig(
      id: id,
      name: name,
      serverAddress: serverAddress,
      port: port,
      privateKey: 'PENDING_WARP_GENERATION',
      publicKey: 'PENDING_WARP_GENERATION',
      allowedIPs: const ['0.0.0.0/0', '::/0'],
      dnsServers: const ['1.1.1.1', '1.0.0.1'],
      createdAt: DateTime.now(),
      metadata: {
        'server_id': id,
        'country': country,
        'city': city,
        'requires_warp_generation': true,
      },
    );
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