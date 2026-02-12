import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'proxy_config.g.dart';

enum ProxyType {
  @JsonValue('socks5')
  socks5,
  @JsonValue('shadowsocks')
  shadowsocks,
  @JsonValue('http')
  http,
  @JsonValue('https')
  https,
  @JsonValue('trojan')
  trojan,
  @JsonValue('v2ray')
  v2ray
}

enum ProxyRole {
  @JsonValue('entry')
  entry,   // First hop
  @JsonValue('middle')
  middle,  // Middle hops
  @JsonValue('exit')
  exit,    // Final hop
  @JsonValue('bridge')
  bridge,  // Bridge/obfuscation
}

@JsonSerializable()
class ProxyConfig {
  final String id;
  final String name;
  final ProxyType type;
  final ProxyRole? role; // Added for chain positioning
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String? method; // For Shadowsocks encryption method
  final String? plugin; // For Shadowsocks plugin
  final Map<String, dynamic>? pluginOptions;
  final String? country; // Added for geographic info
  final String? countryCode; // Added for geographic info
  final String? flagEmoji; // Added for UI display
  final bool isObfuscated; // Added for stealth capabilities
  final int priority; // Added for routing priority
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final Map<String, dynamic>? metadata;

  const ProxyConfig({
    required this.id,
    required this.name,
    required this.type,
    this.role,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.method,
    this.plugin,
    this.pluginOptions,
    this.country,
    this.countryCode,
    this.flagEmoji,
    this.isObfuscated = false,
    this.priority = 50,
    this.isEnabled = false,
    required this.createdAt,
    this.lastUsedAt,
    this.metadata,
  });

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => _$ProxyConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ProxyConfigToJson(this);

  // toMap method for method channels
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'role': role?.toString().split('.').last,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'method': method,
      'plugin': plugin,
      'pluginOptions': pluginOptions,
      'country': country,
      'countryCode': countryCode,
      'flagEmoji': flagEmoji,
      'isObfuscated': isObfuscated,
      'priority': priority,
      'isEnabled': isEnabled,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUsedAt': lastUsedAt?.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ProxyConfig.socks5({
    required String name,
    required String host,
    required int port,
    String? username,
    String? password,
  }) {
    const uuid = Uuid();
    return ProxyConfig(
      id: uuid.v4(),
      name: name,
      type: ProxyType.socks5,
      host: host,
      port: port,
      username: username,
      password: password,
      createdAt: DateTime.now(),
    );
  }

  factory ProxyConfig.shadowsocks({
    required String name,
    required String host,
    required int port,
    required String method,
    required String password,
    String? plugin,
    Map<String, dynamic>? pluginOptions,
  }) {
    const uuid = Uuid();
    return ProxyConfig(
      id: uuid.v4(),
      name: name,
      type: ProxyType.shadowsocks,
      host: host,
      port: port,
      password: password,
      method: method,
      plugin: plugin,
      pluginOptions: pluginOptions,
      createdAt: DateTime.now(),
    );
  }

  ProxyConfig copyWith({
    String? id,
    String? name,
    ProxyType? type,
    ProxyRole? role,
    String? host,
    int? port,
    String? username,
    String? password,
    String? method,
    String? plugin,
    Map<String, dynamic>? pluginOptions,
    String? country,
    String? countryCode,
    String? flagEmoji,
    bool? isObfuscated,
    int? priority,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ProxyConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      role: role ?? this.role,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      method: method ?? this.method,
      plugin: plugin ?? this.plugin,
      pluginOptions: pluginOptions ?? this.pluginOptions,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      isObfuscated: isObfuscated ?? this.isObfuscated,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Additional getters for anonymity system
  String get displayName => flagEmoji != null ? '$flagEmoji $name' : name;
  
  bool get isSecure => type == ProxyType.shadowsocks || 
                      type == ProxyType.trojan || 
                      type == ProxyType.v2ray;

  String get connectionString {
    switch (type) {
      case ProxyType.socks5:
        return 'socks5://${username != null ? '$username:$password@' : ''}$host:$port';
      case ProxyType.shadowsocks:
        return 'ss://${_encodeSSConfig()}';
      case ProxyType.http:
        return 'http://${username != null ? '$username:$password@' : ''}$host:$port';
      case ProxyType.https:
        return 'https://${username != null ? '$username:$password@' : ''}$host:$port';
      default:
        return '$host:$port';
    }
  }
  
  String _encodeSSConfig() {
    // Simplified Shadowsocks config encoding  
    final config = '$method:$password@$host:$port';
    // In real implementation, would use proper base64 encoding
    return config;
  }

  String getProxyUrl() {
    switch (type) {
      case ProxyType.socks5:
        if (username != null && password != null) {
          return 'socks5://$username:$password@$host:$port';
        }
        return 'socks5://$host:$port';
      case ProxyType.http:
        if (username != null && password != null) {
          return 'http://$username:$password@$host:$port';
        }
        return 'http://$host:$port';
      case ProxyType.https:
        if (username != null && password != null) {
          return 'https://$username:$password@$host:$port';
        }
        return 'https://$host:$port';
      case ProxyType.shadowsocks:
        return 'ss://$method:$password@$host:$port';
      case ProxyType.v2ray:
        return 'vmess://$host:$port';
      case ProxyType.trojan:
        return 'trojan://$password@$host:$port';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxyConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}