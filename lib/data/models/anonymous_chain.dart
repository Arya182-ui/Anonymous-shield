import 'package:json_annotation/json_annotation.dart';
import 'proxy_config.dart';
import 'built_in_server.dart';

part 'anonymous_chain.g.dart';

enum AnonymousMode {
  ghost,    // Maximum anonymity (5+ hops)
  stealth,  // Censorship bypass
  turbo,    // Fast anonymity (2-3 hops)
  tor,      // Tor-like routing
  paranoid, // NSA-level protection
  custom    // User-defined chain
}

enum ChainStatus {
  inactive,
  connecting,
  connected,
  disconnecting,
  rotating,
  error
}

@JsonSerializable()
class AnonymousChain {
  final String id;
  final String name;
  final AnonymousMode mode;
  final List<ProxyConfig> proxyChain;
  final BuiltInServer? vpnExit;
  final ChainStatus status;
  final DateTime? connectedAt;
  final Duration? rotationInterval;
  final bool autoRotate;
  final bool trafficObfuscation;
  final bool dpiBypass;
  final Map<String, dynamic> securitySettings;
  
  const AnonymousChain({
    required this.id,
    required this.name,
    required this.mode,
    required this.proxyChain,
    this.vpnExit,
    this.status = ChainStatus.inactive,
    this.connectedAt,
    this.rotationInterval,
    this.autoRotate = true,
    this.trafficObfuscation = true,
    this.dpiBypass = true,
    this.securitySettings = const {},
  });

  factory AnonymousChain.fromJson(Map<String, dynamic> json) => _$AnonymousChainFromJson(json);
  Map<String, dynamic> toJson() => _$AnonymousChainToJson(this);
  
  // Predefined anonymous chains
  static AnonymousChain ghostMode() {
    return AnonymousChain(
      id: 'ghost_mode',
      name: 'Ghost Mode',
      mode: AnonymousMode.ghost,
      proxyChain: [
        // Entry proxy (India)
        ProxyConfig(
          id: 'entry_in_01',
          name: 'Mumbai Entry',
          type: ProxyType.shadowsocks,
          role: ProxyRole.entry,
          host: 'in-entry1.anonshield.net',
          port: 8388,
          method: 'chacha20-ietf-poly1305',
          password: 'ghost_entry_key',
          country: 'India',
          countryCode: 'IN',
          flagEmoji: '🇮🇳',
          isObfuscated: true,
          createdAt: DateTime.now(),
        ),
        
        // Middle relay 1 (Singapore)
        ProxyConfig(
          id: 'middle_sg_01',
          name: 'Singapore Relay',
          type: ProxyType.v2ray,
          role: ProxyRole.middle,
          host: 'sg-relay1.anonshield.net',
          port: 443,
          country: 'Singapore',
          countryCode: 'SG',
          flagEmoji: '🇸🇬',
          isObfuscated: true,
          createdAt: DateTime.now(),
        ),
        
        // Middle relay 2 (Germany)
        ProxyConfig(
          id: 'middle_de_01',
          name: 'Frankfurt Relay',
          type: ProxyType.trojan,
          role: ProxyRole.middle,
          host: 'de-relay2.anonshield.net',
          port: 443,
          country: 'Germany',
          countryCode: 'DE',
          flagEmoji: '🇩🇪',
          isObfuscated: true,
          createdAt: DateTime.now(),
        ),
        
        // Exit proxy (US)
        ProxyConfig(
          id: 'exit_us_01',
          name: 'New York Exit',
          type: ProxyType.socks5,
          role: ProxyRole.exit,
          host: 'us-exit1.anonshield.net',
          port: 1080,
          country: 'United States',
          countryCode: 'US',
          flagEmoji: '🇺🇸',
          isObfuscated: false,
          createdAt: DateTime.now(),
        ),
      ],
      rotationInterval: Duration(minutes: 10),
      autoRotate: true,
      trafficObfuscation: true,
      dpiBypass: true,
      securitySettings: {
        'maxHops': 5,
        'minLatency': 200,
        'encryptionLevel': 'maximum',
        'dnsLeakProtection': true,
        'ipv6Blocking': true,
        'webrtcBlocking': true,
      },
    );
  }
  
