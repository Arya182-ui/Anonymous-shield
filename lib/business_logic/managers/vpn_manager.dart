import 'dart:async';
import 'package:logger/logger.dart';
import '../../platform/channels/vpn_channel.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/connection_status.dart';
import '../../data/repositories/config_repository.dart';
import '../../core/constants/app_constants.dart';

class VpnManager {
  static final VpnManager _instance = VpnManager._internal();
  factory VpnManager() => _instance;
  VpnManager._internal();

  final VpnMethodChannel _vpnChannel = VpnMethodChannel();
  final ConfigRepository _configRepo = ConfigRepository();
  final Logger _logger = Logger();
  
  StreamController<ConnectionStatus>? _statusController;
  Stream<ConnectionStatus>? _statusStream;
  VpnConfig? _currentConfig;
  Timer? _rotationTimer;
  
  /// Initialize VPN manager
  Future<void> initialize() async {
    await _vpnChannel.initialize();
    await _configRepo.initialize();
    
    _statusController = StreamController<ConnectionStatus>.broadcast();
    _statusStream = _statusController!.stream;
    
    // Listen to native VPN status changes
    _vpnChannel.statusStream.listen((status) {
      _statusController?.add(status);
      _logger.d('VPN status update: ${status.vpnStatus}');
    });
    
    _logger.i('VPN Manager initialized');
  }
  
  /// Get status stream
  Stream<ConnectionStatus> get statusStream {
    _statusStream ??= _statusController!.stream;
    return _statusStream!;
  }
  
  /// Connect to VPN with configuration
  Future<bool> connect(VpnConfig config) async {
    try {
      _logger.i('Starting VPN connection to ${config.name}');
      
      // Check VPN permission first
      final hasPermission = await _vpnChannel.checkVpnPermission();
      if (!hasPermission) {
        _logger.w('VPN permission not granted, requesting...');
        final granted = await _vpnChannel.requestVpnPermission();
        if (!granted) {
          _logger.e('VPN permission denied by user');
          _statusController?.add(ConnectionStatus(
            vpnStatus: VpnStatus.error,
            lastErrorMessage: AppConstants.errorPermissionDenied,
            lastErrorAt: DateTime.now(),
          ));
          return false;
        }
      }
      
      // Update status to connecting
      _statusController?.add(ConnectionStatus(
        vpnStatus: VpnStatus.connecting,
        currentServerId: config.id,
        currentServerName: config.name,
      ));
      
      // Start VPN connection
      final success = await _vpnChannel.startVpn(config);
      
      if (success) {
        _currentConfig = config;
        
        // Update config last used time and save
        final updatedConfig = config.copyWith(
          lastUsedAt: DateTime.now(),
          isActive: true,
        );
        await _configRepo.updateVpnConfig(updatedConfig);
        
        _logger.i('VPN connection successful');
        return true;
      } else {
        _logger.e('VPN connection failed');
        _statusController?.add(ConnectionStatus(
          vpnStatus: VpnStatus.error,
          lastErrorMessage: AppConstants.errorConnectionFailed,
          lastErrorAt: DateTime.now(),
        ));
        return false;
      }
    } catch (e, stack) {
      _logger.e('VPN connection error', error: e, stackTrace: stack);
      _statusController?.add(ConnectionStatus(
        vpnStatus: VpnStatus.error,
        lastErrorMessage: e.toString(),
        lastErrorAt: DateTime.now(),
      ));
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
      
      // Update status to disconnecting
      _statusController?.add(ConnectionStatus(
        vpnStatus: VpnStatus.disconnecting,
      ));
      
      final success = await _vpnChannel.stopVpn();
      
      if (success) {
        // Update config active status
        if (_currentConfig != null) {
          final updatedConfig = _currentConfig!.copyWith(isActive: false);
          await _configRepo.updateVpnConfig(updatedConfig);
        }
        
        _currentConfig = null;
        _logger.i('VPN disconnected successfully');
        return true;
      } else {
        _logger.e('VPN disconnection failed');
        return false;
      }
    } catch (e, stack) {
      _logger.e('VPN disconnection error', error: e, stackTrace: stack);
      _statusController?.add(ConnectionStatus(
        vpnStatus: VpnStatus.error,
        lastErrorMessage: e.toString(),
        lastErrorAt: DateTime.now(),
      ));
      return false;
    }
  }
  
  /// Get current VPN status
  Future<ConnectionStatus> getStatus() async {
    try {
      return await _vpnChannel.getVpnStatus();
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
      return await _vpnChannel.enableKillSwitch();
    } catch (e) {
      _logger.e('Failed to enable kill switch', error: e);
      return false;
    }
  }
  
  /// Disable kill switch
  Future<bool> disableKillSwitch() async {
    try {
      return await _vpnChannel.disableKillSwitch();
    } catch (e) {
      _logger.e('Failed to disable kill switch', error: e);
      return false;
    }
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
    _statusController?.close();
    _vpnChannel.dispose();
  }
}