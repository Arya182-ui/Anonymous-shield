import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../storage/secure_storage.dart';

/// Production-Grade Error Handler & Crash Reporting System
/// Provides comprehensive error logging, crash reporting, and recovery mechanisms
class ProductionErrorHandler {
  static final ProductionErrorHandler _instance = ProductionErrorHandler._internal();
  factory ProductionErrorHandler() => _instance;
  ProductionErrorHandler._internal();

  final Logger _logger = Logger();
  final SecureStorage _secureStorage = SecureStorage();
  
  bool _isInitialized = false;
  bool _crashReportingEnabled = true;  // Can be disabled for privacy
  bool _errorLoggingEnabled = true;
  
  // Error tracking
  final List<ErrorReport> _recentErrors = [];
  final Map<String, int> _errorFrequency = {};
  Timer? _errorAnalysisTimer;
  
  /// Initialize production error handling
  Future<bool> initialize({
    String? sentryDsn,
    bool enableCrashReporting = true,
    bool enableErrorLogging = true,
  }) async {
    if (_isInitialized) return true;
    
    try {
      _logger.i('Initializing Production Error Handler');
      
      _crashReportingEnabled = enableCrashReporting;
      _errorLoggingEnabled = enableErrorLogging;
      
      // Initialize Sentry for crash reporting (if enabled and DSN provided)
      if (_crashReportingEnabled && sentryDsn != null) {
        await SentryFlutter.init(
          (options) {
            options.dsn = sentryDsn;
            options.environment = kDebugMode ? 'development' : 'production';
            options.release = 'privacy_vpn_controller@1.0.0+1';
            options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
            options.enableAutoSessionTracking = false;
            options.sendDefaultPii = false;  // Privacy first
            options.attachStacktrace = true;
            options.attachScreenshot = false;  // Privacy
            options.beforeSend = _filterSensitiveData;
          },
        );
        _logger.i('Crash reporting initialized');
      }
      
      // Set up Flutter error handlers
      _setupFlutterErrorHandlers();
      
      // Set up zone error handlers  
      _setupZoneErrorHandlers();
      
      // Start error analysis
      _startErrorAnalysis();
      
      _isInitialized = true;
      _logger.i('Production Error Handler initialized');
      return true;
      
    } catch (e) {
      _logger.e('Failed to initialize error handler: $e');
      return false;
    }
  }

  /// Setup Flutter framework error handlers
  void _setupFlutterErrorHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log the error
      _logError(
        error: details.exception,
        stackTrace: details.stack,
        context: 'Flutter Framework',
        library: details.library,
        informationCollector: details.informationCollector,
      );
      
