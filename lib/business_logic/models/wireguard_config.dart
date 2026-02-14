import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// part 'wireguard_config.g.dart';

/// WireGuard configuration model
@JsonSerializable()
class WireGuardConfig {
  final String name;
  final String privateKey;
  final String publicKey;
  final String? presharedKey;
  final List<String> addresses;
  final List<String> dns;
  final int? mtu;
  final String endpoint;
  final List<String> allowedIPs;
  final int? persistentKeepalive;
  final DateTime? createdAt;
  final DateTime? lastConnected;
  final bool isActive;
  final String? configHash;
  final String? interfaceName;

  const WireGuardConfig({
    required this.name,
    required this.privateKey,
    required this.publicKey,
    this.presharedKey,
    required this.addresses,
    required this.dns,
    this.mtu = 1420,
    required this.endpoint,
    required this.allowedIPs,
    this.persistentKeepalive = 25,
    this.createdAt,
    this.lastConnected,
    this.isActive = false,
    this.configHash,
    this.interfaceName,
  });

  /// Validate configuration
  bool validateConfig() {
    if (name.isEmpty) return false;
    if (privateKey.isEmpty) return false;
    if (publicKey.isEmpty) return false;
    if (endpoint.isEmpty) return false;
    if (addresses.isEmpty) return false;
    if (allowedIPs.isEmpty) return false;
    
    // Validate endpoint format (host:port)
    final endpointPattern = RegExp(r'^[a-zA-Z0-9.-]+:\d+$');
    if (!endpointPattern.hasMatch(endpoint)) return false;
    
    // Validate MTU
    if (mtu != null && (mtu! < 1280 || mtu! > 1420)) return false;
    
    return true;
  }

