// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anonymous_chain.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnonymousChain _$AnonymousChainFromJson(Map<String, dynamic> json) =>
    AnonymousChain(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: $enumDecode(_$AnonymousModeEnumMap, json['mode']),
      proxyChain: (json['proxyChain'] as List<dynamic>)
          .map((e) => ProxyConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      vpnExit: json['vpnExit'] == null
          ? null
          : BuiltInServer.fromJson(json['vpnExit'] as Map<String, dynamic>),
      status:
          $enumDecodeNullable(_$ChainStatusEnumMap, json['status']) ??
          ChainStatus.inactive,
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
      rotationInterval: json['rotationInterval'] == null
          ? null
          : Duration(microseconds: (json['rotationInterval'] as num).toInt()),
      autoRotate: json['autoRotate'] as bool? ?? true,
      trafficObfuscation: json['trafficObfuscation'] as bool? ?? true,
      dpiBypass: json['dpiBypass'] as bool? ?? true,
      securitySettings:
          json['securitySettings'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$AnonymousChainToJson(AnonymousChain instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'mode': _$AnonymousModeEnumMap[instance.mode]!,
      'proxyChain': instance.proxyChain,
      'vpnExit': instance.vpnExit,
      'status': _$ChainStatusEnumMap[instance.status]!,
      'connectedAt': instance.connectedAt?.toIso8601String(),
      'rotationInterval': instance.rotationInterval?.inMicroseconds,
      'autoRotate': instance.autoRotate,
      'trafficObfuscation': instance.trafficObfuscation,
      'dpiBypass': instance.dpiBypass,
      'securitySettings': instance.securitySettings,
    };

const _$AnonymousModeEnumMap = {
  AnonymousMode.ghost: 'ghost',
  AnonymousMode.stealth: 'stealth',
  AnonymousMode.turbo: 'turbo',
  AnonymousMode.tor: 'tor',
  AnonymousMode.paranoid: 'paranoid',
  AnonymousMode.custom: 'custom',
};

const _$ChainStatusEnumMap = {
  ChainStatus.inactive: 'inactive',
  ChainStatus.connecting: 'connecting',
  ChainStatus.connected: 'connected',
  ChainStatus.disconnecting: 'disconnecting',
  ChainStatus.rotating: 'rotating',
  ChainStatus.error: 'error',
};
