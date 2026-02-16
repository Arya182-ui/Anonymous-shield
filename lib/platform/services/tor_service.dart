import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Tor VPN Service - Dart wrapper for native TorVpnService
/// Ghost Mode: Real Tor onion routing for actual IP/location change
class TorService {
  static final TorService _instance = TorService._internal();
  factory TorService() => _instance;
  TorService._internal();

  final Logger _logger = Logger();

  static const MethodChannel _channel =
      MethodChannel('com.privacyvpn.privacy_vpn_controller/tor');

  bool _isInitialized = false;

  // Stream controllers for events from native side
  final StreamController<int> _bootstrapController =
      StreamController<int>.broadcast();
  final StreamController<String> _stateController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  /// Bootstrap progress stream (0-100)
  Stream<int> get bootstrapProgress => _bootstrapController.stream;

  /// State change stream ("connecting", "connected", "disconnected", "error")
  Stream<String> get stateChanges => _stateController.stream;

  /// Error stream
  Stream<String> get errors => _errorController.stream;

  /// Current state
  String _currentState = 'disconnected';
  String get currentState => _currentState;

  int _currentBootstrap = 0;
  int get currentBootstrap => _currentBootstrap;

  /// Initialize the Tor service and set up method call handler
  Future<void> initialize() async {
    if (_isInitialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
    _logger.i('TorService initialized');
  }

  /// Handle callbacks from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBootstrapProgress':
        final progress = call.arguments['progress'] as int? ?? 0;
        _currentBootstrap = progress;
        _bootstrapController.add(progress);
        _logger.d('Tor bootstrap: $progress%');
        break;

      case 'onStateChanged':
        final state = call.arguments['state'] as String? ?? 'unknown';
        _currentState = state;
        _stateController.add(state);
        _logger.i('Tor state: $state');
        break;

      case 'onError':
        final error = call.arguments['error'] as String? ?? 'Unknown error';
        _errorController.add(error);
        _logger.e('Tor error: $error');
        break;
    }
  }

  /// Start Tor VPN (real onion routing)
  /// [useBridges] - Use pluggable transports (obfs4/snowflake/meek)
  ///                for censored networks or WARP-like ISP protection
  Future<bool> startTor({bool useBridges = false}) async {
    await initialize();
    _currentState = 'connecting';
    _stateController.add('connecting');
    _currentBootstrap = 0;

    try {
      _logger.i('Starting Tor VPN (bridges=$useBridges)');
      final result = await _channel.invokeMethod<Map>('startTorVpn', {
        'useBridges': useBridges,
      });

      final success = result?['success'] == true;
      if (!success) {
        final error = result?['error']?.toString() ?? 'Unknown error';
        _logger.e('Failed to start Tor: $error');
        _currentState = 'error';
        _stateController.add('error');
        _errorController.add(error);
      }
      return success;
    } catch (e) {
      _logger.e('Error starting Tor: $e');
      _currentState = 'error';
      _stateController.add('error');
      _errorController.add(e.toString());
      return false;
    }
  }

  /// Start with free SOCKS5 proxy (fallback when Tor unavailable)
  /// [socksAddress] - "host:port" of the SOCKS5 proxy
  ///
  /// The native side now waits for actual VPN connection confirmation
  /// before returning success/failure (up to 8 seconds timeout).
  Future<bool> startWithProxy(String socksAddress) async {
    await initialize();
    _currentState = 'connecting';
    _stateController.add('connecting');

    try {
      _logger.i('Starting proxy VPN (socks=$socksAddress)');
      final result = await _channel.invokeMethod<Map>('startProxyVpn', {
        'socksAddress': socksAddress,
      });

      final success = result?['success'] == true;
      if (success) {
        _currentState = 'connected';
        _stateController.add('connected');
        _logger.i('Proxy VPN connected successfully');
      } else {
        final error = result?['error']?.toString() ?? 'Unknown error';
        _logger.e('Failed to start proxy VPN: $error');
        _currentState = 'error';
        _stateController.add('error');
        _errorController.add(error);
      }
      return success;
    } catch (e) {
      _logger.e('Error starting proxy VPN: $e');
      _currentState = 'error';
      _stateController.add('error');
      return false;
    }
  }

  /// Stop Tor/Proxy VPN
  Future<bool> stop() async {
    try {
      _logger.i('Stopping Tor/Proxy VPN');
      final result = await _channel.invokeMethod<Map>('stopTorVpn', null);
      _currentState = 'disconnected';
      _currentBootstrap = 0;
      _stateController.add('disconnected');
      return result?['success'] == true;
    } catch (e) {
      _logger.e('Error stopping Tor: $e');
      _currentState = 'disconnected';
      _stateController.add('disconnected');
      return false;
    }
  }

  /// Request new Tor circuit → new exit node → different IP/country
  /// This is the key rotation mechanism for Ghost Mode
  Future<Map<String, dynamic>> requestNewCircuit() async {
    try {
      _logger.i('Requesting new Tor circuit (SIGNAL NEWNYM)');
      final result =
          await _channel.invokeMethod<Map>('requestNewCircuit', null);
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {'success': false, 'error': 'No response'};
    } catch (e) {
      _logger.e('Error requesting new circuit: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get current Tor status
  Future<TorStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getStatus', null);
      if (result != null) {
        return TorStatus.fromMap(Map<String, dynamic>.from(result));
      }
      return TorStatus.disconnected();
    } catch (e) {
      _logger.e('Error getting status: $e');
      return TorStatus.disconnected();
    }
  }

  /// Get detailed circuit info (exit node, country, path)
  Future<Map<String, dynamic>> getCircuitInfo() async {
    try {
      final result =
          await _channel.invokeMethod<Map>('getCircuitInfo', null);
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      _logger.e('Error getting circuit info: $e');
      return {'error': e.toString()};
    }
  }

  /// Check if Tor binary is available on this device
  Future<bool> isTorAvailable() async {
    try {
      final result =
          await _channel.invokeMethod<Map>('isTorAvailable', null);
      return result?['available'] == true;
    } catch (_) {
      // Catches PlatformException AND MissingPluginException
      // (MissingPluginException = native channel not registered yet)
      return false;
    }
  }

  /// Wait for Tor to fully bootstrap (100%)
  /// Returns true if bootstrapped, false if timed out
  Future<bool> waitForBootstrap({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final completer = Completer<bool>();

    // Already at 100?
    if (_currentBootstrap >= 100) return true;

    StreamSubscription<int>? sub;
    Timer? timer;

    sub = bootstrapProgress.listen((progress) {
      if (progress >= 100 && !completer.isCompleted) {
        timer?.cancel();
        sub?.cancel();
        completer.complete(true);
      }
    });

    timer = Timer(timeout, () {
      sub?.cancel();
      if (!completer.isCompleted) {
        _logger.w('Tor bootstrap timed out at $_currentBootstrap%');
        completer.complete(false);
      }
    });

    return completer.future;
  }

  void dispose() {
    _bootstrapController.close();
    _stateController.close();
    _errorController.close();
    _isInitialized = false;
  }
}

/// Tor connection status model
class TorStatus {
  final bool isActive;
  final bool isRunning;
  final int bootstrapProgress;
  final String? exitCountry;

  TorStatus({
    required this.isActive,
    required this.isRunning,
    required this.bootstrapProgress,
    this.exitCountry,
  });

  factory TorStatus.disconnected() => TorStatus(
        isActive: false,
        isRunning: false,
        bootstrapProgress: 0,
      );

  factory TorStatus.fromMap(Map<String, dynamic> map) => TorStatus(
        isActive: map['isActive'] as bool? ?? false,
        isRunning: map['isRunning'] as bool? ?? false,
        bootstrapProgress: map['bootstrapProgress'] as int? ?? 0,
        exitCountry: map['exitCountry'] as String?,
      );

  bool get isConnected => isActive && bootstrapProgress >= 100;
}
