import 'package:logger/logger.dart';
import '../../data/services/built_in_server_service.dart';
import '../../data/services/free_vpn_provider.dart';
import '../../data/models/vpn_config.dart';
// Built-in server import handled by service
/// Automatic VPN Configuration Manager
/// यह service automatic server selection और configuration को handle करती है

class AutoVpnConfigManager {
  static final AutoVpnConfigManager _instance = AutoVpnConfigManager._internal();
  factory AutoVpnConfigManager() => _instance;
  AutoVpnConfigManager._internal();
  final Logger _logger = Logger();
  final BuiltInServerService _serverService = BuiltInServerService();
  final FreeVpnProvider _freeProvider = FreeVpnProvider();

  bool _isInitialized = false;
  bool _isInitializing = false;
  VpnConfig? _currentConfig;
  List<VpnConfig> _availableConfigs = [];
  /// Initialize the auto configuration manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      _logger.w('Initialization already in progress, waiting...');
      // Wait for initialization to complete
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;
    try {
      _logger.i('Initializing Auto VPN Configuration Manager...');

      // Load built-in servers
      await _serverService.loadBuiltInServers();

      // Pre-generate some free configs
      await _preGenerateConfigs();

      _isInitialized = true;
      _logger.i('Auto VPN Configuration Manager initialized successfully');

    } catch (e, stack) {
      _logger.e('Failed to initialize Auto VPN Configuration Manager', 
                error: e, stackTrace: stack);
      throw Exception('Initialization failed: $e');
    } finally {
      _isInitializing = false;
    }
  }
  /// Get the best available VPN configuration automatically
  /// यह function automatically best server select करके config return करता है
  Future<VpnConfig?> getBestAvailableConfig() async {
    await _ensureInitialized();

    try {
      _logger.i('Finding best available VPN configuration...');

      // 1. Try auto-selection based on location and performance
      final autoSelected = await _serverService.autoSelectBestServer();
      if (autoSelected != null) {
        _currentConfig = autoSelected;
        _logger.i('Auto-selected server: ${autoSelected.name}');
        return autoSelected;
      }

      // 2. Try Cloudflare WARP (best free option)
      final warpConfig = await _freeProvider.generateWarpConfig();
      if (warpConfig != null) {
        _currentConfig = warpConfig;
        _logger.i('Generated Cloudflare WARP configuration');
        return warpConfig;
      }

      // 3. Use pre-generated configs
      if (_availableConfigs.isNotEmpty) {
        _currentConfig = _availableConfigs.first;
        _logger.i('Using pre-generated config: ${_currentConfig!.name}');
        return _currentConfig;
      }

      _logger.w('No VPN configurations available');
      return null;

    } catch (e, stack) {
      _logger.e('Failed to get best config', error: e, stackTrace: stack);
      return null;
    }
  }
  /// Get multiple VPN configurations for rotation
  Future<List<VpnConfig>> getMultipleConfigs({int count = 5}) async {
    await _ensureInitialized();
    return _getMultipleConfigsInternal(count: count);
  }

  /// Internal method to get multiple configs (used during initialization)
  Future<List<VpnConfig>> _getMultipleConfigsInternal({int count = 5}) async {
    try {
      _logger.i('Getting multiple VPN configurations...');

      final configs = <VpnConfig>[];

      // 1. Try to get WARP configurations (with better error handling)
      try {
        final warpConfigs = await _freeProvider.getMultipleWarpConfigs(count: 2);
        configs.addAll(warpConfigs);
        _logger.d('Successfully added ${warpConfigs.length} WARP configurations');
      } catch (e) {
        _logger.w('WARP configuration failed, continuing with built-in servers: $e');
        // Continue without WARP configs - this is not critical for app functionality
      }

      // 2. Get built-in server configurations (prioritize these as they're more reliable)
      try {
        final serverConfigs = await _serverService.getMultipleFreeConfigs(limit: count - configs.length);
        configs.addAll(serverConfigs);
        _logger.d('Successfully added ${serverConfigs.length} built-in server configurations');
      } catch (e) {
        _logger.w('Built-in server configuration failed: $e');
      }

      // 3. Add additional free provider configs if needed
      if (configs.length < count) {
        try {
          final additionalConfigs = await _freeProvider.getFreeVpnConfigs();
          configs.addAll(additionalConfigs.take(count - configs.length));
          _logger.d('Added ${additionalConfigs.length} additional free configurations');
        } catch (e) {
          _logger.w('Additional free provider configs failed: $e');
        }
      }

      _availableConfigs = configs;
      _logger.i('Successfully generated ${configs.length} VPN configurations');
      return configs;

    } catch (e, stack) {
      _logger.e('Failed to get multiple configs', error: e, stackTrace: stack);
      // Return empty list but don't fail initialization
      return [];
    }
  }
  /// Get configuration for specific country
  Future<VpnConfig?> getConfigForCountry(String countryCode) async {
    await _ensureInitialized();

    try {
      _logger.i('Getting VPN configuration for country: $countryCode');

      // Try built-in servers first
      final servers = _serverService.getServersByCountry(countryCode);

      for (final server in servers) {
        final config = await _serverService.generateConfigForServer(server);
        if (config != null) {
          _logger.i('Found config for $countryCode: ${server.name}');
          return config;
        }
      }

      // If no built-in servers, try general configs
      return await getBestAvailableConfig();

    } catch (e, stack) {
      _logger.e('Failed to get config for country $countryCode', 
                error: e, stackTrace: stack);
      return null;
    }
  }
  /// Get configuration optimized for streaming
  Future<VpnConfig?> getStreamingOptimizedConfig() async {
    await _ensureInitialized();

    try {
      _logger.i('Getting streaming-optimized VPN configuration...');

      // Get recommended servers (usually fastest)
      final recommended = await _serverService.getRecommendedServers(limit: 3);

      // Try each recommended server
      for (final server in recommended) {
        if (server.maxSpeedMbps >= 100) { // Prefer high-speed servers
          final config = await _serverService.generateConfigForServer(server);
          if (config != null) {
            _logger.i('Found streaming config: ${server.name} (${server.maxSpeedMbps} Mbps)');
            return config;
          }
        }
      }

      // Fallback to WARP (usually good for streaming)
      return await _freeProvider.generateWarpConfig();

    } catch (e, stack) {
      _logger.e('Failed to get streaming config', error: e, stackTrace: stack);
      return null;
    }
  }
  /// Simple one-click connect
  /// यह function users को simply one click में best server से connect करने देता है
  Future<bool> oneClickConnect() async {
    try {
      _logger.i('Starting one-click connect...');

      final config = await getBestAvailableConfig();

      if (config == null) {
        _logger.w('No suitable configuration found for one-click connect');
        return false;
      }

      // यहाँ आप अपने VPN connection logic को call करेंगे
      // Example: await vpnManager.connect(config);

      _currentConfig = config;
      _logger.i('One-click connect successful: ${config.name}');
      return true;

    } catch (e, stack) {
      _logger.e('One-click connect failed', error: e, stackTrace: stack);
      return false;
    }
  }
  /// Rotate to next available server
  Future<VpnConfig?> rotateToNextServer() async {
    await _ensureInitialized();

    try {
      if (_availableConfigs.isEmpty) {
        await getMultipleConfigs();
      }

      if (_availableConfigs.isEmpty) {
        return await getBestAvailableConfig();
      }

      // Find current config index
      int currentIndex = 0;
      if (_currentConfig != null) {
        currentIndex = _availableConfigs.indexWhere((c) => c.id == _currentConfig!.id);
        if (currentIndex == -1) currentIndex = 0;
      }

      // Move to next config
      final nextIndex = (currentIndex + 1) % _availableConfigs.length;
      _currentConfig = _availableConfigs[nextIndex];

      _logger.i('Rotated to next server: ${_currentConfig!.name}');
      return _currentConfig;

    } catch (e, stack) {
      _logger.e('Failed to rotate server', error: e, stackTrace: stack);
      return null;
    }
  }
  /// Get server statistics and recommendations
  Map<String, dynamic> getServerStats() {
    final stats = _serverService.getServerStats();
    stats['available_configs'] = _availableConfigs.length;
    stats['current_config'] = _currentConfig?.name ?? 'None';
    stats['auto_management'] = 'Enabled';

    return stats;
  }
  /// Reset and refresh all configurations
  Future<void> refreshConfigurations() async {
    try {
      _logger.i('Refreshing all VPN configurations...');

      _availableConfigs.clear();
      _currentConfig = null;

      // Reload servers
      await _serverService.loadBuiltInServers();

      // Update server loads
      _serverService.updateServerLoads();

      // Pre-generate new configs
      await _preGenerateConfigs();

      _logger.i('Configuration refresh completed');

    } catch (e, stack) {
      _logger.e('Failed to refresh configurations', error: e, stackTrace: stack);
    }
  }
  /// Private helper methods
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      if (_isInitializing) {
        _logger.w('Initialization in progress, waiting...');
        // Wait for initialization to complete
        while (_isInitializing && !_isInitialized) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      } else {
        await initialize();
      }
    }
  }
  Future<void> _preGenerateConfigs() async {
    try {
      _logger.d('Pre-generating VPN configurations...');
      // Generate a few configs to have them ready (using internal method)
      final configs = await _getMultipleConfigsInternal(count: 3);
      _availableConfigs = configs;

      if (configs.isEmpty) {
        _logger.w('No configurations were pre-generated, but initialization will continue');
      } else {
        _logger.d('Pre-generated ${configs.length} configurations successfully');
      }

    } catch (e, stack) {
      _logger.w('Failed to pre-generate configs, but initialization will continue', 
                error: e, stackTrace: stack);
      // Don't throw - allow initialization to complete even if pre-generation fails
      _availableConfigs = [];
    }
  }
  // Getters
  VpnConfig? get currentConfig => _currentConfig;
  List<VpnConfig> get availableConfigs => List.unmodifiable(_availableConfigs);
  bool get isInitialized => _isInitialized;

  /// Clean up resources
  void dispose() {
    _availableConfigs.clear();
    _currentConfig = null;
    _isInitialized = false;
    _isInitializing = false;
  }
}