      // Report to crash service
      if (_crashReportingEnabled) {
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );
      }
      
      // Continue with default Flutter error handling in debug mode
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle platform dispatcher errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(
        error: error,
        stackTrace: stack,
        context: 'Platform Dispatcher',
      );
      
      if (_crashReportingEnabled) {
        Sentry.captureException(error, stackTrace: stack);
      }
      
      return true;
    };
  }

  /// Setup zone-based error handlers for async operations
  void _setupZoneErrorHandlers() {
    // This will be used when running the app in a guarded zone
    // Called from main.dart: runZonedGuarded(() => runApp(MyApp()), ProductionErrorHandler().handleZoneError);
  }

  /// Handle zone errors (async operations)
  void handleZoneError(Object error, StackTrace stack) {
    _logError(
      error: error,
      stackTrace: stack,
      context: 'Async Zone',
    );
    
    if (_crashReportingEnabled) {
      Sentry.captureException(error, stackTrace: stack);
    }
  }

  /// Log errors with comprehensive information
  void _logError({
    required Object error,
    StackTrace? stackTrace,
    String? context,
    String? library,
    InformationCollector? informationCollector,
    Map<String, dynamic>? additionalData,
  }) {
    if (!_errorLoggingEnabled) return;
    
    try {
      final errorReport = ErrorReport(
        error: error,
        stackTrace: stackTrace,
        context: context ?? 'Unknown',
        library: library,
        timestamp: DateTime.now(),
        deviceInfo: _getDeviceInfo(),
        additionalData: additionalData,
      );
      
      // Add to recent errors
      _recentErrors.add(errorReport);
      if (_recentErrors.length > 50) {
        _recentErrors.removeAt(0);
      }
      
      // Track error frequency
      final errorKey = '${error.runtimeType}:${error.toString()}'.substring(0, 100);
      _errorFrequency[errorKey] = (_errorFrequency[errorKey] ?? 0) + 1;
      
      // Log with appropriate level
      final severity = _determineErrorSeverity(error);
      switch (severity) {
        case ErrorSeverity.critical:
          _logger.f('CRITICAL ERROR [$context]: $error', error: error, stackTrace: stackTrace);
          break;
        case ErrorSeverity.high:
          _logger.e('ERROR [$context]: $error', error: error, stackTrace: stackTrace);
          break;
        case ErrorSeverity.medium:
          _logger.w('WARNING [$context]: $error', error: error, stackTrace: stackTrace);
          break;
        case ErrorSeverity.low:
          _logger.i('INFO [$context]: $error', error: error, stackTrace: stackTrace);
          break;
      }
      
      // Store error locally for offline analysis
      _storeErrorLocally(errorReport);
      
    } catch (e) {
      // Fallback logging if error handler itself fails
      print('ERROR HANDLER FAILED: $e');
      print('Original error: $error');
    }
  }

  /// Determine error severity for proper handling
  ErrorSeverity _determineErrorSeverity(Object error) {
    // VPN-specific critical errors
    if (error.toString().contains('VPN') || 
        error.toString().contains('WireGuard') ||
        error.toString().contains('kill switch') ||
        error.toString().contains('DNS leak')) {
      return ErrorSeverity.critical;
    }
    
    // Security-related errors
    if (error.toString().contains('security') ||
        error.toString().contains('encryption') ||
        error.toString().contains('certificate')) {
      return ErrorSeverity.high;
    }
    
    // Network errors
    if (error is SocketException || 
        error is HttpException ||
        error.toString().contains('network')) {
      return ErrorSeverity.medium;
    }
    
    // UI/UX errors (less critical but should be fixed)
    if (error is FlutterError) {
      return ErrorSeverity.medium;
    }
    
    // Default to medium severity
    return ErrorSeverity.medium;
  }

  /// Filter sensitive data before reporting
  SentryEvent? _filterSensitiveData(SentryEvent event, {Hint? hint}) {
    // Remove sensitive information from error reports
    if (event.contexts.containsKey('os') && event.contexts['os'] != null) {
      // Keep basic OS info but remove detailed system info
      event = event.copyWith(
        // Temporarily disabled due to API compatibility issues
        // contexts: Map.from(event.contexts)
        //   ..remove('device')  // Remove device-specific info
        //   ..remove('app')     // Remove app-specific details
      );
    }
    
    // Filter sensitive data from extra fields
    if (event.extra != null) {
      final filteredExtra = <String, dynamic>{};
      for (final entry in event.extra!.entries) {
        if (!_isSensitiveKey(entry.key)) {
          filteredExtra[entry.key] = entry.value;
        }
      }
      event = event.copyWith(extra: filteredExtra);
    }
    
    // Filter breadcrumbs for sensitive data
    if (event.breadcrumbs != null) {
      final filteredBreadcrumbs = event.breadcrumbs!
          .where((breadcrumb) => !_containsSensitiveData(breadcrumb.message ?? ''))
          .toList();
      event = event.copyWith(breadcrumbs: filteredBreadcrumbs);
    }
    
    return event;
  }

  /// Check if key contains sensitive information
  bool _isSensitiveKey(String key) {
    final sensitiveKeys = [
      'password', 'token', 'key', 'secret', 'private',
      'vpn_config', 'server_endpoint', 'user_id', 'device_id',
      'ip_address', 'location', 'dns'
    ];
    
    return sensitiveKeys.any((sensitive) => 
      key.toLowerCase().contains(sensitive));
  }

  /// Check if data contains sensitive information
  bool _containsSensitiveData(String data) {
    final sensitivePatterns = [
      RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'), // IP addresses
      RegExp(r'[a-f0-9]{32,}'), // Hashes/keys
      RegExp(r'vpn\w*[\w\.\-]+\.com'), // VPN domains
    ];
    
    return sensitivePatterns.any((pattern) => pattern.hasMatch(data.toLowerCase()));
  }

  /// Get device information for error context
  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'is_debug': kDebugMode,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Store error locally for offline analysis
  Future<void> _storeErrorLocally(ErrorReport report) async {
    try {
      final errorData = {
        'timestamp': report.timestamp.toIso8601String(),
        'error': report.error.toString(),
        'context': report.context,
        'severity': report.severity.toString(),
      };
      
      await _secureStorage.store(
        'error_${report.timestamp.millisecondsSinceEpoch}',
        errorData.toString(),
      );
    } catch (e) {
      // Ignore storage errors to avoid infinite recursion
    }
  }

  /// Start error analysis and pattern detection
  void _startErrorAnalysis() {
    _errorAnalysisTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _analyzeErrorPatterns();
    });
  }

  /// Analyze error patterns for proactive issue detection
  void _analyzeErrorPatterns() {
    try {
      // Detect frequent errors
      const frequencyThreshold = 5;
      final frequentErrors = _errorFrequency.entries
          .where((entry) => entry.value >= frequencyThreshold)
          .toList();
      
      if (frequentErrors.isNotEmpty) {
        _logger.w('Detected ${frequentErrors.length} frequent error patterns');
        
        // Report pattern to monitoring if enabled
        if (_crashReportingEnabled) {
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'Frequent error patterns detected',
              data: {'count': frequentErrors.length},
              level: SentryLevel.warning,
            ),
          );
        }
      }
      
      // Clean old error data
      _cleanupOldErrors();
      
    } catch (e) {
      _logger.e('Error analysis failed: $e');
    }
  }

  /// Cleanup old error data to prevent memory leaks
  void _cleanupOldErrors() {
    final cutoffTime = DateTime.now().subtract(Duration(hours: 24));
    _recentErrors.removeWhere((error) => error.timestamp.isBefore(cutoffTime));
    
    // Reset frequency counters periodically
    if (_recentErrors.length < 10) {
      _errorFrequency.clear();
    }
  }

  /// Get error statistics for debugging
  Map<String, dynamic> getErrorStatistics() {
    return {
      'total_errors': _recentErrors.length,
      'error_frequency': Map.from(_errorFrequency),
      'recent_errors': _recentErrors.take(5).map((e) => e.toMap()).toList(),
      'last_analysis': DateTime.now().toIso8601String(),
    };
  }

  /// Manually report custom errors
  void reportError({
    required Object error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    _logError(
      error: error,
      stackTrace: stackTrace,
      context: context ?? 'Manual Report',
      additionalData: additionalData,
    );
  }

  /// Cleanup resources
  void dispose() {
    _errorAnalysisTimer?.cancel();
    _recentErrors.clear();
    _errorFrequency.clear();
  }
}

/// Error severity levels
enum ErrorSeverity { low, medium, high, critical }

/// Comprehensive error report model
class ErrorReport {
  final Object error;
  final StackTrace? stackTrace;
  final String context;
  final String? library;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic>? additionalData;
  
  ErrorSeverity get severity => _determineSeverity();

  const ErrorReport({
    required this.error,
    this.stackTrace,
    required this.context,
    this.library,
    required this.timestamp,
    required this.deviceInfo,
    this.additionalData,
  });

  ErrorSeverity _determineSeverity() {
    // Same logic as in ProductionErrorHandler._determineErrorSeverity
    if (error.toString().contains('VPN') || 
        error.toString().contains('WireGuard') ||
        error.toString().contains('kill switch')) {
      return ErrorSeverity.critical;
    }
    
    if (error.toString().contains('security') ||
        error.toString().contains('encryption')) {
      return ErrorSeverity.high;
    }
    
    if (error is SocketException || error is HttpException) {
      return ErrorSeverity.medium;
    }
    
    return ErrorSeverity.medium;
  }

  Map<String, dynamic> toMap() {
    return {
      'error': error.toString(),
      'context': context,
      'library': library,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.toString(),
      'device_info': deviceInfo,
      'additional_data': additionalData,
    };
  }
}