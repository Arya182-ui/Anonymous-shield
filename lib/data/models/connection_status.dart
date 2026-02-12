import 'package:json_annotation/json_annotation.dart';

part 'connection_status.g.dart';

// Simple enum for basic connection states
enum SimpleConnectionStatus {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('disconnecting')
  disconnecting,
  @JsonValue('error')
  error,
}

enum VpnStatus {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('disconnecting')
  disconnecting,
  @JsonValue('error')
  error,
  @JsonValue('reconnecting')
  reconnecting,
}

enum ProxyStatus {
  @JsonValue('disabled')
  disabled,
  @JsonValue('enabled')
  enabled,
  @JsonValue('error')
  error,
}

@JsonSerializable()
class ConnectionStatus {
  final VpnStatus vpnStatus;
  final ProxyStatus proxyStatus;
  final String? currentServerId;
  final String? currentServerName;
  final String? currentIpAddress;
  final String? currentCountry;
  final String? currentCity;
  final DateTime? connectedAt;
  final DateTime? lastRotationAt;
  final DateTime? nextRotationAt;
  final Duration? connectionDuration;
  final int bytesReceived;
  final int bytesSent;
  final String? lastErrorMessage;
  final DateTime? lastErrorAt;
  final bool killSwitchActive;
  final bool dnsLeakProtectionActive;
  final bool ipv6Blocked;

  const ConnectionStatus({
    this.vpnStatus = VpnStatus.disconnected,
    this.proxyStatus = ProxyStatus.disabled,
    this.currentServerId,
    this.currentServerName,
    this.currentIpAddress,
    this.currentCountry,
    this.currentCity,
    this.connectedAt,
    this.lastRotationAt,
    this.nextRotationAt,
    this.connectionDuration,
    this.bytesReceived = 0,
    this.bytesSent = 0,
    this.lastErrorMessage,
    this.lastErrorAt,
    this.killSwitchActive = false,
    this.dnsLeakProtectionActive = false,
    this.ipv6Blocked = false,
  });

  factory ConnectionStatus.fromJson(Map<String, dynamic> json) => _$ConnectionStatusFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectionStatusToJson(this);

  // Factory method for method channel
  factory ConnectionStatus.fromMap(Map<String, dynamic> map) {
    return ConnectionStatus(
      vpnStatus: VpnStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['vpnStatus'],
        orElse: () => VpnStatus.disconnected,
      ),
      proxyStatus: ProxyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['proxyStatus'],
        orElse: () => ProxyStatus.disabled,
      ),
      currentServerId: map['currentServerId'],
      currentServerName: map['currentServerName'],
      currentIpAddress: map['currentIpAddress'],
      currentCountry: map['currentCountry'],
      currentCity: map['currentCity'],
      connectedAt: map['connectedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['connectedAt']) 
          : null,
      lastRotationAt: map['lastRotationAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastRotationAt'])
          : null,
      nextRotationAt: map['nextRotationAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextRotationAt'])
          : null,
      connectionDuration: map['connectionDuration'] != null
          ? Duration(milliseconds: map['connectionDuration'])
          : null,
      bytesReceived: map['bytesReceived'] ?? 0,
      bytesSent: map['bytesSent'] ?? 0,
      lastErrorMessage: map['lastErrorMessage'],
      lastErrorAt: map['lastErrorAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastErrorAt'])
          : null,
      killSwitchActive: map['killSwitchActive'] ?? false,
      dnsLeakProtectionActive: map['dnsLeakProtectionActive'] ?? false,
      ipv6Blocked: map['ipv6Blocked'] ?? false,
    );
  }

  // Factory method to create disconnected status
  factory ConnectionStatus.disconnected({String? errorMessage}) {
    return ConnectionStatus(
      vpnStatus: VpnStatus.disconnected,
      proxyStatus: ProxyStatus.disabled,
      lastErrorMessage: errorMessage,
      lastErrorAt: errorMessage != null ? DateTime.now() : null,
    );
  }

  ConnectionStatus copyWith({
    VpnStatus? vpnStatus,
    ProxyStatus? proxyStatus,
    String? currentServerId,
    String? currentServerName,
    String? currentIpAddress,
    String? currentCountry,
    String? currentCity,
    DateTime? connectedAt,
    DateTime? lastRotationAt,
    DateTime? nextRotationAt,
    Duration? connectionDuration,
    int? bytesReceived,
    int? bytesSent,
    String? lastErrorMessage,
    DateTime? lastErrorAt,
    bool? killSwitchActive,
    bool? dnsLeakProtectionActive,
    bool? ipv6Blocked,
  }) {
    return ConnectionStatus(
      vpnStatus: vpnStatus ?? this.vpnStatus,
      proxyStatus: proxyStatus ?? this.proxyStatus,
      currentServerId: currentServerId ?? this.currentServerId,
      currentServerName: currentServerName ?? this.currentServerName,
      currentIpAddress: currentIpAddress ?? this.currentIpAddress,
      currentCountry: currentCountry ?? this.currentCountry,
      currentCity: currentCity ?? this.currentCity,
      connectedAt: connectedAt ?? this.connectedAt,
      lastRotationAt: lastRotationAt ?? this.lastRotationAt,
      nextRotationAt: nextRotationAt ?? this.nextRotationAt,
      connectionDuration: connectionDuration ?? this.connectionDuration,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesSent: bytesSent ?? this.bytesSent,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      killSwitchActive: killSwitchActive ?? this.killSwitchActive,
      dnsLeakProtectionActive: dnsLeakProtectionActive ?? this.dnsLeakProtectionActive,
      ipv6Blocked: ipv6Blocked ?? this.ipv6Blocked,
    );
  }

  bool get isConnected => vpnStatus == VpnStatus.connected;
  bool get isConnecting => vpnStatus == VpnStatus.connecting || vpnStatus == VpnStatus.reconnecting;
  bool get hasError => vpnStatus == VpnStatus.error || lastErrorMessage != null;
  bool get isProxyEnabled => proxyStatus == ProxyStatus.enabled;

  String get statusText {
    switch (vpnStatus) {
      case VpnStatus.disconnected:
        return 'Disconnected';
      case VpnStatus.connecting:
        return 'Connecting...';
      case VpnStatus.connected:
        return 'Connected';
      case VpnStatus.disconnecting:
        return 'Disconnecting...';
      case VpnStatus.reconnecting:
        return 'Reconnecting...';
      case VpnStatus.error:
        return 'Error: ${lastErrorMessage ?? 'Unknown error'}';
    }
  }
}