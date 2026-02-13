import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';
import '../../platform/channels/vpn_method_channel.dart';
import '../../platform/channels/anonymous_method_channel.dart';
import '../../platform/services/wireguard_vpn_service.dart';
import '../../data/models/vpn_config.dart';
import '../../data/models/proxy_config.dart';
import '../../data/models/connection_status.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/enhanced_vpn_models.dart';
import '../../data/repositories/config_repository.dart';

/// Enhanced VPN Manager with Real Native Service Integration
/// यह real Android VPN service के साथ communicate करता है
class EnhancedVpnManager {
  static final EnhancedVpnManager _instance = EnhancedVpnManager._internal();
  factory EnhancedVpnManager() => _instance;
  EnhancedVpnManager._internal();

  final ConfigRepository _configRepo = ConfigRepository();
  final Logger _logger = Logger();
  final WireGuardVpnService _wireGuardService = WireGuardVpnService();
  
  StreamController<ConnectionStatus>? _statusController;
  StreamController<VpnConnectionStatus>? _vpnStatusController;
  StreamController<VpnConnectionInfo>? _connectionInfoController;
  Stream<ConnectionStatus>? _statusStream;
  Stream<VpnConnectionStatus>? _vpnStatusStream;
  Stream<VpnConnectionInfo>? _connectionInfoStream;
  VpnConfig? _currentConfig;
  AnonymousChain? _currentChain;
  Timer? _rotationTimer;
  Timer? _statusUpdateTimer;
  StreamSubscription? _wireGuardStageSubscription;
  
  bool _isInitialized = false;
  bool _isConnecting = false;
  
  /// Initialize VPN manager with native integration
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      await _configRepo.initialize();
      
      // Initialize WireGuard service
      await _wireGuardService.initialize();
      
      _statusController = StreamController<ConnectionStatus>.broadcast();
      _statusStream = _statusController!.stream;
      
      _vpnStatusController = StreamController<VpnConnectionStatus>.broadcast();
      _vpnStatusStream = _vpnStatusController!.stream;
      
      _connectionInfoController = StreamController<VpnConnectionInfo>.broadcast();
      _connectionInfoStream = _connectionInfoController!.stream;
      
      // Listen to WireGuard stage changes
      _wireGuardStageSubscription = _wireGuardService.stageStream.listen(_onWireGuardStageChanged);
      
      // Set up native method call handlers
      VpnMethodChannel.setMethodCallHandler(_handleVpnMethodCall);
      AnonymousMethodChannel.setMethodCallHandler(_handleAnonymousMethodCall);
      
      // Start periodic status updates
      _startStatusUpdates();
      
