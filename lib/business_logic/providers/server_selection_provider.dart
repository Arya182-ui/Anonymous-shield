import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/built_in_server.dart';
import '../../data/repositories/built_in_servers_repository.dart';

// Selected server state
final selectedServerProvider = StateNotifierProvider<SelectedServerNotifier, BuiltInServer?>((ref) {
  return SelectedServerNotifier();
});

// Available servers list
final availableServersProvider = Provider<List<BuiltInServer>>((ref) {
  return BuiltInServersRepository().getAllServers();
});

// Servers by country
final serversByCountryProvider = Provider<Map<String, List<BuiltInServer>>>((ref) {
  final servers = ref.watch(availableServersProvider);
  final Map<String, List<BuiltInServer>> serversByCountry = {};
  
  for (final server in servers) {
    if (!serversByCountry.containsKey(server.country)) {
      serversByCountry[server.country] = [];
    }
    serversByCountry[server.country]!.add(server);
  }
  
  return serversByCountry;
});

// Recommended servers
final recommendedServersProvider = Provider<List<BuiltInServer>>((ref) {
  return BuiltInServersRepository().getRecommendedServers();
});

// Country list
final countryListProvider = Provider<List<String>>((ref) {
  return BuiltInServersRepository().getUniqueCountries();
});

class SelectedServerNotifier extends StateNotifier<BuiltInServer?> {
  SelectedServerNotifier() : super(null);

  void selectServer(BuiltInServer server) {
    state = server;
  }

  void clearSelection() {
    state = null;
  }

  BuiltInServer? get selectedServer => state;
}