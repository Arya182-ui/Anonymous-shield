// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'built_in_server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BuiltInServer _$BuiltInServerFromJson(Map<String, dynamic> json) =>
    BuiltInServer(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      countryCode: json['countryCode'] as String,
      city: json['city'] as String,
      serverAddress: json['serverAddress'] as String,
      port: (json['port'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isFree: json['isFree'] as bool? ?? true,
      maxSpeedMbps: (json['maxSpeedMbps'] as num?)?.toInt() ?? 100,
      flagEmoji: json['flagEmoji'] as String,
      isRecommended: json['isRecommended'] as bool? ?? false,
      loadPercentage: (json['loadPercentage'] as num?)?.toInt() ?? 50,
      publicKey: json['publicKey'] as String?,
      clientPrivateKey: json['clientPrivateKey'] as String?,
      clientAddress: json['clientAddress'] as String?,
      presharedKey: json['presharedKey'] as String?,
      dns: (json['dns'] as List<dynamic>?)?.map((e) => e as String).toList(),
      provider: json['provider'] as String?,
    );

Map<String, dynamic> _$BuiltInServerToJson(BuiltInServer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'country': instance.country,
      'countryCode': instance.countryCode,
      'city': instance.city,
      'serverAddress': instance.serverAddress,
      'port': instance.port,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'isFree': instance.isFree,
      'maxSpeedMbps': instance.maxSpeedMbps,
      'flagEmoji': instance.flagEmoji,
      'isRecommended': instance.isRecommended,
      'loadPercentage': instance.loadPercentage,
      'publicKey': instance.publicKey,
      'clientPrivateKey': instance.clientPrivateKey,
      'clientAddress': instance.clientAddress,
      'presharedKey': instance.presharedKey,
      'dns': instance.dns,
      'provider': instance.provider,
    };
