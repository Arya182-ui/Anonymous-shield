import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import '../models/built_in_server.dart';
import '../models/vpn_config.dart';
import 'free_vpn_provider.dart';

/// Built-in VPN servers management service
/// Supports real VPS WireGuard servers (instant connect) and WARP fallback.
class BuiltInServerService {
  static final BuiltInServerService _instance = BuiltInServerService._internal();
  factory BuiltInServerService() => _instance;
  BuiltInServerService._internal();

  final Logger _logger = Logger();
  final FreeVpnProvider _freeVpnProvider = FreeVpnProvider();
  
  /// Primary servers (real VPS when configured)
  List<BuiltInServer> _servers = [];
  /// Fallback servers (WARP endpoints)
  List<BuiltInServer> _fallbackServers = [];
  Position? _userLocation;
  
  /// Track last used server index for round-robin rotation
  int _lastUsedIndex = -1;

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
      
      // Load fallback servers (WARP endpoints)
      final List<dynamic>? fallbackList = jsonData['fallback_servers'];
      if (fallbackList != null) {
        _fallbackServers = fallbackList
            .map((json) => BuiltInServer.fromJson(json))
            .toList();
      }

      // Filter out servers with placeholder IPs (not yet configured)
      final configured = _servers.where((s) => 
          !s.serverAddress.startsWith('YOUR_')).toList();
      final unconfigured = _servers.length - configured.length;
      
      if (unconfigured > 0) {
        _logger.w('$unconfigured servers have placeholder IPs — skipped');
      }
      
      // Use only configured real servers; if none, fall back to WARP
      if (configured.isEmpty) {
        _logger.w('No real VPS servers configured, using WARP fallback servers');
        _servers = _fallbackServers;
      } else {
        _servers = configured;
      }
      
      _logger.i('Loaded ${_servers.length} servers (${_servers.where((s) => s.isRealVps).length} real VPS, '
          '${_servers.where((s) => !s.isRealVps).length} WARP, '
          '${_fallbackServers.length} fallback)');
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

  /// Generate VPN configuration for a built-in server.
  /// - Real VPS servers: builds config instantly from embedded keys (no API call).
  /// - WARP servers: calls Cloudflare registration API for key generation.
  Future<VpnConfig?> generateConfigForServer(BuiltInServer server) async {
    try {
      _logger.i('Generating configuration for server: ${server.name} '
          '(endpoint: ${server.serverAddress}:${server.port}, '
          'realVPS: ${server.isRealVps})');
      
      // ---- Real VPS: instant config from embedded keys ----
      if (server.isRealVps) {
        final config = server.toVpnConfig();
        _logger.i('Real VPS config ready: ${server.name} '
            '(${server.country}, ${server.city})');
        return config;
      }
      
      // ---- WARP: needs API registration for keys ----
      final serverEndpoint = '${server.serverAddress}:${server.port}';
      
      final warpConfig = await _freeVpnProvider.generateWarpConfig(
        overrideEndpoint: serverEndpoint,
      );
      if (warpConfig != null) {
        return warpConfig.copyWith(
          id: server.id,
          name: server.name,
          serverAddress: server.serverAddress,
          port: server.port,
          endpoint: serverEndpoint,
          metadata: {
            'server_id': server.id,
            'country': server.country,
            'city': server.city,
            'provider': 'cloudflare_warp',
            'auto_generated': true,
            'is_real_vps': false,
          },
        );
      }

      _logger.w('Config generation failed for ${server.name}');
      return null;
      
    } catch (e, stack) {
      _logger.e('Failed to generate config for server ${server.name}', 
                error: e, stackTrace: stack);
      return null;
    }
  }

