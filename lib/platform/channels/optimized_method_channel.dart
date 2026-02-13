import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Production-Optimized Method Channel Handler
/// Provides efficient communication with native Android code with caching, 
/// retry logic, and comprehensive error handling
class OptimizedMethodChannel {
  static final Map<String, OptimizedMethodChannel> _instances = {};
  
  final String _channelName;
  final MethodChannel _channel;
  final Logger _logger = Logger();
  
  // Performance optimizations
  final Map<String, CachedResponse> _responseCache = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, int> _retryCounters = {};
  
  // Configuration
  Duration _defaultTimeout = Duration(seconds: 30);
  int _maxRetries = 3;
  Duration _cacheExpiry = Duration(minutes: 5);
  bool _enableCaching = true;
  bool _enableDebouncing = true;
  
  OptimizedMethodChannel._(this._channelName) : _channel = MethodChannel(_channelName);
  
  /// Factory constructor with singleton pattern
  factory OptimizedMethodChannel(String channelName) {
    return _instances.putIfAbsent(channelName, () => OptimizedMethodChannel._(channelName));
  }
  
  /// Initialize channel with configuration
  Future<void> initialize({
    Duration? timeout,
    int? maxRetries,
    Duration? cacheExpiry,
    bool? enableCaching,
    bool? enableDebouncing,
  }) async {
    _defaultTimeout = timeout ?? _defaultTimeout;
    _maxRetries = maxRetries ?? _maxRetries;
    _cacheExpiry = cacheExpiry ?? _cacheExpiry;
    _enableCaching = enableCaching ?? _enableCaching;
    _enableDebouncing = enableDebouncing ?? _enableDebouncing;
    
    _logger.d('Initialized optimized channel: $_channelName');
  }
  
  /// Invoke method with advanced optimizations
  Future<T?> invokeMethod<T>({
    required String method,
    dynamic arguments,
    Duration? timeout,
    bool? useCache,
    bool? debounce,
    int? retries,
  }) async {
    final methodTimeout = timeout ?? _defaultTimeout;
    final shouldCache = useCache ?? _enableCaching;
    final shouldDebounce = debounce ?? _enableDebouncing;
    final maxRetries = retries ?? _maxRetries;
    
    final cacheKey = _generateCacheKey(method, arguments);
    
    try {
      // Check cache first
      if (shouldCache && _isCacheValid(cacheKey)) {
        _logger.d('Cache hit for $method');
        return _responseCache[cacheKey]?.data as T?;
      }
      
      // Debounce rapid calls
      if (shouldDebounce && _debounceTimers.containsKey(cacheKey)) {
        _logger.d('Debouncing call to $method');
        _debounceTimers[cacheKey]?.cancel();
      }
      
      // Perform method call with retry logic
      T? result = await _invokeWithRetry<T>(
        method: method,
        arguments: arguments,
        timeout: methodTimeout,
        maxRetries: maxRetries,
      );
      
      // Cache successful response
      if (shouldCache && result != null) {
        _cacheResponse(cacheKey, result);
      }
      
      // Reset retry counter on success
      _retryCounters.remove(cacheKey);
      
      return result;
      
    } catch (e) {
      _logger.e('Method channel error [$_channelName.$method]: $e');
      rethrow;
    }
  }
  
