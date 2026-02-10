// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionStatus _$ConnectionStatusFromJson(Map<String, dynamic> json) =>
    ConnectionStatus(
      vpnStatus:
          $enumDecodeNullable(_$VpnStatusEnumMap, json['vpnStatus']) ??
          VpnStatus.disconnected,
      proxyStatus:
          $enumDecodeNullable(_$ProxyStatusEnumMap, json['proxyStatus']) ??
          ProxyStatus.disabled,
      currentServerId: json['currentServerId'] as String?,
      currentServerName: json['currentServerName'] as String?,
      currentIpAddress: json['currentIpAddress'] as String?,
      currentCountry: json['currentCountry'] as String?,
      currentCity: json['currentCity'] as String?,
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
      lastRotationAt: json['lastRotationAt'] == null
          ? null
          : DateTime.parse(json['lastRotationAt'] as String),
      nextRotationAt: json['nextRotationAt'] == null
          ? null
          : DateTime.parse(json['nextRotationAt'] as String),
      connectionDuration: json['connectionDuration'] == null
          ? null
          : Duration(microseconds: (json['connectionDuration'] as num).toInt()),
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
      lastErrorMessage: json['lastErrorMessage'] as String?,
      lastErrorAt: json['lastErrorAt'] == null
          ? null
          : DateTime.parse(json['lastErrorAt'] as String),
      killSwitchActive: json['killSwitchActive'] as bool? ?? false,
      dnsLeakProtectionActive:
          json['dnsLeakProtectionActive'] as bool? ?? false,
      ipv6Blocked: json['ipv6Blocked'] as bool? ?? false,
    );

Map<String, dynamic> _$ConnectionStatusToJson(ConnectionStatus instance) =>
    <String, dynamic>{
      'vpnStatus': _$VpnStatusEnumMap[instance.vpnStatus]!,
      'proxyStatus': _$ProxyStatusEnumMap[instance.proxyStatus]!,
      'currentServerId': instance.currentServerId,
      'currentServerName': instance.currentServerName,
      'currentIpAddress': instance.currentIpAddress,
      'currentCountry': instance.currentCountry,
      'currentCity': instance.currentCity,
      'connectedAt': instance.connectedAt?.toIso8601String(),
      'lastRotationAt': instance.lastRotationAt?.toIso8601String(),
      'nextRotationAt': instance.nextRotationAt?.toIso8601String(),
      'connectionDuration': instance.connectionDuration?.inMicroseconds,
      'bytesReceived': instance.bytesReceived,
      'bytesSent': instance.bytesSent,
      'lastErrorMessage': instance.lastErrorMessage,
      'lastErrorAt': instance.lastErrorAt?.toIso8601String(),
      'killSwitchActive': instance.killSwitchActive,
      'dnsLeakProtectionActive': instance.dnsLeakProtectionActive,
      'ipv6Blocked': instance.ipv6Blocked,
    };

const _$VpnStatusEnumMap = {
  VpnStatus.disconnected: 'disconnected',
  VpnStatus.connecting: 'connecting',
  VpnStatus.connected: 'connected',
  VpnStatus.disconnecting: 'disconnecting',
  VpnStatus.error: 'error',
  VpnStatus.reconnecting: 'reconnecting',
};

const _$ProxyStatusEnumMap = {
  ProxyStatus.disabled: 'disabled',
  ProxyStatus.enabled: 'enabled',
  ProxyStatus.error: 'error',
};
