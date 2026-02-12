import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart'; 
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';
import '../models/wireguard_config.dart';
import '../models/connection_status.dart';
import '../repositories/config_repository.dart';
import '../../platform/channels/vpn_method_channel.dart';

/// Production-grade WireGuard Manager
/// Handles secure WireGuard VPN connections with comprehensive error handling
class WireGuardManager {
  static final WireGuardManager _instance = WireGuardManager._internal();
  factory WireGuardManager() => _instance;
  WireGuardManager._internal();

  final Logger _logger = Logger();
  final ConfigRepository _configRepo = ConfigRepository();
  
  StreamController<ConnectionStatus>? _statusController;
  StreamController<WireGuardConnectionStats>? _statsController;
  
  WireGuardConfig? _activeConfig;
  Timer? _connectionMonitor;
  Timer? _statsCollector;
  
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  
  DateTime? _connectionStartTime;
  int _bytesReceived = 0;
  int _bytesSent = 0;
  
  /// Initialize WireGuard manager
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _logger.i('Initializing WireGuard Manager');
      
      await _configRepo.initialize();
      
      _statusController = StreamController<ConnectionStatus>.broadcast();
      _statsController = StreamController<WireGuardConnectionStats>.broadcast();
      
      // Set up native method call handlers
      VpnMethodChannel.setMethodCallHandler(_handleNativeCallback);
      
