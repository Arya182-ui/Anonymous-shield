// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VpnConfig _$VpnConfigFromJson(Map<String, dynamic> json) => VpnConfig(
  id: json['id'] as String,
  name: json['name'] as String,
  serverAddress: json['serverAddress'] as String,
  port: (json['port'] as num).toInt(),
  privateKey: json['privateKey'] as String,
  publicKey: json['publicKey'] as String,
  presharedKey: json['presharedKey'] as String?,
  allowedIPs:
      (json['allowedIPs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['0.0.0.0/0', '::/0'],
  dnsServers:
      (json['dnsServers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['1.1.1.1', '1.0.0.1'],
  mtu: (json['mtu'] as num?)?.toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  isActive: json['isActive'] as bool? ?? false,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$VpnConfigToJson(VpnConfig instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'serverAddress': instance.serverAddress,
  'port': instance.port,
  'privateKey': instance.privateKey,
  'publicKey': instance.publicKey,
  'presharedKey': instance.presharedKey,
  'allowedIPs': instance.allowedIPs,
  'dnsServers': instance.dnsServers,
  'mtu': instance.mtu,
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
  'isActive': instance.isActive,
  'metadata': instance.metadata,
};