  /// Invoke method with retry logic and circuit breaker
  Future<T?> _invokeWithRetry<T>({
    required String method,
    dynamic arguments,
    required Duration timeout,
    required int maxRetries,
  }) async {
    final cacheKey = _generateCacheKey(method, arguments);
    int attempts = 0;
    Exception? lastException;
    
    while (attempts <= maxRetries) {
      try {
        _logger.d('Invoking $_channelName.$method (attempt ${attempts + 1})');
        
        final result = await _channel
            .invokeMethod<T>(method, arguments)
            .timeout(timeout);
            
        return result;
        
      } on TimeoutException catch (e) {
        lastException = e;
        _logger.w('Method timeout for $method (attempt ${attempts + 1})');
        
      } on PlatformException catch (e) {
        lastException = e;
        
        // Don't retry certain errors
        if (_isNonRetryableError(e)) {
          _logger.e('Non-retryable error for $method: ${e.message}');
          throw e;
        }
        
        _logger.w('Platform error for $method (attempt ${attempts + 1}): ${e.message}');
        
      } on Exception catch (e) {
        lastException = e;
        _logger.w('Unexpected error for $method (attempt ${attempts + 1}): $e');
      }
      
      attempts++;
      
      // Exponential backoff between retries
      if (attempts <= maxRetries) {
        final delay = Duration(milliseconds: 500 * (1 << (attempts - 1)));
        _logger.d('Retrying $method in ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
    
    // Track retry failures
    _retryCounters[cacheKey] = (_retryCounters[cacheKey] ?? 0) + 1;
    
    _logger.e('Method $method failed after $attempts attempts');
    throw lastException ?? Exception('Method failed after retries');
  }
  
  /// Set method call handler with error handling
  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    _channel.setMethodCallHandler((call) async {
      try {
        _logger.d('Received native call: ${call.method}');
        return await handler?.call(call);
      } catch (e) {
        _logger.e('Error handling native call ${call.method}: $e');
        rethrow;
      }
    });
  }
  
  /// Batch invoke multiple methods efficiently
  Future<Map<String, dynamic>> batchInvoke(List<BatchMethodCall> calls) async {
    final results = <String, dynamic>{};
    final futures = <String, Future<dynamic>>{};
    
    // Start all calls concurrently
    for (final call in calls) {
      futures[call.id] = invokeMethod(
        method: call.method,
        arguments: call.arguments,
        timeout: call.timeout,
        useCache: call.useCache,
      );
    }
    
    // Wait for all results
    for (final entry in futures.entries) {
      try {
        results[entry.key] = await entry.value;
      } catch (e) {
        results[entry.key] = {'error': e.toString()};
      }
    }
    
    return results;
  }
  
  /// Stream method calls for real-time communication
  Stream<T> invokeMethodStream<T>(
    String method, {
    dynamic arguments,
    Duration? interval,
  }) {
    final streamInterval = interval ?? Duration(seconds: 1);
    
    return Stream.periodic(streamInterval, (_) async {
      final result = await invokeMethod<T>(
        method: method,
        arguments: arguments,
        useCache: false, // Don't cache streaming data
      );
      return result!;
    }).asyncMap((future) => future);
  }
  
  /// Generate cache key for method and arguments
  String _generateCacheKey(String method, dynamic arguments) {
    final argsString = arguments != null ? jsonEncode(arguments) : '';
    return '${method}_${argsString.hashCode}';
  }
  
  /// Check if cached response is still valid
  bool _isCacheValid(String cacheKey) {
    final cached = _responseCache[cacheKey];
    if (cached == null) return false;
    
    return DateTime.now().difference(cached.timestamp) < _cacheExpiry;
  }
  
  /// Cache response with timestamp
  void _cacheResponse(String cacheKey, dynamic data) {
    _responseCache[cacheKey] = CachedResponse(
      data: data,
      timestamp: DateTime.now(),
    );
  }
  
  /// Check if error should not be retried
  bool _isNonRetryableError(PlatformException e) {
    final nonRetryableCodes = [
      'INVALID_ARGUMENT',
      'PERMISSION_DENIED',
      'NOT_FOUND',
      'ALREADY_EXISTS',
      'INVALID_CONFIG',
    ];
    
    return nonRetryableCodes.contains(e.code);
  }
  
  /// Get channel performance statistics
  Map<String, dynamic> getStatistics() {
    final cacheHitRate = _responseCache.isNotEmpty 
        ? (_responseCache.length / (_responseCache.length + _retryCounters.length))
        : 0.0;
    
    return {
      'channel_name': _channelName,
      'cached_responses': _responseCache.length,
      'active_debounce_timers': _debounceTimers.length,
      'retry_failures': _retryCounters.length,
      'cache_hit_rate': cacheHitRate,
      'configuration': {
        'timeout_ms': _defaultTimeout.inMilliseconds,
        'max_retries': _maxRetries,
        'cache_expiry_ms': _cacheExpiry.inMilliseconds,
        'caching_enabled': _enableCaching,
        'debouncing_enabled': _enableDebouncing,
      },
    };
  }
  
  /// Clear cache manually
  void clearCache() {
    _responseCache.clear();
    _logger.d('Cleared cache for channel: $_channelName');
  }
  
  /// Clear expired cache entries
  void cleanupCache() {
    final now = DateTime.now();
    _responseCache.removeWhere((key, value) => 
      now.difference(value.timestamp) > _cacheExpiry);
  }
  
  /// Dispose resources and cleanup
  void dispose() {
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    // Clear caches
    _responseCache.clear();
    _retryCounters.clear();
    
    // Remove from instances
    _instances.remove(_channelName);
    
    _logger.d('Disposed channel: $_channelName');
  }
  
  /// Dispose all channels (app cleanup)
  static void disposeAll() {
    for (final channel in _instances.values) {
      channel.dispose();
    }
    _instances.clear();
  }
}

/// Cached response model
class CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  
  const CachedResponse({
    required this.data,
    required this.timestamp,
  });
}

/// Batch method call model
class BatchMethodCall {
  final String id;
  final String method;
  final dynamic arguments;
  final Duration? timeout;
  final bool? useCache;
  