      _isInitialized = true;
      _logger.i('WireGuard Manager initialized successfully');
      return true;
      
    } catch (e) {
      _logger.e('Failed to initialize WireGuard Manager: $e');
      return false;
    }
  }

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream {
    if (!_isInitialized) {
      throw StateError('WireGuard Manager not initialized');
    }
    return _statusController!.stream;
  }

  /// Get connection statistics stream
  Stream<WireGuardConnectionStats> get statsStream {
    if (!_isInitialized) {
      throw StateError('WireGuard Manager not initialized');
    }
    return _statsController!.stream;
  }

  /// Connect to WireGuard VPN with comprehensive validation
  Future<bool> connect(WireGuardConfig config) async {
    if (!_isInitialized) {
      _logger.e('WireGuard Manager not initialized');
      return false;
    }

    if (_isConnecting || _isConnected) {
      _logger.w('Connection already in progress or active');
      return false;
    }

    try {
      _logger.i('Starting WireGuard connection to ${config.endpoint}');
      _isConnecting = true;
      
      // Validate configuration
      if (!config.validateConfig()) {
        _logger.e('Invalid WireGuard configuration');
        _emitStatus(ConnectionStatus.error, 'Invalid configuration');
        return false;
      }

      // Security check: verify config hash
      final expectedHash = config.generateConfigHash();
      if (expectedHash != config.configHash) {
        _logger.e('Configuration integrity check failed');
        _emitStatus(ConnectionStatus.error, 'Configuration tampered');
        return false;
      }

      _emitStatus(ConnectionStatus.connecting, 'Preparing secure tunnel');

      // Prepare configuration for native layer
      final configMap = {
        'interface_name': config.interfaceName,
        'private_key': config.privateKey,
        'public_key': config.publicKey,
        'preshared_key': config.preSharedKey,
        'server_public_key': config.serverPublicKey,
        'endpoint': config.endpoint,
        'listen_port': config.listenPort,
        'allowed_ips': config.allowedIPs,
        'dns_servers': config.dns,
        'mtu': config.mtu,
        'keepalive': config.keepAlive,
        'persistent_keepalive': config.persistentKeepalive,
        'security_level': config.securityLevel,
      };

      _emitStatus(ConnectionStatus.connecting, 'Establishing tunnel');

      // Call native Android VPN service
      final result = await VpnMethodChannel.invokeMethod('startWireGuardTunnel', configMap);
      
      if (result['success'] == true) {
        _activeConfig = config;
        _isConnected = true;
        _isConnecting = false;
        _connectionStartTime = DateTime.now();
        
        // Start monitoring
        _startConnectionMonitoring();
        _startStatsCollection();
        
        _emitStatus(ConnectionStatus.connected, 'Secure tunnel established');
        _logger.i('WireGuard connection established successfully');
        
        return true;
      } else {
        final error = result['error'] ?? 'Unknown error';
        _logger.e('WireGuard connection failed: $error');
        _emitStatus(ConnectionStatus.error, error);
        return false;
      }
      
    } catch (e) {
      _logger.e('WireGuard connection error: $e');
      _emitStatus(ConnectionStatus.error, e.toString());
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnect WireGuard VPN
  Future<bool> disconnect() async {
    if (!_isInitialized) {
      _logger.e('WireGuard Manager not initialized');
      return false;
    }

    try {
      _logger.i('Disconnecting WireGuard VPN');
      
      _emitStatus(ConnectionStatus.disconnecting, 'Closing secure tunnel');

      // Call native disconnect
      final result = await VpnMethodChannel.invokeMethod('stopWireGuardTunnel', {});
      
      if (result['success'] == true) {
        _isConnected = false;
        _activeConfig = null;
        _connectionStartTime = null;
        
        // Stop monitoring
        _stopConnectionMonitoring();
        _stopStatsCollection();
        
        _emitStatus(ConnectionStatus.disconnected, 'Tunnel closed');
        _logger.i('WireGuard disconnected successfully');
        
        return true;
      } else {
        final error = result['error'] ?? 'Disconnect failed';
        _logger.e('WireGuard disconnect error: $error');
        return false;
      }
      
    } catch (e) {
      _logger.e('WireGuard disconnect error: $e');
      return false;
    }
  }

  /// Get current connection status
  bool get isConnected => _isConnected && _activeConfig != null;
  
  /// Get active configuration
  WireGuardConfig? get activeConfig => _activeConfig;
  
  /// Get connection duration
  Duration? get connectionDuration {
    if (_connectionStartTime == null) return null;
    return DateTime.now().difference(_connectionStartTime!);
  }

  /// Generate configuration from server data
  Future<WireGuardConfig> generateConfig({
    required String serverEndpoint,
    required String serverPublicKey, 
    required List<String> dnsServers,
  }) async {
    try {
      _logger.i('Generating WireGuard configuration');

      // Generate key pair via native method
      final keyResult = await VpnMethodChannel.invokeMethod('generateWireGuardKeys', {});
      
      if (keyResult['success'] != true) {
        throw Exception('Failed to generate keys: ${keyResult['error']}');
      }

      final privateKey = keyResult['private_key'] as String;
      final publicKey = keyResult['public_key'] as String;
      final preSharedKey = keyResult['preshared_key'] as String;

      // Generate secure interface name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final interfaceName = 'wg${timestamp.hashCode.abs() % 10000}';

      final config = WireGuardConfig(
        interfaceName: interfaceName,
        privateKey: privateKey,
        publicKey: publicKey,
        preSharedKey: preSharedKey,
        serverPublicKey: serverPublicKey,
        endpoint: serverEndpoint,
        listenPort: 51820,
        allowedIPs: ['10.0.0.2/32'], // Client IP
        dns: dnsServers,
        mtu: 1420,
        keepAlive: 25,
        persistentKeepalive: true,
        configHash: '', // Will be set below
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(days: 30)),
        isValid: true,
        securityLevel: 'high',
      );

      // Generate and set config hash
      final configWithHash = config.copyWith(
        configHash: config.generateConfigHash(),
      );

      _logger.i('WireGuard configuration generated successfully');
      return configWithHash;
      
    } catch (e) {
      _logger.e('Failed to generate WireGuard config: $e');
      rethrow;
    }
  }

  /// Handle callbacks from native layer
  Future<void> _handleNativeCallback(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onWireGuardStatusChanged':
          final status = call.arguments['status'] as String;
          final message = call.arguments['message'] as String? ?? '';
          _handleStatusChange(status, message);
          break;
          
        case 'onWireGuardStatsUpdated':
          final stats = WireGuardConnectionStats.fromMap(call.arguments);
          _statsController?.add(stats);
          break;
          
        case 'onWireGuardError':
          final error = call.arguments['error'] as String;
          _logger.e('Native WireGuard error: $error');
          _emitStatus(ConnectionStatus.error, error);
          break;
      }
    } catch (e) {
      _logger.e('Error handling native callback: $e');
    }
  }

  void _handleStatusChange(String status, String message) {
    _logger.d('WireGuard status changed: $status - $message');
    
    switch (status) {
      case 'CONNECTED':
        _isConnected = true;
        _emitStatus(ConnectionStatus.connected, message);
        break;
      case 'DISCONNECTED':
        _isConnected = false;
        _emitStatus(ConnectionStatus.disconnected, message);
        break;
      case 'CONNECTING':
        _emitStatus(ConnectionStatus.connecting, message);
        break;
      case 'ERROR':
        _isConnected = false;
        _emitStatus(ConnectionStatus.error, message);
        break;
    }
  }

  void _emitStatus(ConnectionStatus status, String message) {
    _statusController?.add(ConnectionStatus(
      status: status.status,
      message: message,
      timestamp: DateTime.now(),
      serverEndpoint: _activeConfig?.endpoint,
    ));
  }

  void _startConnectionMonitoring() {
    _connectionMonitor = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      _checkConnectionHealth();
    });
  }

  void _stopConnectionMonitoring() {
    _connectionMonitor?.cancel();
    _connectionMonitor = null;
  }

  void _startStatsCollection() {
    _statsCollector = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      await _collectStats();
    });
  }

  void _stopStatsCollection() {
    _statsCollector?.cancel();
    _statsCollector = null;
  }

  Future<void> _checkConnectionHealth() async {
    try {
      final result = await VpnMethodChannel.invokeMethod('checkWireGuardHealth', {});
      if (result['connected'] != true) {
        _logger.w('Connection health check failed');
        _emitStatus(ConnectionStatus.error, 'Connection lost');
      }
    } catch (e) {
      _logger.e('Health check error: $e');
    }
  }

  Future<void> _collectStats() async {
    try {
      final result = await VpnMethodChannel.invokeMethod('getWireGuardStats', {});
      if (result['success'] == true) {
        final stats = WireGuardConnectionStats(
          bytesReceived: result['bytes_received'] ?? 0,
          bytesSent: result['bytes_sent'] ?? 0,
          packetsReceived: result['packets_received'] ?? 0,
          packetsSent: result['packets_sent'] ?? 0,
          lastHandshake: DateTime.tryParse(result['last_handshake'] ?? ''),
          connectionDuration: connectionDuration,
        );
        _statsController?.add(stats);
      }
    } catch (e) {
      _logger.e('Stats collection error: $e');
    }
  }

  /// Cleanup resources
  void dispose() {
    _stopConnectionMonitoring();
    _stopStatsCollection();
    _statusController?.close();
    _statsController?.close();
    _isInitialized = false;
  }
}

/// WireGuard connection statistics model
class WireGuardConnectionStats {
  final int bytesReceived;
  final int bytesSent;
  final int packetsReceived;
  final int packetsSent;
  final DateTime? lastHandshake;
  final Duration? connectionDuration;

  const WireGuardConnectionStats({
    required this.bytesReceived,
    required this.bytesSent,
    required this.packetsReceived,
    required this.packetsSent,
    this.lastHandshake,
    this.connectionDuration,
  });

  factory WireGuardConnectionStats.fromMap(Map<String, dynamic> map) {
    return WireGuardConnectionStats(
      bytesReceived: map['bytes_received'] ?? 0,
      bytesSent: map['bytes_sent'] ?? 0,
      packetsReceived: map['packets_received'] ?? 0,
      packetsSent: map['packets_sent'] ?? 0,
      lastHandshake: DateTime.tryParse(map['last_handshake'] ?? ''),
      connectionDuration: Duration(seconds: map['connection_duration'] ?? 0),
    );
  }

  double get downloadSpeedMbps => bytesReceived / (1024 * 1024);
  double get uploadSpeedMbps => bytesSent / (1024 * 1024);
}