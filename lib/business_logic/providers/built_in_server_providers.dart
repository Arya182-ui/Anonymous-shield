import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/built_in_server.dart';
import '../../data/models/vpn_config.dart';
import '../../data/services/built_in_server_service.dart';
import '../../data/services/free_vpn_provider.dart';

// Built-in server service provider
final builtInServerServiceProvider = Provider<BuiltInServerService>((ref) {
  return BuiltInServerService();
});

// Free VPN provider
final freeVpnProviderProvider = Provider<FreeVpnProvider>((ref) {
  return FreeVpnProvider();
});

// Built-in servers list provider
final builtInServersProvider = FutureProvider<List<BuiltInServer>>((ref) async {
  final service = ref.read(builtInServerServiceProvider);
  return await service.loadBuiltInServers();
});

// Servers sorted by distance provider
final serversByDistanceProvider = FutureProvider<List<BuiltInServer>>((ref) async {
  final service = ref.read(builtInServerServiceProvider);
  return await service.getServersByDistance();
});

// Recommended servers provider
final recommendedServersProvider = FutureProvider<List<BuiltInServer>>((ref) async {
  final service = ref.read(builtInServerServiceProvider);
  return await service.getRecommendedServers(limit: 5);
});

// Auto-selected best server provider
final autoSelectedServerProvider = FutureProvider<VpnConfig?>((ref) async {
  final service = ref.read(builtInServerServiceProvider);
  return await service.autoSelectBestServer();
});

// Multiple free VPN configs provider
final multipleFreeConfigsProvider = FutureProvider.family<List<VpnConfig>, int>((ref, limit) async {
  final service = ref.read(builtInServerServiceProvider);
  return await service.getMultipleFreeConfigs(limit: limit);
});

// Server search provider
final serverSearchProvider = StateProvider<String>((ref) => '');

// Filtered servers based on search
final filteredServersProvider = Provider<AsyncValue<List<BuiltInServer>>>((ref) {
  final serversAsync = ref.watch(builtInServersProvider);
  final searchQuery = ref.watch(serverSearchProvider);
  
  return serversAsync.when(
    data: (servers) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(servers);
      }
      
      final service = ref.read(builtInServerServiceProvider);
      final filteredServers = service.searchServers(searchQuery);
      return AsyncValue.data(filteredServers);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Selected server provider
final selectedServerProvider = StateProvider<BuiltInServer?>((ref) => null);

// Server connection state
final serverConnectionStateProvider = StateProvider<ServerConnectionState>((ref) {
  return ServerConnectionState.disconnected;
});

// Auto-connect state
final autoConnectEnabledProvider = StateProvider<bool>((ref) => false);

// Server rotation settings
final serverRotationProvider = StateProvider<ServerRotationSettings>((ref) {
  return ServerRotationSettings(
    enabled: false,
    intervalMinutes: 30,
    onlyRecommended: true,
  );
});

// Current active VPN config
final activeVpnConfigProvider = StateProvider<VpnConfig?>((ref) => null);

// Free provider selection
final selectedFreeProviderProvider = StateProvider<FreeVpnProviderType>((ref) {
  return FreeVpnProviderType.cloudflare;
});

// Cloudflare WARP generation provider
final warpConfigProvider = FutureProvider<VpnConfig?>((ref) async {
  final provider = ref.read(freeVpnProviderProvider);
  return await provider.generateWarpConfig();
});

// Multiple WARP configs for rotation
final multipleWarpConfigsProvider = FutureProvider.family<List<VpnConfig>, int>((ref, count) async {
  final provider = ref.read(freeVpnProviderProvider);
  return await provider.getMultipleWarpConfigs(count: count);
});

// Server statistics provider
final serverStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.read(builtInServerServiceProvider);
  return service.getServerStats();
});

// Enums and Models
enum ServerConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

enum FreeVpnProviderType {
  cloudflare,
  proton,
  windscribe,
  hideme,
  tunnelbear,
  outline,
  all,
}

class ServerRotationSettings {
  final bool enabled;
  final int intervalMinutes;
  final bool onlyRecommended;

  const ServerRotationSettings({
    required this.enabled,
    required this.intervalMinutes,
    this.onlyRecommended = true,
  });

  ServerRotationSettings copyWith({
    bool? enabled,
    int? intervalMinutes,
    bool? onlyRecommended,
  }) {
    return ServerRotationSettings(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      onlyRecommended: onlyRecommended ?? this.onlyRecommended,
    );
  }
}

// Extension to provide user-friendly provider names
extension FreeVpnProviderTypeExtension on FreeVpnProviderType {
  String get displayName {
    switch (this) {
      case FreeVpnProviderType.cloudflare:
        return 'Cloudflare WARP';
      case FreeVpnProviderType.proton:
        return 'ProtonVPN Free';
      case FreeVpnProviderType.windscribe:
        return 'Windscribe Free';
      case FreeVpnProviderType.hideme:
        return 'Hide.me Free';
      case FreeVpnProviderType.tunnelbear:
        return 'TunnelBear Free';
      case FreeVpnProviderType.outline:
        return 'Outline (Community)';
      case FreeVpnProviderType.all:
        return 'All Providers';
    }
  }

  String get description {
    switch (this) {
      case FreeVpnProviderType.cloudflare:
        return 'Unlimited, fast, privacy-focused';
      case FreeVpnProviderType.proton:
        return 'No data limit, 1 device';
      case FreeVpnProviderType.windscribe:
        return '10GB/month, multiple locations';
      case FreeVpnProviderType.hideme:
        return '10GB/month, good speeds';
      case FreeVpnProviderType.tunnelbear:
        return '500MB/month, easy to use';
      case FreeVpnProviderType.outline:
        return 'Community shared servers';
      case FreeVpnProviderType.all:
        return 'Mix of all providers';
    }
  }
}