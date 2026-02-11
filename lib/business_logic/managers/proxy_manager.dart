import 'dart:async';
import 'package:logger/logger.dart';
import '../../platform/channels/proxy_channel.dart';
import '../../data/models/proxy_config.dart';
import '../../data/models/connection_status.dart';
import '../../data/repositories/config_repository.dart';
import '../../core/constants/app_constants.dart';

class ProxyManager {
  static final ProxyManager _instance = ProxyManager._internal();
  factory ProxyManager() => _instance;
  ProxyManager._internal();

  final ProxyMethodChannel _proxyChannel = ProxyMethodChannel();
  final ConfigRepository _configRepo = ConfigRepository();
  final Logger _logger = Logger();
  
  StreamController<ProxyStatus>? _statusController;
  Stream<ProxyStatus>? _statusStream;
  List<ProxyConfig> _activeProxies = [];
  Timer? _heartbeatTimer;
  
  /// Initialize proxy manager
  Future<void> initialize() async {
    await _proxyChannel.initialize();
    await _configRepo.initialize();
    
    _statusController = StreamController<ProxyStatus>.broadcast();
    _statusStream = _statusController!.stream;
    
    // Listen to native proxy status changes
    _proxyChannel.statusStream.listen((status) {
      _statusController?.add(status);
      _logger.d('Proxy status update: $status');
    });
    
    _logger.i('Proxy Manager initialized');
  }
  
  /// Get proxy status stream
  Stream<ProxyStatus> get statusStream {
    _statusStream ??= _statusController!.stream;
    return _statusStream!;
  }
  
  /// Start single proxy connection
  Future<bool> startProxy(ProxyConfig config) async {
    try {
      _logger.i('Starting proxy connection: ${config.name}');
      
      // Update status to connecting
      _statusController?.add(ProxyStatus.enabled);
      
      // Start proxy connection
      final success = await _proxyChannel.startProxy(config);
      
      if (success) {
        _activeProxies = [config];
        
        // Update config last used time and save
        final updatedConfig = config.copyWith(
          lastUsedAt: DateTime.now(),
          isEnabled: true,
        );
        await _configRepo.updateProxyConfig(updatedConfig);
        
        _logger.i('Proxy connection successful: ${config.type.name}');
        return true;
      } else {
        _logger.e('Proxy connection failed: ${config.name}');
        _statusController?.add(ProxyStatus.error);
        return false;
      }
    } catch (e, stack) {
      _logger.e('Proxy connection error', error: e, stackTrace: stack);
      _statusController?.add(ProxyStatus.error);
      return false;
    }
  }
  
