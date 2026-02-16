import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'vpn_config.g.dart';

@JsonSerializable()
class VpnConfig {
  final String id;
  final String name;
  final String serverAddress;
  final int port;
  final String privateKey;
  final String publicKey;
  final String? presharedKey;
  final List<String> allowedIPs;
  final List<String> dnsServers;
  final int? mtu;
  final String? endpoint; // Full endpoint with port
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  // Enhanced properties for enhanced VPN manager
  final bool autoRotate;
  final Duration rotationInterval;
  final String serverName;
  final String serverHost;
  final int serverPort;
  final String protocol;
  final String? clientIpv4;
  final bool killSwitchEnabled;
  final String? customConfig;

  const VpnConfig({
    required this.id,
    required this.name,
    required this.serverAddress,
    required this.port,
    required this.privateKey,
    required this.publicKey,
    this.presharedKey,
    this.allowedIPs = const ['0.0.0.0/0', '::/0'],
    this.dnsServers = const ['1.1.1.1', '1.0.0.1'],
    this.mtu,
    this.endpoint,
    required this.createdAt,
    this.lastUsedAt,
    this.isActive = false,
    this.metadata,
    // Enhanced properties
    this.autoRotate = false,
    this.rotationInterval = const Duration(minutes: 30),
    String? serverName,
    String? serverHost,
    int? serverPort,
    this.protocol = 'WireGuard',
    this.clientIpv4,
    this.killSwitchEnabled = false,
    this.customConfig,
  })  : serverName = serverName ?? name,
        serverHost = serverHost ?? serverAddress,
        serverPort = serverPort ?? port;

  factory VpnConfig.fromJson(Map<String, dynamic> json) => _$VpnConfigFromJson(json);
  Map<String, dynamic> toJson() => _$VpnConfigToJson(this);

  factory VpnConfig.fromWireGuardConfig(String configText, {String? customName}) {
    const uuid = Uuid();
    final lines = configText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    
    String? privateKey, publicKey, presharedKey, endpoint;
    List<String> allowedIPs = [];
    List<String> dnsServers = [];
    int? mtu;
    
    for (final line in lines) {
      if (line.startsWith('PrivateKey = ')) {
        privateKey = line.substring(13);
      } else if (line.startsWith('PublicKey = ')) {
        publicKey = line.substring(12);
      } else if (line.startsWith('PresharedKey = ')) {
        presharedKey = line.substring(15);
      } else if (line.startsWith('Endpoint = ')) {
        endpoint = line.substring(11);
      } else if (line.startsWith('AllowedIPs = ')) {
        allowedIPs = line.substring(13).split(',').map((e) => e.trim()).toList();
      } else if (line.startsWith('DNS = ')) {
        dnsServers = line.substring(6).split(',').map((e) => e.trim()).toList();
      } else if (line.startsWith('MTU = ')) {
        mtu = int.tryParse(line.substring(6));
      }
    }
    
    if (privateKey == null || publicKey == null || endpoint == null) {
      throw ArgumentError('Invalid WireGuard configuration: missing required fields');
    }
    
    final endpointParts = endpoint.split(':');
    final serverAddress = endpointParts[0];
    final port = int.parse(endpointParts[1]);
    
    return VpnConfig(
      id: uuid.v4(),
      name: customName ?? 'Server $serverAddress',
      serverAddress: serverAddress,
      port: port,
      privateKey: privateKey,
      publicKey: publicKey,
      presharedKey: presharedKey,
      allowedIPs: allowedIPs.isNotEmpty ? allowedIPs : ['0.0.0.0/0', '::/0'],
      dnsServers: dnsServers.isNotEmpty ? dnsServers : ['1.1.1.1', '1.0.0.1'],
      mtu: mtu,
      createdAt: DateTime.now(),
      // Enhanced properties defaults
      autoRotate: false,
      rotationInterval: const Duration(minutes: 30),
      killSwitchEnabled: true,
      protocol: 'WireGuard',
    );
  }
  
  String toWireGuardConfig() {
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    if (dnsServers.isNotEmpty) {
      buffer.writeln('DNS = ${dnsServers.join(', ')}');
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
    buffer.writeln('Endpoint = $serverAddress:$port');
    buffer.writeln('AllowedIPs = ${allowedIPs.join(', ')}');
    return buffer.toString();
  }
  
  VpnConfig copyWith({
    String? id,
    String? name,
    String? serverAddress,
    int? port,
    String? privateKey,
    String? publicKey,
    String? presharedKey,
    List<String>? allowedIPs,
    List<String>? dnsServers,
    int? mtu,
    String? endpoint,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
    // Enhanced properties
    bool? autoRotate,
    Duration? rotationInterval,
    String? serverName,
    String? serverHost,
    int? serverPort,
    String? protocol,
    String? clientIpv4,
    bool? killSwitchEnabled,
    String? customConfig,
  }) {
    return VpnConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAddress: serverAddress ?? this.serverAddress,
      port: port ?? this.port,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      presharedKey: presharedKey ?? this.presharedKey,
      allowedIPs: allowedIPs ?? this.allowedIPs,
      dnsServers: dnsServers ?? this.dnsServers,
      mtu: mtu ?? this.mtu,
      endpoint: endpoint ?? this.endpoint,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      // Enhanced properties
      autoRotate: autoRotate ?? this.autoRotate,
      rotationInterval: rotationInterval ?? this.rotationInterval,
      serverName: serverName ?? this.serverName,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      protocol: protocol ?? this.protocol,
      clientIpv4: clientIpv4 ?? this.clientIpv4,
      killSwitchEnabled: killSwitchEnabled ?? this.killSwitchEnabled,
      customConfig: customConfig ?? this.customConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VpnConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}