import 'dart:async';
import 'package:logger/logger.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_platform_interface.dart';
import '../../data/models/vpn_config.dart';

/// WireGuard VPN Service - Uses wireguard_flutter_plus plugin directly
/// यह service WireGuard VPN connections को manage करती है
class WireGuardVpnService {
  static final WireGuardVpnService _instance = WireGuardVpnService._internal();
  factory WireGuardVpnService() => _instance;
  WireGuardVpnService._internal();

  final Logger _logger = Logger();
  WireGuardFlutterInterface? _wireGuard;
  
  bool _isInitialized = false;
  VpnConfig? _currentConfig;
  
  StreamController<VpnStage>? _stageController;
  StreamSubscription? _stageSubscription;

  /// Initialize the WireGuard service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _logger.i('Initializing WireGuard VPN Service');
      
      // Get the WireGuard instance
      _wireGuard = WireGuardFlutter.instance;
      
      await _wireGuard!.initialize(
        interfaceName: 'wg0',
        vpnName: 'Privacy VPN',
      );
      
      _stageController = StreamController<VpnStage>.broadcast();
      
      // Listen to VPN stage changes
      _stageSubscription = _wireGuard!.vpnStageSnapshot.listen(
        (stage) {
          _logger.d('VPN Stage changed: $stage');
          _stageController?.add(stage);
        },
        onError: (error) {
          _logger.e('VPN stage error: $error');
        },
      );
      
      _isInitialized = true;
      _logger.i('WireGuard VPN Service initialized successfully');
      return true;
      
    } catch (e) {
      _logger.e('Failed to initialize WireGuard VPN Service: $e');
      return false;
    }
  }

  /// Get VPN stage stream
  Stream<VpnStage> get stageStream {
    if (!_isInitialized || _stageController == null) {
      throw StateError('WireGuard service not initialized');
    }
    return _stageController!.stream;
  }

  /// Get current VPN stage
  Future<VpnStage> get currentStage async {
    if (!_isInitialized || _wireGuard == null) return VpnStage.disconnected;
    return await _wireGuard!.stage();
  }

  /// Check if VPN is connected
  Future<bool> get isConnected async {
    final stage = await currentStage;
    return stage == VpnStage.connected;
  }

  /// Get current config
  VpnConfig? get currentConfig => _currentConfig;

  /// Connect to VPN using VpnConfig
  Future<bool> connect(VpnConfig config) async {
    if (!_isInitialized) {
      _logger.e('WireGuard service not initialized');
      return false;
    }
    
    try {
      _logger.i('Connecting to VPN: ${config.name}');
      
      // Check permission first
      final hasPermission = await _wireGuard!.checkVpnPermission();
      if (!hasPermission) {
        _logger.w('VPN permission not granted');
        // The plugin should request permission automatically
      }
      
      // Generate wg-quick config string
      final wgQuickConfig = _generateWgQuickConfig(config);
      
      _logger.d('WireGuard config:\n$wgQuickConfig');
      
      // Start VPN
      await _wireGuard!.startVpn(
        serverAddress: '${config.serverAddress}:${config.port}',
        wgQuickConfig: wgQuickConfig,
        providerBundleIdentifier: 'com.privacyvpn.privacy_vpn_controller',
      );
      
      _currentConfig = config;
      _logger.i('VPN connection initiated for ${config.name}');
      
      // Wait a bit and check the stage
      await Future.delayed(const Duration(seconds: 2));
      final stage = await _wireGuard!.stage();
      
      if (stage == VpnStage.connected || stage == VpnStage.connecting) {
        _logger.i('VPN connected successfully');
        return true;
      } else {
        _logger.w('VPN connection status: $stage');
        return stage != VpnStage.disconnected;
      }
      
    } catch (e) {
      _logger.e('Failed to connect VPN: $e');
      _currentConfig = null;
      return false;
    }
  }

  /// Disconnect VPN
  Future<bool> disconnect() async {
    if (!_isInitialized) return true;
    
    try {
      _logger.i('Disconnecting VPN');
      
      await _wireGuard!.stopVpn();
      _currentConfig = null;
      
      _logger.i('VPN disconnected');
      return true;
      
    } catch (e) {
      _logger.e('Failed to disconnect VPN: $e');
      return false;
    }
  }

  /// Get traffic statistics
  Future<Map<String, dynamic>> getTrafficStats() async {
    if (!_isInitialized || _wireGuard == null) {
      return {'rxBytes': 0, 'txBytes': 0};
    }
    
    try {
      return await _wireGuard!.trafficStats();
    } catch (e) {
      _logger.e('Failed to get traffic stats: $e');
      return {'rxBytes': 0, 'txBytes': 0};
    }
  }

  /// Refresh VPN stage
  Future<void> refreshStage() async {
    if (_isInitialized && _wireGuard != null) {
      await _wireGuard!.refreshStage();
    }
  }

  /// Generate wg-quick format config
  String _generateWgQuickConfig(VpnConfig config) {
    final buffer = StringBuffer();
    
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = ${config.privateKey}');
    
    // Add Address (client IP)
    if (config.clientIpv4 != null && config.clientIpv4!.isNotEmpty) {
      buffer.writeln('Address = ${config.clientIpv4}/32');
    } else {
      buffer.writeln('Address = 10.0.0.2/32');
    }
    
    if (config.dnsServers.isNotEmpty) {
      buffer.writeln('DNS = ${config.dnsServers.join(', ')}');
    }
    
    if (config.mtu != null) {
      buffer.writeln('MTU = ${config.mtu}');
    }
    
    buffer.writeln();
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = ${config.publicKey}');
    
    if (config.presharedKey != null && config.presharedKey!.isNotEmpty) {
      buffer.writeln('PresharedKey = ${config.presharedKey}');
    }
    
    buffer.writeln('Endpoint = ${config.serverAddress}:${config.port}');
    buffer.writeln('AllowedIPs = ${config.allowedIPs.join(', ')}');
    buffer.writeln('PersistentKeepalive = 25');
    
    return buffer.toString();
  }

  /// Dispose resources
  void dispose() {
    _stageSubscription?.cancel();
    _stageController?.close();
    _isInitialized = false;
  }
}
