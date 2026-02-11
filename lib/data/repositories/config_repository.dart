import 'package:logger/logger.dart';
import '../storage/secure_storage.dart';
import '../models/vpn_config.dart';
import '../models/proxy_config.dart';
import '../../core/constants/app_constants.dart';

class ConfigRepository {
  static final ConfigRepository _instance = ConfigRepository._internal();
  factory ConfigRepository() => _instance;
  ConfigRepository._internal();

  final SecureStorage _storage = SecureStorage();
  final Logger _logger = Logger();
  
  List<VpnConfig> _vpnConfigs = [];
  List<ProxyConfig> _proxyConfigs = [];
  bool _initialized = false;
  
  /// Initialize repository
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _storage.initialize();
    await _loadConfigs();
    _initialized = true;
    
    _logger.i('Config repository initialized');
  }
  
  /// Load all configurations from secure storage
  Future<void> _loadConfigs() async {
    try {
      // Load VPN configs
      final vpnData = await _storage.retrieveSecure(AppConstants.vpnConfigsKey);
      if (vpnData != null && vpnData['configs'] is List) {
        final configsList = vpnData['configs'] as List;
        _vpnConfigs = configsList
            .map((config) => VpnConfig.fromJson(config as Map<String, dynamic>))
            .toList();
        _logger.d('Loaded ${_vpnConfigs.length} VPN configurations');
      }
      
      // Load Proxy configs
      final proxyData = await _storage.retrieveSecure(AppConstants.proxyConfigsKey);
      if (proxyData != null && proxyData['configs'] is List) {
        final configsList = proxyData['configs'] as List;
        _proxyConfigs = configsList
            .map((config) => ProxyConfig.fromJson(config as Map<String, dynamic>))
            .toList();
        _logger.d('Loaded ${_proxyConfigs.length} Proxy configurations');
      }
    } catch (e, stack) {
      _logger.e('Failed to load configurations', error: e, stackTrace: stack);
      _vpnConfigs = [];
      _proxyConfigs = [];
    }
  }
  
  /// Save all VPN configs to secure storage
  Future<void> _saveVpnConfigs() async {
    try {
      final data = {
        'configs': _vpnConfigs.map((config) => config.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _storage.storeSecure(AppConstants.vpnConfigsKey, data);
      _logger.d('Saved ${_vpnConfigs.length} VPN configurations');
    } catch (e, stack) {
      _logger.e('Failed to save VPN configurations', error: e, stackTrace: stack);
      rethrow;
    }
  }
  
  /// Save all Proxy configs to secure storage
  Future<void> _saveProxyConfigs() async {
    try {
      final data = {
        'configs': _proxyConfigs.map((config) => config.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _storage.storeSecure(AppConstants.proxyConfigsKey, data);
      _logger.d('Saved ${_proxyConfigs.length} Proxy configurations');
    } catch (e, stack) {
      _logger.e('Failed to save Proxy configurations', error: e, stackTrace: stack);
      rethrow;
    }
  }
  
  // VPN Configuration Methods
  
  /// Get all VPN configurations
  Future<List<VpnConfig>> getAllVpnConfigs() async {
    await _ensureInitialized();
    return List.from(_vpnConfigs);
  }
  
  /// Add new VPN configuration
  Future<void> addVpnConfig(VpnConfig config) async {
    await _ensureInitialized();
    
    // Check for duplicates
    if (_vpnConfigs.any((c) => c.id == config.id)) {
      throw ArgumentError('Configuration with ID ${config.id} already exists');
    }
    
    _vpnConfigs.add(config);
    await _saveVpnConfigs();
    
    _logger.i('Added VPN config: ${config.name}');
  }
  
  /// Update VPN configuration
  Future<void> updateVpnConfig(VpnConfig config) async {
    await _ensureInitialized();
    
    final index = _vpnConfigs.indexWhere((c) => c.id == config.id);
    if (index == -1) {
      throw ArgumentError('Configuration with ID ${config.id} not found');
    }
    
    _vpnConfigs[index] = config;
    await _saveVpnConfigs();
    
    _logger.i('Updated VPN config: ${config.name}');
  }
  
  /// Remove VPN configuration
  Future<void> removeVpnConfig(String configId) async {
    await _ensureInitialized();
    
    final originalLength = _vpnConfigs.length;
    _vpnConfigs.removeWhere((c) => c.id == configId);
    
    if (_vpnConfigs.length == originalLength) {
      throw ArgumentError('Configuration with ID $configId not found');
    }
    
    await _saveVpnConfigs();
    _logger.i('Removed VPN config: $configId');
  }
  
  /// Get VPN configuration by ID
  Future<VpnConfig?> getVpnConfigById(String configId) async {
    await _ensureInitialized();
    
    try {
      return _vpnConfigs.firstWhere((c) => c.id == configId);
    } catch (e) {
      return null;
    }
  }
  
  // Proxy Configuration Methods
  
  /// Get all Proxy configurations
  Future<List<ProxyConfig>> getAllProxyConfigs() async {
    await _ensureInitialized();
    return List.from(_proxyConfigs);
  }
  
  /// Add new Proxy configuration
  Future<void> addProxyConfig(ProxyConfig config) async {
    await _ensureInitialized();
    
    // Check for duplicates
    if (_proxyConfigs.any((c) => c.id == config.id)) {
      throw ArgumentError('Configuration with ID ${config.id} already exists');
    }
    
    _proxyConfigs.add(config);
    await _saveProxyConfigs();
    
    _logger.i('Added Proxy config: ${config.name}');
  }
  
  /// Update Proxy configuration
  Future<void> updateProxyConfig(ProxyConfig config) async {
    await _ensureInitialized();
    
    final index = _proxyConfigs.indexWhere((c) => c.id == config.id);
    if (index == -1) {
      throw ArgumentError('Configuration with ID ${config.id} not found');
    }
    
    _proxyConfigs[index] = config;
    await _saveProxyConfigs();
    
    _logger.i('Updated Proxy config: ${config.name}');
  }
  
  /// Remove Proxy configuration
  Future<void> removeProxyConfig(String configId) async {
    await _ensureInitialized();
    
    final originalLength = _proxyConfigs.length;
    _proxyConfigs.removeWhere((c) => c.id == configId);
    
    if (_proxyConfigs.length == originalLength) {
      throw ArgumentError('Configuration with ID $configId not found');
    }
    
    await _saveProxyConfigs();
    _logger.i('Removed Proxy config: $configId');
  }
  
  /// Get Proxy configuration by ID
  Future<ProxyConfig?> getProxyConfigById(String configId) async {
    await _ensureInitialized();
    
    try {
      return _proxyConfigs.firstWhere((c) => c.id == configId);
    } catch (e) {
      return null;
    }
  }
  
  /// Ensure repository is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
  
  /// Get configuration counts
  int get vpnConfigCount => _vpnConfigs.length;
  int get proxyConfigCount => _proxyConfigs.length;
  
  /// Clear all configurations
  Future<void> clearAllConfigs() async {
    await _ensureInitialized();
    
    _vpnConfigs.clear();
    _proxyConfigs.clear();
    
    await _saveVpnConfigs();
    await _saveProxyConfigs();
    
    _logger.w('All configurations cleared');
  }
}