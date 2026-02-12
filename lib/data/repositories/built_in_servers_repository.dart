import '../models/built_in_server.dart';
import '../models/vpn_config.dart';
import '../services/free_vpn_provider.dart';
import 'package:logger/logger.dart';

class BuiltInServersRepository {
  static final BuiltInServersRepository _instance = BuiltInServersRepository._internal();
  factory BuiltInServersRepository() => _instance;
  BuiltInServersRepository._internal();

  final Logger _logger = Logger();
  final FreeVpnProvider _freeVpnProvider = FreeVpnProvider();
  
  List<VpnConfig>? _cachedFreeConfigs;

  // Pre-configured free servers for instant connectivity
  static final List<BuiltInServer> _servers = [
    BuiltInServer(
      id: 'in-mumbai-01',
      name: 'India - Mumbai',
      country: 'India',
      countryCode: 'IN',
      city: 'Mumbai',
      serverAddress: 'in1.freevpn.world',
      port: 51820,
      latitude: 19.0760,
      longitude: 72.8777,
      flagEmoji: '🇮🇳',
      isRecommended: true,
      maxSpeedMbps: 50,
      loadPercentage: 45,
    ),
    BuiltInServer(
      id: 'us-newyork-01', 
      name: 'USA - New York',
      country: 'United States',
      countryCode: 'US',
      city: 'New York',
      serverAddress: 'us1.freevpn.world',
      port: 51820,
      latitude: 40.7128,
      longitude: -74.0060,
      flagEmoji: '🇺🇸',
      maxSpeedMbps: 100,
      loadPercentage: 35,
    ),
    BuiltInServer(
      id: 'sg-singapore-01',
      name: 'Singapore',
      country: 'Singapore', 
      countryCode: 'SG',
      city: 'Singapore',
      serverAddress: 'sg1.freevpn.world',
      port: 51820,
      latitude: 1.3521,
      longitude: 103.8198,
      flagEmoji: '🇸🇬',
      isRecommended: true,
      maxSpeedMbps: 80,
      loadPercentage: 25,
    ),
    BuiltInServer(
      id: 'jp-tokyo-01',
      name: 'Japan - Tokyo',
      country: 'Japan',
      countryCode: 'JP', 
      city: 'Tokyo',
      serverAddress: 'jp1.freevpn.world',
      port: 51820,
      latitude: 35.6762,
      longitude: 139.6503,
      flagEmoji: '🇯🇵',
      maxSpeedMbps: 90,
      loadPercentage: 40,
    ),
    BuiltInServer(
      id: 'gb-london-01',
      name: 'UK - London', 
      country: 'United Kingdom',
      countryCode: 'GB',
      city: 'London',
      serverAddress: 'uk1.freevpn.world',
      port: 51820,
      latitude: 51.5074,
      longitude: -0.1278,
      flagEmoji: '🇬🇧',
      maxSpeedMbps: 75,
      loadPercentage: 55,
    ),
    BuiltInServer(
      id: 'de-frankfurt-01',
      name: 'Germany - Frankfurt',
      country: 'Germany',
      countryCode: 'DE',
      city: 'Frankfurt', 
      serverAddress: 'de1.freevpn.world',
      port: 51820,
      latitude: 50.1109,
      longitude: 8.6821,
      flagEmoji: '🇩🇪',
      maxSpeedMbps: 85,
      loadPercentage: 30,
    ),
    BuiltInServer(
      id: 'au-sydney-01',
      name: 'Australia - Sydney',
      country: 'Australia',
      countryCode: 'AU',
      city: 'Sydney',
      serverAddress: 'au1.freevpn.world',
      port: 51820,
      latitude: -33.8688,
      longitude: 151.2093,
      flagEmoji: '🇦🇺',
      maxSpeedMbps: 70,
      loadPercentage: 40,
    ),
    BuiltInServer(
      id: 'ca-toronto-01',
      name: 'Canada - Toronto',
      country: 'Canada',
      countryCode: 'CA',
      city: 'Toronto',
      serverAddress: 'ca1.freevpn.world',
      port: 51820,
      latitude: 43.6532,
      longitude: -79.3832,
      flagEmoji: '🇨🇦',
      maxSpeedMbps: 65,
      loadPercentage: 50,
    ),
  ];

  List<BuiltInServer> getAllServers() {
    return List.from(_servers);
  }

  List<BuiltInServer> getFreeServers() {
    return _servers.where((server) => server.isFree).toList();
  }

  List<BuiltInServer> getRecommendedServers() {
    return _servers.where((server) => server.isRecommended).toList();
  }

  BuiltInServer? getServerById(String id) {
    try {
      return _servers.firstWhere((server) => server.id == id);
    } catch (e) {
      return null;
    }
  }

  List<BuiltInServer> getServersByCountry(String countryCode) {
    return _servers.where((server) => server.countryCode == countryCode).toList();
  }

  List<BuiltInServer> getNearestServers(double userLat, double userLon, {int limit = 5}) {
    final serversWithDistance = _servers.map((server) {
      return MapEntry(server, server.distanceFrom(userLat, userLon));
    }).toList();

    serversWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    return serversWithDistance
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  BuiltInServer getBestServer({double? userLat, double? userLon}) {
    // If user location available, get nearest server
    if (userLat != null && userLon != null) {
      final nearestServers = getNearestServers(userLat, userLon, limit: 3);
      // From nearest servers, pick one with lowest load
      nearestServers.sort((a, b) => a.loadPercentage.compareTo(b.loadPercentage));
      return nearestServers.first;
    }
    
    // Fallback: get server with lowest load
    final sortedByLoad = List<BuiltInServer>.from(_servers);
    sortedByLoad.sort((a, b) => a.loadPercentage.compareTo(b.loadPercentage));
    return sortedByLoad.first;
  }

  List<String> getUniqueCountries() {
    final countries = _servers.map((server) => server.country).toSet().toList();
    countries.sort();
    return countries;
  }
  
  /// Get real VPN configurations from free providers
  Future<List<VpnConfig>> getRealVpnConfigurations() async {
    try {
      _logger.i('Fetching real VPN configurations from free providers...');
      
      // Check cache first
      if (_cachedFreeConfigs != null && _cachedFreeConfigs!.isNotEmpty) {
        _logger.d('Returning cached VPN configurations');
        return _cachedFreeConfigs!;
      }
      
      // Fetch fresh configurations
      final configs = await _freeVpnProvider.getFreeVpnConfigs();
      _cachedFreeConfigs = configs;
      
      _logger.i('Retrieved ${configs.length} real VPN configurations');
      return configs;
      
    } catch (e, stack) {
      _logger.e('Failed to get real VPN configurations', error: e, stackTrace: stack);
      
      // Fallback to test configuration for development
      return [_freeVpnProvider.createTestConfig()];
    }
  }
  
  /// Add custom VPN configuration (user imported)
  Future<bool> addCustomVpnConfig(VpnConfig config) async {
    try {
      _cachedFreeConfigs ??= [];
      _cachedFreeConfigs!.add(config);
      
      _logger.i('Added custom VPN configuration: ${config.name}');
      return true;
      
    } catch (e) {
      _logger.e('Failed to add custom VPN config', error: e);
      return false;
    }
  }
  
  /// Clear cached configurations (force refresh)
  void clearCache() {
    _cachedFreeConfigs = null;
    _logger.d('VPN configuration cache cleared');
  }
}