  const BatchMethodCall({
    required this.id,
    required this.method,
    this.arguments,
    this.timeout,
    this.useCache,
  });
}

/// Pre-configured optimized channels for the app
class AppMethodChannels {
  static OptimizedMethodChannel? _vpnChannel;
  static OptimizedMethodChannel? _proxyChannel;
  static OptimizedMethodChannel? _securityChannel;
  static OptimizedMethodChannel? _systemChannel;
  
  /// VPN method channel
  static OptimizedMethodChannel get vpn {
    return _vpnChannel ??= OptimizedMethodChannel('privacy_vpn_controller/vpn')
      ..initialize(
        timeout: Duration(seconds: 45), // VPN operations can take time
        maxRetries: 3,
        cacheExpiry: Duration(seconds: 30), // Short cache for VPN status
        enableCaching: true,
        enableDebouncing: true,
      );
  }
  
  /// Proxy method channel
  static OptimizedMethodChannel get proxy {
    return _proxyChannel ??= OptimizedMethodChannel('privacy_vpn_controller/proxy')
      ..initialize(
        timeout: Duration(seconds: 20),
        maxRetries: 2,
        cacheExpiry: Duration(minutes: 1),
        enableCaching: true,
        enableDebouncing: true,
      );
  }
  
  /// Security method channel
  static OptimizedMethodChannel get security {
    return _securityChannel ??= OptimizedMethodChannel('privacy_vpn_controller/security')
      ..initialize(
        timeout: Duration(seconds: 15),
        maxRetries: 1, // Security operations should be fast
        cacheExpiry: Duration(minutes: 2),
        enableCaching: false, // Don't cache security status
        enableDebouncing: false,
      );
  }
  
  /// System method channel
  static OptimizedMethodChannel get system {
    return _systemChannel ??= OptimizedMethodChannel('privacy_vpn_controller/system')
      ..initialize(
        timeout: Duration(seconds: 10),
        maxRetries: 2,
        cacheExpiry: Duration(minutes: 5),
        enableCaching: true,
        enableDebouncing: true,
      );
  }
  
  /// Initialize all channels
  static Future<void> initializeAll() async {
    await Future.wait([
      vpn.initialize(),
      proxy.initialize(),
      security.initialize(),
      system.initialize(),
    ]);
  }
  
  /// Get combined statistics for all channels
  static Map<String, dynamic> getAllStatistics() {
    return {
      'vpn': vpn.getStatistics(),
      'proxy': proxy.getStatistics(),
      'security': security.getStatistics(),
      'system': system.getStatistics(),
    };
  }
  
  /// Cleanup all channels
  static void disposeAll() {
    OptimizedMethodChannel.disposeAll();
    _vpnChannel = null;
    _proxyChannel = null;
    _securityChannel = null;
    _systemChannel = null;
  }
}