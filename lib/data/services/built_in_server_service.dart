import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import '../models/built_in_server.dart';
import '../models/vpn_config.dart';
import 'free_vpn_provider.dart';

/// Built-in VPN servers management service
/// Automatically loads and manages pre-configured free VPN servers
class BuiltInServerService {
  static final BuiltInServerService _instance = BuiltInServerService._internal();
  factory BuiltInServerService() => _instance;
  BuiltInServerService._internal();

  final Logger _logger = Logger();
  final FreeVpnProvider _freeVpnProvider = FreeVpnProvider();
  
  List<BuiltInServer> _servers = [];
  Position? _userLocation;

  /// Load built-in servers from assets
  Future<List<BuiltInServer>> loadBuiltInServers() async {
    try {
      _logger.i('Loading built-in VPN servers...');
      
      // Load JSON from assets
      final String jsonString = await rootBundle.loadString('assets/json/built_in_servers.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> serversList = jsonData['servers'];
      
      // Convert to BuiltInServer objects
      _servers = serversList
          .map((json) => BuiltInServer.fromJson(json))
          .toList();
      
      _logger.i('Loaded ${_servers.length} built-in servers');
      return _servers;
      
    } catch (e, stack) {
      _logger.e('Failed to load built-in servers', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get all available servers
  List<BuiltInServer> getAllServers() => _servers;

  /// Get servers sorted by distance from user location
  Future<List<BuiltInServer>> getServersByDistance() async {
    try {
      await _updateUserLocation();
      
      if (_userLocation == null) {
        _logger.w('User location not available, returning unsorted servers');
        return _servers;
      }

      // Sort servers by distance
      final serversCopy = List<BuiltInServer>.from(_servers);
      serversCopy.sort((a, b) {
        final distanceA = a.distanceFrom(_userLocation!.latitude, _userLocation!.longitude);
        final distanceB = b.distanceFrom(_userLocation!.latitude, _userLocation!.longitude);
        return distanceA.compareTo(distanceB);
      });

      _logger.i('Sorted ${serversCopy.length} servers by distance');
      return serversCopy;
      
    } catch (e, stack) {
      _logger.e('Failed to sort servers by distance', error: e, stackTrace: stack);
      return _servers;
    }
  }

  /// Get recommended servers (fastest and closest)
  Future<List<BuiltInServer>> getRecommendedServers({int limit = 5}) async {
    try {
      final sortedServers = await getServersByDistance();
      
      // Filter for recommended or high-performance servers
      final recommended = sortedServers.where((server) {
        return server.isRecommended || 
               server.loadPercentage < 50 ||
               server.maxSpeedMbps > 100;
      }).take(limit).toList();

      _logger.i('Found ${recommended.length} recommended servers');
      return recommended;
      
    } catch (e, stack) {
      _logger.e('Failed to get recommended servers', error: e, stackTrace: stack);
      return _servers.take(limit).toList();
    }
  }

  /// Get servers by country
  List<BuiltInServer> getServersByCountry(String countryCode) {
    return _servers.where((server) => server.countryCode == countryCode).toList();
  }

  /// Get the fastest server (lowest load)
  BuiltInServer? getFastestServer() {
    if (_servers.isEmpty) return null;
    
    return _servers.reduce((a, b) => 
        a.loadPercentage < b.loadPercentage ? a : b);
  }

  /// Generate VPN configuration for a built-in server
  Future<VpnConfig?> generateConfigForServer(BuiltInServer server) async {
    try {
      _logger.i('Generating configuration for server: ${server.name}');
      
      // Handle auto-generation for specific providers
      if (server.id.contains('cloudflare') && server.id.contains('auto')) {
        // Use Cloudflare WARP auto-generation
        final warpConfig = await _freeVpnProvider.generateWarpConfig();
        if (warpConfig != null) {
          return warpConfig.copyWith(
            name: server.name,
            metadata: {
              'server_id': server.id,
              'country': server.country,
              'city': server.city,
              'provider': 'cloudflare',
              'auto_generated': true,
            },
          );
        }
      }

      // For other providers, convert built-in server to VPN config
      final config = server.toVpnConfig().copyWith(
        metadata: {
          'server_id': server.id,
          'country': server.country, 
          'city': server.city,
          'provider': server.id.split('-').first,
        },
      );

      _logger.i('Generated configuration for ${server.name}');
      return config;
      
    } catch (e, stack) {
      _logger.e('Failed to generate config for server ${server.name}', 
                error: e, stackTrace: stack);
      return null;
    }
  }

  /// Auto-select best server for user
  Future<VpnConfig?> autoSelectBestServer() async {
    try {
      _logger.i('Auto-selecting best VPN server...');
      
      // First try to get recommended servers by distance
      final recommended = await getRecommendedServers(limit: 3);
      
      if (recommended.isNotEmpty) {
        // Try to generate config for the best server
        for (final server in recommended) {
          final config = await generateConfigForServer(server);
          if (config != null) {
            _logger.i('Auto-selected server: ${server.name}');
            return config;
          }
        }
      }

      // Fallback: try any available server
      for (final server in _servers) {
        final config = await generateConfigForServer(server);
        if (config != null) {
          _logger.i('Fallback selected server: ${server.name}');
          return config;
        }
      }

      _logger.w('No suitable server found');
      return null;
      
    } catch (e, stack) {
      _logger.e('Failed to auto-select server', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Get multiple free VPN configurations
  Future<List<VpnConfig>> getMultipleFreeConfigs({int limit = 5}) async {
    try {
      _logger.i('Generating multiple free VPN configurations...');
      
      final configs = <VpnConfig>[];
      final servers = await getRecommendedServers(limit: limit * 2);
      
      // Generate configs for each server
      for (final server in servers) {
        if (configs.length >= limit) break;
        
        final config = await generateConfigForServer(server);
        if (config != null) {
          configs.add(config);
        }
      }

      // If we don't have enough, try additional free providers
      if (configs.length < limit) {
        final additionalConfigs = await _freeVpnProvider.getFreeVpnConfigs();
        configs.addAll(additionalConfigs.take(limit - configs.length));
      }

      _logger.i('Generated ${configs.length} free VPN configurations');
      return configs;
      
    } catch (e, stack) {
      _logger.e('Failed to get multiple free configs', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Update server load information (mock data for now)
  void updateServerLoads() {
    final random = Random();
    
    for (int i = 0; i < _servers.length; i++) {
      // Simulate load changes (±10%)
      final currentLoad = _servers[i].loadPercentage;
      final change = random.nextInt(21) - 10; // -10 to +10
      final newLoad = (currentLoad + change).clamp(10, 90);
      
      // Create updated server (immutable)
      _servers[i] = BuiltInServer(
        id: _servers[i].id,
        name: _servers[i].name,
        country: _servers[i].country,
        countryCode: _servers[i].countryCode,
        city: _servers[i].city,
        serverAddress: _servers[i].serverAddress,
        port: _servers[i].port,
        latitude: _servers[i].latitude,
        longitude: _servers[i].longitude,
        isFree: _servers[i].isFree,
        maxSpeedMbps: _servers[i].maxSpeedMbps,
        flagEmoji: _servers[i].flagEmoji,
        isRecommended: _servers[i].isRecommended,
        loadPercentage: newLoad,
      );
    }
    
    _logger.d('Updated server load information');
  }

  /// Get user location for distance calculation
  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.w('Location permissions permanently denied');
        return;
      }

      _userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      );
      
      _logger.d('Updated user location: ${_userLocation?.latitude}, ${_userLocation?.longitude}');
      
    } catch (e, stack) {
      _logger.w('Failed to get user location', error: e, stackTrace: stack);
    }
  }

  /// Search servers by name or country
  List<BuiltInServer> searchServers(String query) {
    if (query.isEmpty) return _servers;
    
    final lowercaseQuery = query.toLowerCase();
    
    return _servers.where((server) {
      return server.name.toLowerCase().contains(lowercaseQuery) ||
             server.country.toLowerCase().contains(lowercaseQuery) ||
             server.city.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Check if servers are loaded
  bool get isLoaded => _servers.isNotEmpty;

  /// Get server statistics
  Map<String, dynamic> getServerStats() {
    final stats = {
      'total_servers': _servers.length,
      'free_servers': _servers.where((s) => s.isFree).length,
      'recommended_servers': _servers.where((s) => s.isRecommended).length,
      'countries': _servers.map((s) => s.countryCode).toSet().length,
      'providers': _servers.map((s) => s.id.split('-').first).toSet().toList(),
      'average_load': _servers.isNotEmpty 
          ? _servers.map((s) => s.loadPercentage).reduce((a, b) => a + b) / _servers.length
          : 0,
    };
    
    return stats;
  }
}

/// Extension to add copyWith method to VpnConfig
extension VpnConfigCopyWith on VpnConfig {
  VpnConfig copyWith({
    String? id,
    String? name,
    String? serverAddress,
    int? port,
    String? privateKey,
    String? publicKey,
    String? presharedKey,
    List<String>? allowedIPs,
    List<String>? dnsServers,
    int? mtu,
    String? endpoint,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return VpnConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAddress: serverAddress ?? this.serverAddress,
      port: port ?? this.port,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      presharedKey: presharedKey ?? this.presharedKey,
      allowedIPs: allowedIPs ?? this.allowedIPs,
      dnsServers: dnsServers ?? this.dnsServers,  
      mtu: mtu ?? this.mtu,
      endpoint: endpoint ?? this.endpoint,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }
}