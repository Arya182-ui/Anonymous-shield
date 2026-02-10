// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'proxy_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProxyConfig _$ProxyConfigFromJson(Map<String, dynamic> json) => ProxyConfig(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$ProxyTypeEnumMap, json['type']),
  role: $enumDecodeNullable(_$ProxyRoleEnumMap, json['role']),
  host: json['host'] as String,
  port: (json['port'] as num).toInt(),
  username: json['username'] as String?,
  password: json['password'] as String?,
  method: json['method'] as String?,
  plugin: json['plugin'] as String?,
  pluginOptions: json['pluginOptions'] as Map<String, dynamic>?,
  country: json['country'] as String?,
  countryCode: json['countryCode'] as String?,
  flagEmoji: json['flagEmoji'] as String?,
  isObfuscated: json['isObfuscated'] as bool? ?? false,
  priority: (json['priority'] as num?)?.toInt() ?? 50,
  isEnabled: json['isEnabled'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ProxyConfigToJson(ProxyConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$ProxyTypeEnumMap[instance.type]!,
      'role': _$ProxyRoleEnumMap[instance.role],
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'password': instance.password,
      'method': instance.method,
      'plugin': instance.plugin,
      'pluginOptions': instance.pluginOptions,
      'country': instance.country,
      'countryCode': instance.countryCode,
      'flagEmoji': instance.flagEmoji,
      'isObfuscated': instance.isObfuscated,
      'priority': instance.priority,
      'isEnabled': instance.isEnabled,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
      'metadata': instance.metadata,
    };

const _$ProxyTypeEnumMap = {
  ProxyType.socks5: 'socks5',
  ProxyType.shadowsocks: 'shadowsocks',
  ProxyType.http: 'http',
  ProxyType.https: 'https',
  ProxyType.trojan: 'trojan',
  ProxyType.v2ray: 'v2ray',
};

const _$ProxyRoleEnumMap = {
  ProxyRole.entry: 'entry',
  ProxyRole.middle: 'middle',
  ProxyRole.exit: 'exit',
  ProxyRole.bridge: 'bridge',
};
