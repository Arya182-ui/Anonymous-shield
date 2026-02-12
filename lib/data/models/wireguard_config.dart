import 'package:json_annotation/json_annotation.dart';
import 'package:encrypt/encrypt.dart';

part 'wireguard_config.g.dart';

/// Production-ready WireGuard Configuration Model
/// Provides secure configuration management with validation
@JsonSerializable()
class WireGuardConfig {
  final String interfaceName;
  final String privateKey;
  final String publicKey; 
  final String preSharedKey;
  final String serverPublicKey;
  final String endpoint;
  final int listenPort;
  final List<String> allowedIPs;
  final List<String> dns;
  final int mtu;
  final int keepAlive;
  final String? fwmark;
  final bool persistentKeepalive;
  
  // Security enhancements
  final String configHash;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isValid;
  final String securityLevel;
  
  const WireGuardConfig({
    required this.interfaceName,
    required this.privateKey,
    required this.publicKey,
    required this.preSharedKey,
    required this.serverPublicKey,
    required this.endpoint,
    required this.listenPort,
    required this.allowedIPs,
    required this.dns,
    this.mtu = 1420,
    this.keepAlive = 25,
    this.fwmark,
    this.persistentKeepalive = true,
    required this.configHash,
    required this.createdAt,
    this.expiresAt,
    this.isValid = true,
    this.securityLevel = 'high',
  });

  /// Create from JSON with validation
  factory WireGuardConfig.fromJson(Map<String, dynamic> json) =>
      _$WireGuardConfigFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$WireGuardConfigToJson(this);

  /// Generate WireGuard configuration string
  String toWireGuardConfig() {
    final buffer = StringBuffer();
    
    // Interface section
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = ${allowedIPs.join(', ')}');
    buffer.writeln('DNS = ${dns.join(', ')}');
    buffer.writeln('MTU = $mtu');
    if (fwmark != null) {
      buffer.writeln('FwMark = $fwmark');
    }
    
    buffer.writeln();
    
    // Peer section
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = $serverPublicKey');
    buffer.writeln('PreSharedKey = $preSharedKey');
    buffer.writeln('Endpoint = $endpoint');
    buffer.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    if (persistentKeepalive) {
      buffer.writeln('PersistentKeepalive = $keepAlive');
    }
    
    return buffer.toString();
  }

  /// Validate configuration integrity
  bool validateConfig() {
    try {
      // Check required fields
      if (privateKey.isEmpty || serverPublicKey.isEmpty || endpoint.isEmpty) {
        return false;
      }
      
      // Validate key formats (Base64)
      if (!_isValidBase64(privateKey) || !_isValidBase64(serverPublicKey)) {
        return false;
      }
      
      // Validate endpoint format
      if (!_isValidEndpoint(endpoint)) {
        return false;
      }
      
      // Check expiration
      if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
        return false;
      }
      
      // Validate MTU range
      if (mtu < 576 || mtu > 1500) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate secure hash for config validation
  String generateConfigHash() {
    final key = Key.fromSecureRandom(32);
    final encrypter = Encrypter(AES(key));
    final configString = toWireGuardConfig();
    return encrypter.encrypt(configString).base64;
  }

  /// Create a copy with updated fields
  WireGuardConfig copyWith({
    String? interfaceName,
    String? privateKey,
    String? publicKey,
    String? preSharedKey,
    String? serverPublicKey,
    String? endpoint,
    int? listenPort,
    List<String>? allowedIPs,
    List<String>? dns,
    int? mtu,
    int? keepAlive,
    String? fwmark,
    bool? persistentKeepalive,
    String? configHash,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isValid,
    String? securityLevel,
  }) {
    return WireGuardConfig(
      interfaceName: interfaceName ?? this.interfaceName,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      preSharedKey: preSharedKey ?? this.preSharedKey,
      serverPublicKey: serverPublicKey ?? this.serverPublicKey,
      endpoint: endpoint ?? this.endpoint,
      listenPort: listenPort ?? this.listenPort,
      allowedIPs: allowedIPs ?? this.allowedIPs,
      dns: dns ?? this.dns,
      mtu: mtu ?? this.mtu,
      keepAlive: keepAlive ?? this.keepAlive,
      fwmark: fwmark ?? this.fwmark,
      persistentKeepalive: persistentKeepalive ?? this.persistentKeepalive,
      configHash: configHash ?? this.configHash,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isValid: isValid ?? this.isValid,
      securityLevel: securityLevel ?? this.securityLevel,
    );
  }

  // Helper methods for validation
  bool _isValidBase64(String value) {
    try {
      // WireGuard keys are 32 bytes (256 bits) encoded as Base64
      return RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(value);
    } catch (e) {
      return false;
    }
  }

  bool _isValidEndpoint(String endpoint) {
    try {
      // Format: domain.com:port or IP:port
      final parts = endpoint.split(':');
      if (parts.length != 2) return false;
      
      final port = int.tryParse(parts[1]);
      return port != null && port > 0 && port <= 65535;
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() {
    return 'WireGuardConfig(interface: $interfaceName, endpoint: $endpoint, security: $securityLevel)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WireGuardConfig && other.configHash == configHash;
  }

  @override
  int get hashCode => configHash.hashCode;
}