  /// Start proxy chain (multiple proxies)
  Future<bool> startProxyChain(List<ProxyConfig> proxyChain) async {
    try {
      _logger.i('Starting proxy chain with ${proxyChain.length} hops');
      
      // Clear any existing connections
      await stopAllProxies();
      
      // Connect to each proxy in sequence
      for (int i = 0; i < proxyChain.length; i++) {
        final proxy = proxyChain[i];
        _logger.i('Connecting hop ${i + 1}: ${proxy.name}');
        
        final success = await _connectSingleProxy(proxy);
        if (!success) {
          _logger.e('Failed to connect to proxy ${proxy.name}');
          
          // Cleanup any partial connections
          await stopAllProxies();
          return false;
        }
        
        // Add delay between connections for stability
        if (i < proxyChain.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      
      _activeProxies = List.from(proxyChain);
      
      // Start heartbeat monitoring
      _startHeartbeat();
      
      _logger.i('Proxy chain established successfully');
      return true;
      
    } catch (e, stack) {
      _logger.e('Proxy chain setup failed', error: e, stackTrace: stack);
      await stopAllProxies();
      return false;
    }
  }
  
  /// Test proxy connection without establishing it
  Future<bool> testProxy(ProxyConfig config) async {
    try {
      _logger.i('Testing proxy: ${config.name}');
      return await _proxyChannel.testProxy(config);
    } catch (e) {
      _logger.e('Proxy test failed', error: e);
      return false;
    }
  }
  
  /// Stop all proxy connections
  Future<bool> stopAllProxies() async {
    try {
      _logger.i('Stopping all proxy connections');
      
      // Stop heartbeat monitoring
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      
      final success = await _proxyChannel.stopProxy();
      
      if (success) {
        // Update all active configs
        for (final proxy in _activeProxies) {
          final updatedConfig = proxy.copyWith(isEnabled: false);
          await _configRepo.updateProxyConfig(updatedConfig);
        }
        
        _activeProxies.clear();
        _statusController?.add(ProxyStatus.disabled);
        _logger.i('All proxies stopped successfully');
        return true;
      } else {
        _logger.e('Failed to stop proxies');
        return false;
      }
    } catch (e, stack) {
      _logger.e('Error stopping proxies', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Rotate proxy chain (change to new servers)
  Future<bool> rotateProxyChain() async {
    if (_activeProxies.isEmpty) return false;
    
    try {
      _logger.i('Rotating proxy chain');
      
      // Get available proxy configs
      final allProxies = await _configRepo.getAllProxyConfigs();
      final availableProxies = allProxies
          .where((p) => !_activeProxies.any((active) => active.id == p.id))
          .toList();
      
      if (availableProxies.length < _activeProxies.length) {
        _logger.w('Not enough alternative proxies for rotation');
        return false;
      }
      
      // Create new proxy chain with same structure but different servers
      final newChain = <ProxyConfig>[];
      for (int i = 0; i < _activeProxies.length; i++) {
        final currentRole = _activeProxies[i].role;
        final sameRoleProxies = availableProxies
            .where((p) => p.role == currentRole)
            .toList();
        
        if (sameRoleProxies.isNotEmpty) {
          final randomProxy = sameRoleProxies[
              DateTime.now().millisecond % sameRoleProxies.length
          ];
          newChain.add(randomProxy);
        } else {
          // Fallback to any available proxy
          final randomProxy = availableProxies[
              DateTime.now().millisecond % availableProxies.length
          ];
          newChain.add(randomProxy);
        }
      }
      
      // Stop current chain and start new one
      await stopAllProxies();
      await Future.delayed(Duration(seconds: 2)); // Brief pause
      return await startProxyChain(newChain);
      
    } catch (e, stack) {
      _logger.e('Proxy rotation failed', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Get current proxy status
  Future<ProxyStatus> getStatus() async {
    try {
      return await _proxyChannel.getProxyStatus();
    } catch (e) {
      _logger.e('Failed to get proxy status', error: e);
      return ProxyStatus.error;
    }
  }
  
  /// Private helper to connect single proxy
  Future<bool> _connectSingleProxy(ProxyConfig config) async {
    try {
      return await _proxyChannel.startProxy(config);
    } catch (e) {
      _logger.e('Failed to connect single proxy: ${config.name}', error: e);
      return false;
    }
  }
  
  /// Start heartbeat monitoring for proxy health
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkProxyHealth();
    });
  }
  
  /// Check health of active proxy connections
  Future<void> _checkProxyHealth() async {
    if (_activeProxies.isEmpty) return;
    
    try {
      // Test first proxy in chain as health indicator
      final testResult = await testProxy(_activeProxies.first);
      if (!testResult) {
        _logger.w('Proxy health check failed, may need rotation');
        _statusController?.add(ProxyStatus.error);
      }
    } catch (e) {
      _logger.e('Proxy health check error', error: e);
    }
  }
  
  /// Get active proxy configurations
  List<ProxyConfig> get activeProxies => List.unmodifiable(_activeProxies);
  
  /// Check if any proxies are active
  bool get hasActiveProxies => _activeProxies.isNotEmpty;
  
  /// Get proxy chain hop count
  int get hopCount => _activeProxies.length;
  
  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusController?.close();
  }
}