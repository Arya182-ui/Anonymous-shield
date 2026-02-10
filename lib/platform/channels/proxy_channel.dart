import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/proxy_config.dart';
import '../../data/models/connection_status.dart';

class ProxyMethodChannel {
  static final ProxyMethodChannel _instance = ProxyMethodChannel._internal();
  factory ProxyMethodChannel() => _instance;
  ProxyMethodChannel._internal();

  static const MethodChannel _channel = MethodChannel(AppConstants.proxyChannelName);
  final Logger _logger = Logger();

  StreamController<ProxyStatus>? _statusController;
  Stream<ProxyStatus>? _statusStream;

  /// Initialize the proxy method channel
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    _statusController = StreamController<ProxyStatus>.broadcast();
    _statusStream = _statusController!.stream;
    
    _logger.i('Proxy method channel initialized');
  }

  /// Get the proxy status update stream
  Stream<ProxyStatus> get statusStream {
    _statusStream ??= _statusController!.stream;
    return _statusStream!;
  }

  /// Handle incoming method calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _logger.d('Received proxy method call: ${call.method}');
    
    switch (call.method) {
      case 'onProxyStatusChanged':
        _handleProxyStatusChange(call.arguments);
        break;
      case 'onProxyError':
        _handleProxyError(call.arguments);
        break;
      default:
        _logger.w('Unknown proxy method call: ${call.method}');
    }
  }

  /// Start proxy with configuration
  Future<bool> startProxy(ProxyConfig config) async {
    try {
      _logger.i('Starting proxy: ${config.name}');
      
      final configData = {
        'id': config.id,
        'name': config.name,
        'type': config.type.name,
        'host': config.host,
        'port': config.port,
        'username': config.username,
        'password': config.password,
        'method': config.method,
        'plugin': config.plugin,
        'pluginOptions': config.pluginOptions,
      };
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodStartProxy,
        configData,
      );
      
      _logger.i('Proxy start result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to start proxy', error: e, stackTrace: stack);
      _handleProxyError({'error': e.toString()});
      return false;
    }
  }

  /// Stop proxy
  Future<bool> stopProxy() async {
    try {
      _logger.i('Stopping proxy');
      
      final result = await _channel.invokeMethod<bool>(
        AppConstants.methodStopProxy,
      );
      
      _logger.i('Proxy stop result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to stop proxy', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get current proxy status
  Future<ProxyStatus> getProxyStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<String, dynamic>>(
        AppConstants.methodGetProxyStatus,
      );
      
      if (result != null) {
        return _parseProxyStatus(result['status'] as String?);
      }
      
      return ProxyStatus.disabled;
    } catch (e, stack) {
      _logger.e('Failed to get proxy status', error: e, stackTrace: stack);
      return ProxyStatus.error;
    }
  }

  /// Test proxy connection
  Future<bool> testProxy(ProxyConfig config) async {
    try {
      _logger.i('Testing proxy connection: ${config.name}');
      
      final configData = {
        'type': config.type.name,
        'host': config.host,
        'port': config.port,
        'username': config.username,
        'password': config.password,
        'method': config.method,
      };
      
      final result = await _channel.invokeMethod<bool>(
        'testProxy',
        configData,
      );
      
      _logger.i('Proxy test result: $result');
      return result ?? false;
    } catch (e, stack) {
      _logger.e('Failed to test proxy', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Handle proxy status changes from native code
  void _handleProxyStatusChange(dynamic arguments) {
    try {
      final statusData = arguments as Map<String, dynamic>;
      final statusString = statusData['status'] as String?;
      final status = _parseProxyStatus(statusString);
      
      _statusController?.add(status);
      _logger.d('Proxy status changed: $status');
    } catch (e, stack) {
      _logger.e('Failed to handle proxy status change', error: e, stackTrace: stack);
    }
  }

  /// Handle proxy errors from native code
  void _handleProxyError(dynamic arguments) {
    try {
      final errorData = arguments as Map<String, dynamic>;
      final errorMessage = errorData['error'] as String? ?? 'Unknown proxy error';
      
      _statusController?.add(ProxyStatus.error);
      _logger.e('Proxy error received: $errorMessage');
    } catch (e, stack) {
      _logger.e('Failed to handle proxy error', error: e, stackTrace: stack);
    }
  }

  /// Parse proxy status from string
  ProxyStatus _parseProxyStatus(String? statusString) {
    switch (statusString) {
      case 'enabled':
      case 'connected':
        return ProxyStatus.enabled;
      case 'error':
        return ProxyStatus.error;
      case 'disabled':
      case 'disconnected':
      default:
        return ProxyStatus.disabled;
    }
  }

  /// Dispose resources
  void dispose() {
    _statusController?.close();
    _statusController = null;
    _statusStream = null;
  }
}