  /// Auto-select best server — uses round-robin for real VPS (ensures IP changes)
  /// and random for WARP (diversity attempt within anycast limitation).
  ///
  /// If real VPS servers exist → pick the next one in rotation (guaranteed different IP).
  /// If only WARP → shuffle randomly (best effort).
  /// Falls back to WARP fallback_servers if primary list exhausted.
  Future<VpnConfig?> autoSelectBestServer() async {
    try {
      _logger.i('Auto-selecting server...');
      
      if (_servers.isEmpty) {
        await loadBuiltInServers();
      }
      
      if (_servers.isEmpty) {
        _logger.w('No servers available');
        return null;
      }
      
      // Separate real VPS from WARP servers
      final realVps = _servers.where((s) => s.isRealVps).toList();
      
      if (realVps.isNotEmpty) {
        // Round-robin across real VPS servers for guaranteed IP diversity
        _lastUsedIndex = (_lastUsedIndex + 1) % realVps.length;
        final server = realVps[_lastUsedIndex];
        
        final config = await generateConfigForServer(server);
        if (config != null) {
          _logger.i('Selected real VPS: ${server.name} '
              '(${server.country}, rotation #${_lastUsedIndex})');
          return config;
        }
        _logger.w('Real VPS ${server.name} failed, trying others...');
        
        // Try remaining real VPS servers
        for (int i = 0; i < realVps.length; i++) {
          if (i == _lastUsedIndex) continue;
          final fallbackServer = realVps[i];
          final fallbackConfig = await generateConfigForServer(fallbackServer);
          if (fallbackConfig != null) {
            _lastUsedIndex = i;
            _logger.i('Selected alternate VPS: ${fallbackServer.name}');
            return fallbackConfig;
          }
        }
      }
      
      // No real VPS available — use WARP servers (random shuffle)
      final warpServers = _servers.where((s) => !s.isRealVps).toList();
      if (warpServers.isNotEmpty) {
        warpServers.shuffle(Random());
        for (final server in warpServers) {
          final config = await generateConfigForServer(server);
          if (config != null) {
            _logger.i('Selected WARP server: ${server.name}');
            return config;
          }
        }
      }
      
      // Last resort: try fallback WARP servers
      if (_fallbackServers.isNotEmpty) {
        _logger.w('Primary servers exhausted, trying WARP fallbacks...');
        for (final server in _fallbackServers) {
          final config = await generateConfigForServer(server);
          if (config != null) {
            _logger.i('Using WARP fallback: ${server.name}');
            return config;
          }
        }
      }

      _logger.w('No suitable server found');
      return null;
      
    } catch (e, stack) {
      _logger.e('Failed to auto-select server', error: e, stackTrace: stack);
      return null;
    }
  }
  
  /// Check if we have real VPS servers configured
  bool get hasRealVpsServers => _servers.any((s) => s.isRealVps);
  
  /// Get real VPS server count
  int get realVpsCount => _servers.where((s) => s.isRealVps).length;

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
      
      // Create updated server (immutable) preserving VPS fields
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
        publicKey: _servers[i].publicKey,
        clientPrivateKey: _servers[i].clientPrivateKey,
        clientAddress: _servers[i].clientAddress,
        presharedKey: _servers[i].presharedKey,
        dns: _servers[i].dns,
        provider: _servers[i].provider,
      );
    }
    
    _logger.d('Updated server load information');
  }

  /// Get user location for distance calculation
  /// Uses cached location if available, with generous timeout and fallback
  Future<void> _updateUserLocation() async {
    // Use cached location if we already have one (avoid repeated requests)
    if (_userLocation != null) return;
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w('Location services disabled, using last known or default');
        await _tryLastKnownLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logger.w('Location permission denied, using default location');
          _useDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logger.w('Location permissions permanently denied, using default');
        _useDefaultLocation();
        return;
      }

      // Try to get last known position first (instant, no timeout)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _userLocation = lastKnown;
          _logger.d('Using last known location: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return;
        }
      } catch (_) {}

      // If no cached location, get current with generous timeout
      _userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      );
      
      _logger.d('Updated user location: ${_userLocation?.latitude}, ${_userLocation?.longitude}');
      
    } catch (e, stack) {
      _logger.w('Failed to get user location, using default', error: e, stackTrace: stack);
      _useDefaultLocation();
    }
  }

  /// Try to get last known location as fallback
  Future<void> _tryLastKnownLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _userLocation = lastKnown;
        _logger.d('Using last known location: ${lastKnown.latitude}, ${lastKnown.longitude}');
        return;
      }
    } catch (_) {}
    _useDefaultLocation();
  }

  /// Use a default location (India/Mumbai) when geolocation is unavailable
  /// This ensures servers are at least sorted by some reference point
  void _useDefaultLocation() {
    if (_userLocation != null) return; // Don't override if we already have one
    // Default to India (most users)
    _userLocation = Position(
      latitude: 20.5937,
      longitude: 78.9629,
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: DateTime.now(),
    );
    _logger.d('Using default location (India) for server sorting');
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

// VpnConfig.copyWith is now defined in the VpnConfig class itself (vpn_config.dart)