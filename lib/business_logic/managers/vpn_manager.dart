import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../platform/channels/vpn_method_channel.dart';
import '../../platform/channels/anonymous_method_channel.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/connection_status.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/repositories/config_repository.dart';
// import '../../core/constants/app_constants.dart';

/// Enhanced VPN Manager with Native Service Integration
class VpnManager {
  static final VpnManager _instance = VpnManager._internal();
  factory VpnManager() => _instance;
  VpnManager._internal();

  final ConfigRepository _configRepo = ConfigRepository();
  final Logger _logger = Logger();
  
  StreamController<ConnectionStatus>? _statusController;
  Stream<ConnectionStatus>? _statusStream;
  VpnConfig? _currentConfig;
  AnonymousChain? _currentChain;
  Timer? _rotationTimer;
  Timer? _statusUpdateTimer;
  
  bool _isInitialized = false;
  
  /// Initialize VPN manager with native channel setup
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _configRepo.initialize();
      
      _statusController = StreamController<ConnectionStatus>.broadcast();
      _statusStream = _statusController!.stream;
      
      // Set up native method call handlers
      VpnMethodChannel.setMethodCallHandler(_handleVpnMethodCallWrapper);
      AnonymousMethodChannel.setMethodCallHandler(_handleAnonymousMethodCallWrapper);
      
      // Start periodic status updates
      _startStatusUpdates();
      