  /// Generate configuration hash for integrity checking
  String generateConfigHash() {
    final configString = toWireGuardConfig();
    final bytes = utf8.encode(configString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get preSharedKey (compatibility alias)
  String? get preSharedKey => presharedKey;

  /// Create from JSON
  factory WireGuardConfig.fromJson(Map<String, dynamic> json) {
    return WireGuardConfig(
      name: json['name'] ?? '',
      privateKey: json['privateKey'] ?? '',
      publicKey: json['publicKey'] ?? '',
      presharedKey: json['presharedKey'],
      addresses: List<String>.from(json['addresses'] ?? []),
      dns: List<String>.from(json['dns'] ?? []),
      mtu: json['mtu'] ?? 1420,
      endpoint: json['endpoint'] ?? '',
      allowedIPs: List<String>.from(json['allowedIPs'] ?? []),
      persistentKeepalive: json['persistentKeepalive'] ?? 25,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastConnected: json['lastConnected'] != null ? DateTime.parse(json['lastConnected']) : null,
      isActive: json['isActive'] ?? false,
      configHash: json['configHash'],
      interfaceName: json['interfaceName'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'privateKey': privateKey,
      'publicKey': publicKey,
      'presharedKey': presharedKey,
      'addresses': addresses,
      'dns': dns,
      'mtu': mtu,
      'endpoint': endpoint,
      'allowedIPs': allowedIPs,
      'persistentKeepalive': persistentKeepalive,
      'createdAt': createdAt?.toIso8601String(),
      'lastConnected': lastConnected?.toIso8601String(),
      'isActive': isActive,
      'configHash': configHash,
      'interfaceName': interfaceName,
    };
  }

  /// Create a copy with modified values
  WireGuardConfig copyWith({
    String? name,
    String? privateKey,
    String? publicKey,
    String? presharedKey,
    List<String>? addresses,
    List<String>? dns,
    int? mtu,
    String? endpoint,
    List<String>? allowedIPs,
    int? persistentKeepalive,
    DateTime? createdAt,
    DateTime? lastConnected,
    bool? isActive,
    String? configHash,
    String? interfaceName,
  }) {
    return WireGuardConfig(
      name: name ?? this.name,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      presharedKey: presharedKey ?? this.presharedKey,
      addresses: addresses ?? this.addresses,
      dns: dns ?? this.dns,
      mtu: mtu ?? this.mtu,
      endpoint: endpoint ?? this.endpoint,
      allowedIPs: allowedIPs ?? this.allowedIPs,
      persistentKeepalive: persistentKeepalive ?? this.persistentKeepalive,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
      isActive: isActive ?? this.isActive,
      configHash: configHash ?? this.configHash,
      interfaceName: interfaceName ?? this.interfaceName ?? 'wg0',
    );
  }

  /// Generate WireGuard configuration file format
  String toWireGuardConfig() {
    final buffer = StringBuffer();
    
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = ${addresses.join(', ')}');
    
    if (dns.isNotEmpty) {
      buffer.writeln('DNS = ${dns.join(', ')}');
    }
    
    if (mtu != null) {
      buffer.writeln('MTU = $mtu');
    }
    
    buffer.writeln();
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = $publicKey');
    
    if (presharedKey != null) {
      buffer.writeln('PresharedKey = $presharedKey');
    }
    
    buffer.writeln('Endpoint = $endpoint');
    buffer.writeln('AllowedIPs = ${allowedIPs.join(', ')}');
    
    if (persistentKeepalive != null) {
      buffer.writeln('PersistentKeepalive = $persistentKeepalive');
    }
    
    return buffer.toString();
  }

  /// Parse WireGuard configuration from string
  static WireGuardConfig fromWireGuardConfig(String config, String name) {
    final lines = config.split('\n');
    
    String? privateKey;
    List<String> addresses = [];
    List<String> dns = [];
    int? mtu;
    String? publicKey;
    String? presharedKey;
    String? endpoint;
    List<String> allowedIPs = [];
    int? persistentKeepalive;
    
    bool inInterface = false;
    bool inPeer = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine == '[Interface]') {
        inInterface = true;
        inPeer = false;
        continue;
      }
      
      if (trimmedLine == '[Peer]') {
        inInterface = false;
        inPeer = true;
        continue;
      }
      
      if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
        continue;
      }
      
      final parts = trimmedLine.split('=').map((e) => e.trim()).toList();
      if (parts.length != 2) continue;
      
      final key = parts[0];
      final value = parts[1];
      
      if (inInterface) {
        switch (key) {
          case 'PrivateKey':
            privateKey = value;
            break;
          case 'Address':
            addresses = value.split(',').map((e) => e.trim()).toList();
            break;
          case 'DNS':
            dns = value.split(',').map((e) => e.trim()).toList();
            break;
          case 'MTU':
            mtu = int.tryParse(value);
            break;
        }
      }
      
      if (inPeer) {
        switch (key) {
          case 'PublicKey':
            publicKey = value;
            break;
          case 'PresharedKey':
            presharedKey = value;
            break;
          case 'Endpoint':
            endpoint = value;
            break;
          case 'AllowedIPs':
            allowedIPs = value.split(',').map((e) => e.trim()).toList();
            break;
          case 'PersistentKeepalive':
            persistentKeepalive = int.tryParse(value);
            break;
        }
      }
    }
    
    if (privateKey == null || publicKey == null || endpoint == null) {
      throw ArgumentError('Invalid WireGuard configuration: missing required fields');
    }
    
    return WireGuardConfig(
      name: name,
      privateKey: privateKey,
      publicKey: publicKey,
      presharedKey: presharedKey,
      addresses: addresses,
      dns: dns,
      mtu: mtu,
      endpoint: endpoint,
      allowedIPs: allowedIPs,
      persistentKeepalive: persistentKeepalive,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'WireGuardConfig(name: $name, endpoint: $endpoint, addresses: $addresses)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is WireGuardConfig &&
        other.name == name &&
        other.privateKey == privateKey &&
        other.publicKey == publicKey &&
        other.endpoint == endpoint;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        privateKey.hashCode ^
        publicKey.hashCode ^
        endpoint.hashCode;
  }
}