      _isInitialized = true;
      _logger.i('Enhanced VPN Manager initialized successfully');
      return true;
      
    } catch (e) {
      _logger.e('Failed to initialize Enhanced VPN Manager: $e');
      return false;
    }
  }

  /// Get legacy status stream (for compatibility)
  Stream<ConnectionStatus> get legacyStatusStream {
    if (!_isInitialized) {
      throw StateError('VPN Manager not initialized. Call initialize() first.');
    }
    return _statusStream!;
  }
  
  /// Get VPN connection status stream (main status stream)
  Stream<VpnConnectionStatus> get statusStream {
    if (!_isInitialized) {
      throw StateError('VPN Manager not initialized');
    }
    return _vpnStatusStream!;
  }

  /// Get connection info stream
  Stream<VpnConnectionInfo> get connectionInfoStream {
    if (!_isInitialized) {
      throw StateError('VPN Manager not initialized');
    }
    return _connectionInfoStream!;
  }
  /// Check if VPN is currently connected
  bool get isConnected => _currentConfig != null || _currentChain != null;

  /// Get current configuration
  VpnConfig? get currentConfig => _currentConfig;
  AnonymousChain? get currentChain => _currentChain;

  /// Request VPN permission from user
  Future<bool> requestPermission() async {
    try {
      final result = await VpnMethodChannel.requestVpnPermission();
      return result['permissionRequired'] != true;
    } catch (e) {
      _logger.e('Failed to request VPN permission: $e');
      return false;
    }
  }

  /// Connect to VPN with standard configuration
  Future<bool> connectVpn(VpnConfig config) async {
    if (_isConnecting) {
      _logger.w('VPN connection already in progress');
      return false;
    }

    try {
      _isConnecting = true;
      _logger.i('Starting VPN connection to ${config.name}');
      
      // Disconnect any existing connection
      if (isConnected) {
        await disconnect();
      }
      
      // Start VPN through WireGuard service (uses wireguard_flutter_plus plugin)
      final success = await _wireGuardService.connect(config);
      
      if (success) {
        _currentConfig = config;
        
        // Emit connected status
        _emitLegacyStatus(ConnectionStatus(
          vpnStatus: VpnStatus.connected,
          currentServerName: config.name,
          connectedAt: DateTime.now(),
        ));
        
        // Start server rotation if enabled
        if (config.autoRotate) {
          _startRotationTimer(config.rotationInterval);
        }
        
        _logger.i('VPN connected successfully: ${config.name}');
        return true;
      } else {
        _logger.e('VPN connection failed');
        _emitLegacyStatus(ConnectionStatus(vpnStatus: VpnStatus.error));
        return false;
      }
      
    } catch (e) {
      _logger.e('Failed to connect VPN: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Connect with anonymous chain (Ghost/Stealth/Paranoid modes)
  Future<bool> connectAnonymousChain(AnonymousChain chain) async {
    if (_isConnecting) {
      _logger.w('Connection already in progress');
      return false;
    }

    try {
      _isConnecting = true;
      _logger.i('Starting ${chain.mode.name} mode with ${chain.hopCount} hops');
      
      // Check permission
      if (!await requestPermission()) {
        _logger.w('VPN permission denied for anonymous chain');
        return false;
      }
      
      // Disconnect any existing connection
      if (isConnected) {
        await disconnect();
      }
      
      // Start appropriate anonymous mode
      late Future<Map<String, dynamic>> result;
      
      switch (chain.mode) {
        case AnonymousMode.ghost:
          result = AnonymousMethodChannel.startGhostMode(
            proxyServers: chain.proxyChain,
            hopCount: chain.hopCount,
            autoRotate: chain.autoRotate,
            rotationInterval: chain.rotationInterval ?? Duration(minutes: 10),
          );
          break;
        case AnonymousMode.stealth:
          result = AnonymousMethodChannel.startStealthMode(
            proxyServers: chain.proxyChain,
            hopCount: chain.hopCount,
            obfuscationType: 'https',
          );
          break;
        case AnonymousMode.paranoid:
          result = AnonymousMethodChannel.startParanoidMode(
            proxyServers: chain.proxyChain,
            hopCount: chain.hopCount,
            rotationInterval: Duration(minutes: 3),
          );
          break;
        case AnonymousMode.turbo:
          result = AnonymousMethodChannel.startTurboMode(
            proxyServers: chain.proxyChain,
            hopCount: chain.hopCount,
          );
          break;
        default:
          result = VpnMethodChannel.startAnonymousChain(chain);
      }
      
      final response = await result;
      
      if (response['success'] == true) {
        _currentChain = chain;
        
        // Start automatic rotation if enabled
        if (chain.autoRotate) {
          _startRotationTimer(chain.rotationInterval ?? Duration(minutes: 10));
        }
        
        _logger.i('Anonymous chain connected: ${chain.mode.name}');
        return true;
      } else {
        _logger.e('Anonymous chain failed: ${response['error']}');
        return false;
      }
      
    } catch (e) {
      _logger.e('Failed to start anonymous chain: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Quick connect to Ghost Mode (maximum anonymity)
  Future<bool> connectGhostMode(List<ProxyConfig> servers) async {
    final ghostChain = AnonymousChain.ghostMode();
    final updatedChain = ghostChain.copyWith(
      proxyChain: servers.take(5).toList(), // Use up to 5 servers for ghost mode
    );
    return await connectAnonymousChain(updatedChain);
  }

  /// Quick connect to Stealth Mode (censorship bypass)
  Future<bool> connectStealthMode(List<ProxyConfig> servers) async {
    final stealthChain = AnonymousChain.stealthMode();
    final updatedChain = stealthChain.copyWith(
      proxyChain: servers.where((s) => s.isObfuscated).take(3).toList(),
    );
    return await connectAnonymousChain(updatedChain);
  }

  /// Quick connect to Turbo Mode (fast anonymity)
  Future<bool> connectTurboMode(List<ProxyConfig> servers) async {
    final turboChain = AnonymousChain.turboMode();
    final updatedChain = turboChain.copyWith(
      proxyChain: servers.take(2).toList(), // Only 2 hops for speed
    );
    return await connectAnonymousChain(updatedChain);
  }

  /// Disconnect VPN or anonymous chain
  Future<bool> disconnect() async {
    try {
      _logger.i('Disconnecting VPN/Anonymous chain');
      
      // Stop rotation timer
      _rotationTimer?.cancel();
      _rotationTimer = null;
      
      // Disconnect through WireGuard service
      await _wireGuardService.disconnect();
      
      // Also try native channels for anonymous chain
      if (_currentChain != null) {
        try {
          await AnonymousMethodChannel.stopAnonymousChain();
        } catch (e) {
          _logger.w('Anonymous chain stop failed (may not be running): $e');
        }
      }
      
      // Clear current connections
      _currentConfig = null;
      _currentChain = null;
      
      // Emit disconnected status
      _emitLegacyStatus(ConnectionStatus(vpnStatus: VpnStatus.disconnected));
      
      _logger.i('Disconnected successfully');
      return true;
      
    } catch (e) {
      _logger.e('Failed to disconnect: $e');
      return false;
    }
  }

  /// Get current connection status
  Future<ConnectionStatus> getStatus() async {
    try {
      return await VpnMethodChannel.getVpnStatus();
    } catch (e) {
      _logger.e('Failed to get status: $e');
      return ConnectionStatus.disconnected();
    }
  }

  /// Enable kill switch protection
  Future<bool> enableKillSwitch() async {
    try {
      final result = await VpnMethodChannel.enableKillSwitch(true);
      return result['success'] == true;
    } catch (e) {
      _logger.e('Failed to enable kill switch: $e');
      return false;
    }
  }

  /// Force chain rotation (for anonymous modes)
  Future<bool> rotateChain() async {
    try {
      if (_currentChain == null) {
        _logger.w('No active anonymous chain to rotate');
        return false;
      }
      
      final result = await AnonymousMethodChannel.forceChainRotation();
      return result['success'] == true;
    } catch (e) {
      _logger.e('Failed to rotate chain: $e');
      return false;
    }
  }

  /// Get detailed connection information
  Future<VpnConnectionInfo> getConnectionInfo() async {
    try {
      final result = await VpnMethodChannel.getConnectionInfo();
      return VpnConnectionInfo.fromMap(result);
    } catch (e) {
      _logger.e('Failed to get connection info: $e');
      return VpnConnectionInfo.fromMap({});
    }
  }

  /// Start automatic rotation timer
  void _startRotationTimer(Duration? interval) {
    if (interval == null) return;
    
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(interval, (timer) async {
      if (_currentChain != null) {
        _logger.i('Auto-rotating anonymous chain');
        await rotateChain();
      }
    });
    
    _logger.i('Auto-rotation started: ${interval.inMinutes} minutes');
  }

  /// Start periodic status updates
  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        if (isConnected) {
          final status = await getStatus();
          _statusController?.add(status);
        }
      } catch (e) {
        _logger.w('Status update failed: $e');
      }
    });
  }

  /// Handle VPN method calls from native side
  Future<dynamic> _handleVpnMethodCall(MethodCall call) async {
    await VpnMethodChannel.handleNativeCall(call);
    
    // Additional handling for UI updates
    if (call.method == 'onStatusUpdate') {
      final statusMap = Map<String, dynamic>.from(call.arguments);
      final status = ConnectionStatus.fromMap(statusMap);
      _statusController?.add(status);
    }
  }

  /// Handle anonymous method calls from native side
  Future<dynamic> _handleAnonymousMethodCall(MethodCall call) async {
    await AnonymousMethodChannel.handleNativeCall(call);
    
    // Handle chain-specific events
    switch (call.method) {
      case 'onChainRotation':
        _logger.i('Chain rotation completed successfully');
        break;
      case 'onSecurityAlert':
        _logger.w('Security alert: ${call.arguments}');
        break;
    }
  }

  /// Dispose resources
  void dispose() {
    _rotationTimer?.cancel();
    _statusUpdateTimer?.cancel();
    _wireGuardStageSubscription?.cancel();
    _statusController?.close();
    _wireGuardService.dispose();
    _logger.i('Enhanced VPN Manager disposed');
  }

  /// Handle WireGuard stage changes from plugin
  void _onWireGuardStageChanged(VpnStage stage) {
    _logger.d('WireGuard stage changed: $stage');
    
    VpnStatus vpnStatus;
    switch (stage) {
      case VpnStage.connected:
        vpnStatus = VpnStatus.connected;
        break;
      case VpnStage.connecting:
        vpnStatus = VpnStatus.connecting;
        break;
      case VpnStage.disconnecting:
        vpnStatus = VpnStatus.disconnecting;
        break;
      case VpnStage.disconnected:
        vpnStatus = VpnStatus.disconnected;
        if (_currentConfig != null) {
          // Unexpected disconnect
          _currentConfig = null;
          _rotationTimer?.cancel();
        }
        break;
      case VpnStage.denied:
      case VpnStage.noConnection:
        vpnStatus = VpnStatus.error;
        break;
      default:
        vpnStatus = VpnStatus.disconnected;
    }
    
    _emitLegacyStatus(ConnectionStatus(
      vpnStatus: vpnStatus,
      currentServerName: _currentConfig?.name ?? '',
      connectedAt: vpnStatus == VpnStatus.connected ? DateTime.now() : null,
    ));
  }

  /// Emit status update to legacy stream
  void _emitLegacyStatus(ConnectionStatus status) {
    _statusController?.add(status);
  }
}

/// Extended connection status for enhanced manager
extension ConnectionStatusExtensions on ConnectionStatus {
  static ConnectionStatus fromEnhancedMap(Map<String, dynamic> map) {
    return ConnectionStatus(
      vpnStatus: _parseVpnStatus(map['status']),
      currentServerId: map['serverId'],
      currentServerName: map['serverName'] ?? '',
      connectedAt: map['connectionTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['connectionTime']) 
        : null,
      bytesReceived: map['bytesIn'] ?? 0,
      bytesSent: map['bytesOut'] ?? 0,
      currentIpAddress: map['publicIp'] ?? '0.0.0.0',
      currentCountry: map['country'] ?? 'Unknown',
    );
  }

  static VpnStatus _parseVpnStatus(String? status) {
    switch (status) {
      case 'connected': return VpnStatus.connected;
      case 'connecting': return VpnStatus.connecting;
      case 'disconnecting': return VpnStatus.disconnecting;
      case 'error': return VpnStatus.error;
      default: return VpnStatus.disconnected;
    }
  }
}