      _isInitialized = true;
      _logger.i('Enhanced VPN Manager initialized with native integration');
      
    } catch (e) {
      _logger.e('Failed to initialize VPN Manager: $e');
      rethrow;
    }
  }
  
  /// Get status stream
  Stream<ConnectionStatus> get statusStream {
    _statusStream ??= _statusController!.stream;
    return _statusStream!;
  }
  
  /// Connect to VPN with native service
  Future<bool> connect(VpnConfig config) async {
    try {
      _logger.i('Starting VPN connection to ${config.name}');
      
      // Check VPN permission first
      final permissionResult = await VpnMethodChannel.requestVpnPermission();
      if (permissionResult['permissionRequired'] == true) {
        _logger.w('VPN permission required');
        return false;
      }
      
      // Start VPN through native service
      final result = await VpnMethodChannel.startVpn(config);
      
      if (result['success'] == true) {
        _currentConfig = config;
        
        // Start server rotation if enabled
        if (config.autoRotate) {
          _startRotationTimer(config.rotationInterval);
        }
        
        _logger.i('VPN connection successful: ${config.name}');
        return true;
      } else {
        _logger.e('VPN connection failed: ${result['error']}');
        return false;
      }
      
    } catch (e) {
      _logger.e('Failed to connect to VPN: $e');
      return false;
    }
  }

  /// Connect with anonymous chain (Ghost/Stealth/Paranoid modes)
  Future<bool> connectWithChain(AnonymousChain chain) async {
    try {
      _logger.i('Starting anonymous chain: ${chain.mode} with ${chain.hopCount} hops');
      
      // Check VPN permission
      final permissionResult = await VpnMethodChannel.requestVpnPermission();
      if (permissionResult['permissionRequired'] == true) {
        _logger.w('VPN permission required for anonymous chain');
        return false;
      }
      
      // Start anonymous chain through native service
      final result = await VpnMethodChannel.startAnonymousChain(chain);
      
      if (result['success'] == true) {
        _currentChain = chain;
        
        // Start automatic rotation if enabled
        if (chain.autoRotate) {
          _startRotationTimer(chain.rotationInterval ?? Duration(minutes: 10));
        }
        
        _logger.i('Anonymous chain connected: ${chain.mode}');
        return true;
      } else {
        _logger.e('Anonymous chain connection failed: ${result['error']}');
        return false;
      }
      
    } catch (e) {
      _logger.e('Failed to start anonymous chain: $e');
      return false;
    }
  }

  /// Disconnect VPN
  Future<bool> disconnect() async {
    try {
      _logger.i('Disconnecting VPN');
      
      // Stop rotation timer
      _rotationTimer?.cancel();
      _rotationTimer = null;
      
      // Disconnect through native service
      final result = await VpnMethodChannel.stopVpn();
      
      if (result['success'] == true) {
        _currentConfig = null;
        _currentChain = null;
        _logger.i('VPN disconnected successfully');
        return true;
      } else {
        _logger.e('VPN disconnect failed: ${result['error']}');
        return false;
      }
      
    } catch (e) {
      _logger.e('Failed to disconnect VPN: $e');
      return false;
    }
  }
        
  /// Get current VPN status
  Future<ConnectionStatus> getStatus() async {
    try {
      final result = await VpnMethodChannel.getVpnStatus();
      return result;
    } catch (e) {
      _logger.e('Failed to get VPN status', error: e);
      return ConnectionStatus(
        vpnStatus: VpnStatus.error,
        lastErrorMessage: e.toString(),
      );
    }
  }
  
  /// Enable kill switch
  Future<bool> enableKillSwitch() async {
    try {
      final result = await VpnMethodChannel.enableKillSwitch(true);
      return result['success'] ?? false;
    } catch (e) {
      _logger.e('Failed to enable kill switch', error: e);
      return false;
    }
  }
  
  /// Disable kill switch
  Future<bool> disableKillSwitch() async {
    try {
      final result = await VpnMethodChannel.enableKillSwitch(false);
      return result['success'] ?? false;
    } catch (e) {
      _logger.e('Failed to disable kill switch', error: e);
      return false;
    }
  }

  /// Missing method implementations
  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await getStatus();
        _statusController?.add(status);
      } catch (e) {
        _logger.w('Status update failed: $e');
      }
    });
  }

  void _startRotationTimer(Duration interval) {
    _rotationTimer?.cancel();
    
    _rotationTimer = Timer.periodic(interval, (timer) async {
      if (_currentConfig != null || _currentChain != null) {
        _logger.i('Auto-rotating connection');
        await _performRotation();
      }
    });
    
    _logger.i('Auto-rotation started with ${interval.inMinutes}min interval');
  }

  Future<void> _performRotation() async {
    try {
      if (_currentChain != null) {
        // Rotate anonymous chain
        await AnonymousMethodChannel.forceChainRotation();
      } else if (_currentConfig != null) {
        // Rotate VPN server
        final configs = await _configRepo.getAllVpnConfigs();
        final availableConfigs = configs.where((c) => c.id != _currentConfig!.id && c.isActive).toList();
        
        if (availableConfigs.isNotEmpty) {
          final randomConfig = availableConfigs[DateTime.now().millisecond % availableConfigs.length];
          await disconnect();
          await Future.delayed(Duration(seconds: 2));
          await connect(randomConfig);
        }
      }
    } catch (e) {
      _logger.e('Rotation failed: $e');
    }
  }

  Future<void> _handleVpnMethodCall(String method, dynamic arguments) async {
    _logger.d('Received VPN method call: $method');
    
    switch (method) {
      case 'onStatusChanged':
        final status = ConnectionStatus.fromMap(arguments);
        _statusController?.add(status);
        break;
      case 'onError':
        final errorStatus = ConnectionStatus(
          vpnStatus: VpnStatus.error,
          lastErrorMessage: arguments['error'],
          lastErrorAt: DateTime.now(),
        );
        _statusController?.add(errorStatus);
        break;
      default:
        _logger.w('Unknown VPN method call: $method');
    }
  }

  /// Wrapper for MethodCall-based handler
  Future<dynamic> _handleVpnMethodCallWrapper(MethodCall call) async {
    await _handleVpnMethodCall(call.method, call.arguments);
  }

  Future<void> _handleAnonymousMethodCall(String method, dynamic arguments) async {
    _logger.d('Received Anonymous method call: $method');
    
    switch (method) {
      case 'onChainStatusChanged':
        // Handle anonymous chain status updates
        _logger.i('Chain status changed: ${arguments['status']}');
        break;
      case 'onRotationCompleted':
        _logger.i('Chain rotation completed');
        break;
      default:
        _logger.w('Unknown Anonymous method call: $method');
    }
  }

  /// Wrapper for MethodCall-based handler
  Future<dynamic> _handleAnonymousMethodCallWrapper(MethodCall call) async {
    await _handleAnonymousMethodCall(call.method, call.arguments);
  }
  
  /// Start server rotation
  void startAutoRotation(Duration interval) {
    _rotationTimer?.cancel();
    
    _rotationTimer = Timer.periodic(interval, (timer) async {
      if (_currentConfig != null) {
        _logger.i('Auto-rotating VPN server');
        
        // Get available configs
        final configs = await _configRepo.getAllVpnConfigs();
        final availableConfigs = configs.where((c) => c.id != _currentConfig!.id).toList();
        
        if (availableConfigs.isNotEmpty) {
          // Select random config for rotation
          final randomConfig = availableConfigs[DateTime.now().millisecond % availableConfigs.length];
          
          // Disconnect current and connect to new
          await disconnect();
          await Future.delayed(Duration(seconds: 2)); // Brief pause
          await connect(randomConfig);
          
          _statusController?.add(ConnectionStatus(
            lastRotationAt: DateTime.now(),
            nextRotationAt: DateTime.now().add(interval),
          ));
        }
      }
    });
    
    _logger.i('Auto-rotation started with ${interval.inMinutes}min interval');
  }
  
  /// Stop server rotation
  void stopAutoRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _logger.i('Auto-rotation stopped');
  }
  
  /// Get current configuration
  VpnConfig? get currentConfig => _currentConfig;
  
  /// Dispose resources
  void dispose() {
    _rotationTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _statusController?.close();
    _isInitialized = false;
  }
}