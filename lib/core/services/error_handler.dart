import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../constants/app_constants.dart';

class ProductionErrorHandler {
  static final ProductionErrorHandler _instance = ProductionErrorHandler._internal();
  factory ProductionErrorHandler() => _instance;
  ProductionErrorHandler._internal();

  final Logger _logger = Logger(
    printer: ProductionLogPrinter(),
    level: AppConstants.debugMode ? Level.debug : Level.warning,
  );

  StreamController<ErrorReport>? _errorReportStream;
  List<ErrorReport> _errorHistory = [];
  
  /// Initialize error handling system
  Future<void> initialize() async {
    _errorReportStream = StreamController<ErrorReport>.broadcast();
    
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };
    
    // Set up Dart error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleDartError(error, stack);
      return true;
    };
    
    _logger.i('Production Error Handler initialized');
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    final report = ErrorReport.fromFlutterError(details);
    _processErrorReport(report);
    
    // In debug mode, also use default Flutter error handling
    if (AppConstants.debugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Handle Dart runtime errors
  void _handleDartError(Object error, StackTrace stack) {
    final report = ErrorReport.fromDartError(error, stack);
    _processErrorReport(report);
  }

  /// Process and log error report
  void _processErrorReport(ErrorReport report) {
    // Log error (without sensitive data)
    _logger.e(
      'App Error: ${report.type}',
      error: report.sanitizedMessage,
      stackTrace: report.stackTrace,
    );
    
    // Add to error history (keep last 50 errors)
    _errorHistory.add(report);
    if (_errorHistory.length > 50) {
      _errorHistory.removeAt(0);
    }
    
    // Notify error stream listeners
    _errorReportStream?.add(report);
    
    // In production, you could send to crash reporting service
    if (!AppConstants.debugMode) {
      _reportToAnalytics(report);
    }
  }

  /// Report to analytics (privacy-compliant)
  void _reportToAnalytics(ErrorReport report) {
    // PRIVACY-FIRST: Only report anonymized error data
    // NO user data, IP addresses, or personal information
    try {
      final anonymizedReport = {
        'errorType': report.type,
        'appVersion': AppConstants.appVersion,
        'platform': Platform.operatingSystem,
        'errorClass': report.sanitizedMessage.runtimeType.toString(),
        'timestamp': report.timestamp.toIso8601String(),
        // Do NOT send: stack traces, user data, device IDs
      };
      
      _logger.d('Anonymized error reported: ${anonymizedReport['errorType']}');
      
      // In production: Send to privacy-compliant crash reporting
      // Example: Sentry with data scrubbing, or custom backend
    } catch (e) {
      _logger.w('Failed to report error anonymously: $e');
    }
  }

  /// Get error statistics for debugging
  ErrorStatistics getErrorStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(Duration(days: 1));
    
    final recentErrors = _errorHistory
        .where((e) => e.timestamp.isAfter(last24Hours))
        .toList();
    
    return ErrorStatistics(
      totalErrors: _errorHistory.length,
      recentErrors: recentErrors.length,
      criticalErrors: recentErrors.where((e) => e.severity == ErrorSeverity.critical).length,
      commonErrorTypes: _getCommonErrorTypes(recentErrors),
    );
  }

  /// Get most common error types
  Map<String, int> _getCommonErrorTypes(List<ErrorReport> errors) {
    final errorCounts = <String, int>{};
    
    for (final error in errors) {
      final type = error.type;
      errorCounts[type] = (errorCounts[type] ?? 0) + 1;
    }
    
    return Map.fromEntries(
      errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(5)
    );
  }

  /// Get error report stream
  Stream<ErrorReport> get errorStream => _errorReportStream!.stream;
  
  /// Get recent error history
  List<ErrorReport> get recentErrors => List.unmodifiable(_errorHistory);

  /// Manual error reporting
  void reportError(String message, {
    Object? error, 
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, dynamic>? context,
  }) {
    final report = ErrorReport(
      type: 'Manual',
      message: message,
      stackTrace: stackTrace ?? StackTrace.current,
      severity: severity,
      timestamp: DateTime.now(),
      context: context,
    );
    
    _processErrorReport(report);
  }

  /// Dispose error handler
  void dispose() {
    _errorReportStream?.close();
  }
}

/// Production-safe log printer
class ProductionLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = DateTime.now().toIso8601String();
    final level = event.level.name.toUpperCase();
    
    // Sanitize message to remove sensitive data
    final sanitizedMessage = _sanitizeLogMessage(event.message.toString());
    
    return ['[$time] $level: $sanitizedMessage'];
  }
  
  String _sanitizeLogMessage(String message) {
    // Remove potential sensitive data patterns
    return message
        .replaceAll(RegExp(r'password[=:]\s*\S+', caseSensitive: false), 'password=***')
        .replaceAll(RegExp(r'token[=:]\s*\S+', caseSensitive: false), 'token=***')
        .replaceAll(RegExp(r'key[=:]\s*\S+', caseSensitive: false), 'key=***')
        .replaceAll(RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'), '***IP***'); // IP addresses
  }
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning, 
  error,
  critical
}

/// Error report data class
class ErrorReport {
  final String type;
  final String message;
  final String sanitizedMessage;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic>? context;

  ErrorReport({
    required this.type,
    required this.message,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    required this.timestamp,
    this.context,
  }) : sanitizedMessage = _sanitizeMessage(message);

  factory ErrorReport.fromFlutterError(FlutterErrorDetails details) {
    return ErrorReport(
      type: 'Flutter',
      message: details.toString(),
      stackTrace: details.stack,
      severity: details.silent ? ErrorSeverity.warning : ErrorSeverity.error,
      timestamp: DateTime.now(),
      context: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
  }

  factory ErrorReport.fromDartError(Object error, StackTrace stack) {
    return ErrorReport(
      type: 'Dart',
      message: error.toString(),
      stackTrace: stack,
      severity: ErrorSeverity.critical,
      timestamp: DateTime.now(),
    );
  }

  static String _sanitizeMessage(String message) {
    // Remove sensitive information from error messages
    return message
        .replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '***EMAIL***')
        .replaceAll(RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'), '***IP***')
        .replaceAll(RegExp(r'password.*', caseSensitive: false), '***PASSWORD***');
  }
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'sanitizedMessage': sanitizedMessage,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'hasStackTrace': stackTrace != null,
    'context': context,
  };
}

/// Error statistics
class ErrorStatistics {
  final int totalErrors;
  final int recentErrors;
  final int criticalErrors;
  final Map<String, int> commonErrorTypes;

  const ErrorStatistics({
    required this.totalErrors,
    required this.recentErrors,
    required this.criticalErrors,
    required this.commonErrorTypes,
  });
  
  Map<String, dynamic> toJson() => {
    'totalErrors': totalErrors,
    'recentErrors': recentErrors,
    'criticalErrors': criticalErrors,
    'commonErrorTypes': commonErrorTypes,
  };
}