  static AnonymousChain stealthMode() {
    return AnonymousChain(
      id: 'stealth_mode',
      name: 'Stealth Mode',
      mode: AnonymousMode.stealth,
      proxyChain: [
        // Obfuscated entry (China-friendly)
        ProxyConfig(
          id: 'stealth_entry_01',
          name: 'Stealth Entry',
          type: ProxyType.v2ray,
          role: ProxyRole.entry,
          host: 'stealth1.anonshield.net',
          port: 443,
          plugin: 'obfs-local',
          country: 'Netherlands',
          countryCode: 'NL',
          flagEmoji: '🇳🇱',
          isObfuscated: true,
          metadata: {
            'protocol': 'vmess',
            'security': 'chacha20-poly1305',
            'alterId': 0,
            'level': 1,
          },
          createdAt: DateTime.now(),
        ),
        
        // Exit via different country
        ProxyConfig(
          id: 'stealth_exit_01',
          name: 'Stealth Exit',
          type: ProxyType.shadowsocks,
          role: ProxyRole.exit,
          host: 'ca-stealth.anonshield.net',
          port: 8080,
          method: 'aes-256-gcm',
          password: 'stealth_mode_key',
          country: 'Canada',
          countryCode: 'CA',
          flagEmoji: '🇨🇦',
          isObfuscated: true,
          createdAt: DateTime.now(),
        ),
      ],
      rotationInterval: Duration(minutes: 5),
      autoRotate: true,
      trafficObfuscation: true,
      dpiBypass: true,
      securitySettings: {
        'dpiEvasion': 'advanced',
        'protocolMimicry': 'https',
        'packetObfuscation': true,
        'timingRandomization': true,
        'censorshipResistance': 'maximum',
      },
    );
  }
  
  static AnonymousChain turboMode() {
    return AnonymousChain(
      id: 'turbo_mode',
      name: 'Turbo Mode',
      mode: AnonymousMode.turbo,
      proxyChain: [
        // Fast entry
        ProxyConfig(
          id: 'turbo_entry_01',
          name: 'Turbo Entry',
          type: ProxyType.socks5,
          role: ProxyRole.entry,
          host: 'turbo1.anonshield.net',
          port: 1080,
          country: 'United Kingdom',
          countryCode: 'GB',
          flagEmoji: '🇬🇧',
          priority: 10, // High priority
          createdAt: DateTime.now(),
        ),
      ],
      rotationInterval: Duration(minutes: 15),
      autoRotate: false,
      trafficObfuscation: false,
      dpiBypass: false,
      securitySettings: {
        'optimizeSpeed': true,
        'preferLowLatency': true,
        'minimumEncryption': false,
      },
    );
  }
  
  int get hopCount => proxyChain.length + (vpnExit != null ? 1 : 0);
  
  bool get isConnected => status == ChainStatus.connected;
  
  bool get isHighSecurity => mode == AnonymousMode.ghost || mode == AnonymousMode.paranoid;
  
  Duration? get uptime => connectedAt != null ? DateTime.now().difference(connectedAt!) : null;
  
  String get modeDescription {
    switch (mode) {
      case AnonymousMode.ghost:
        return 'Maximum anonymity with 5+ hop routing';
      case AnonymousMode.stealth:
        return 'Censorship-resistant with DPI evasion';
      case AnonymousMode.turbo:
        return 'Fast anonymity with optimized routing';
      case AnonymousMode.tor:
        return 'Tor-like onion routing for deep web access';
      case AnonymousMode.paranoid:
        return 'NSA-level protection with advanced features';
      case AnonymousMode.custom:
        return 'Custom-configured proxy chain';
    }
  }

  // Computed properties for UI compatibility
  AnonymousMode get currentMode => mode;
  List<BuiltInServer> get servers => proxyChain
      .map((proxy) => BuiltInServer(
            id: proxy.id,
            name: proxy.name,
            country: proxy.country ?? 'Unknown',
            countryCode: proxy.countryCode ?? 'XX',
            city: proxy.country ?? 'Unknown', // Use country as city fallback
            serverAddress: proxy.host,
            port: proxy.port,
            latitude: 0.0, // Default coordinates
            longitude: 0.0,
            flagEmoji: proxy.flagEmoji ?? '🌍',
          ))
      .toList();
  
  // Convenience getters
  bool get isConnecting => status == ChainStatus.connecting;
  bool get isDisconnected => status == ChainStatus.inactive;
  
  // Add copyWith method
  AnonymousChain copyWith({
    String? id,
    String? name,
    AnonymousMode? mode,
    List<ProxyConfig>? proxyChain,
    BuiltInServer? vpnExit,
    ChainStatus? status,
    DateTime? connectedAt,
    Duration? rotationInterval,
    bool? autoRotate,
    bool? trafficObfuscation,
    bool? dpiBypass,
    Map<String, dynamic>? securitySettings,
  }) {
    return AnonymousChain(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      proxyChain: proxyChain ?? this.proxyChain,
      vpnExit: vpnExit ?? this.vpnExit,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      rotationInterval: rotationInterval ?? this.rotationInterval,
      autoRotate: autoRotate ?? this.autoRotate,
      trafficObfuscation: trafficObfuscation ?? this.trafficObfuscation,
      dpiBypass: dpiBypass ?? this.dpiBypass,
      securitySettings: securitySettings ?? this.securitySettings,
    );
  }
}