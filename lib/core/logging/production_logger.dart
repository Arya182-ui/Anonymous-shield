import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../error_handling/production_error_handler.dart';

/// Production-Grade Comprehensive Logging System
/// Provides structured logging, performance monitoring, and analytics
class ProductionLogger {
  static final ProductionLogger _instance = ProductionLogger._internal();
  factory ProductionLogger() => _instance;
  ProductionLogger._internal();

  late Logger _logger;
  late File _logFile;
  late File _performanceLogFile;
  late File _securityLogFile;
  
  Timer? _logRotationTimer;
  Timer? _performanceTimer;
  
  bool _isInitialized = false;
  bool _enableFileLogging = true;
  bool _enablePerformanceLogging = true;
  bool _enableSecurityLogging = true;
  
  // Performance tracking
  final Map<String, PerformanceMetric> _performanceMetrics = {};
  final List<LogEvent> _recentEvents = [];
  
  // Log filtering for production
  Level _minLogLevel = Level.info;
  final Set<String> _sensitiveKeywords = {
    'password', 'token', 'key', 'secret', 'private',
    'vpn_config', 'server_list', 'user_id'
  };

  /// Initialize comprehensive logging system
  Future<bool> initialize({
    Level? minLevel,
    bool? enableFileLogging,
    bool? enablePerformanceLogging,
    bool? enableSecurityLogging,
  }) async {
    if (_isInitialized) return true;

    try {
      _minLogLevel = minLevel ?? Level.info;
      _enableFileLogging = enableFileLogging ?? true;
      _enablePerformanceLogging = enablePerformanceLogging ?? true;
      _enableSecurityLogging = enableSecurityLogging ?? true;

      // Initialize logger with custom output
      _logger = Logger(
        filter: ProductionFilter(_minLogLevel),
        printer: ProductionPrinter(),
        output: MultiOutput([
          ConsoleOutput(),
          if (_enableFileLogging) FileOutput(_getLogFile),
        ]),
        level: _minLogLevel,
      );

      // Initialize log files
      if (_enableFileLogging) {
        await _initializeLogFiles();
      }

      // Start log rotation
      _startLogRotation();

      // Start performance monitoring
      if (_enablePerformanceLogging) {
        _startPerformanceMonitoring();
      }

      _isInitialized = true;
      _logger.i('Production logging system initialized');
      return true;

    } catch (e) {
      print('Failed to initialize logging: $e');
      return false;
    }
  }

  /// Initialize log files with proper organization
  Future<void> _initializeLogFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      _logFile = File('${logDir.path}/app_$timestamp.log');
      _performanceLogFile = File('${logDir.path}/performance_$timestamp.log');
      _securityLogFile = File('${logDir.path}/security_$timestamp.log');

    } catch (e) {
      print('Failed to initialize log files: $e');
      _enableFileLogging = false;
    }
  }

  /// Get current log file
  File _getLogFile() => _logFile;

  /// Log debug message
  void d(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logEvent(Level.debug, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log info message  
  void i(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logEvent(Level.info, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log warning message
  void w(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logEvent(Level.warning, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log error message
  void e(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logEvent(Level.error, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log fatal/critical message
  void f(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _logEvent(Level.fatal, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log VPN-specific events
  void vpn(String event, String message, {Map<String, dynamic>? data}) {
    final vpnData = {
      'category': 'VPN',
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      ...?data,
    };
    _logEvent(Level.info, '[VPN] $event: $message', data: vpnData);
  }

  /// Log security events
  void security(String event, String message, {SecurityLevel? level, Map<String, dynamic>? data}) {
    final securityLevel = level ?? SecurityLevel.info;
    final securityData = {
      'category': 'SECURITY',
      'event': event,
      'security_level': securityLevel.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      ...?data,
    };

    final logLevel = _mapSecurityLevel(securityLevel);
    _logEvent(logLevel, '[SECURITY] $event: $message', data: securityData);

    // Write to dedicated security log
    if (_enableSecurityLogging) {
      _writeSecurityLog(event, message, securityLevel, securityData);
    }
  }

  /// Log performance metrics
  void performance(String operation, Duration duration, {Map<String, dynamic>? metrics}) {
    final performanceData = {
      'category': 'PERFORMANCE',
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
      ...?metrics,
    };

    _logEvent(Level.debug, '[PERF] $operation completed in ${duration.inMilliseconds}ms', 
      data: performanceData);

    // Track performance metrics
    _trackPerformanceMetric(operation, duration, metrics);
  }

  /// Log network events
  void network(String event, String message, {String? endpoint, int? statusCode, Map<String, dynamic>? data}) {
    final networkData = {
      'category': 'NETWORK',
      'event': event,
      'endpoint': endpoint,
      'status_code': statusCode,
      'timestamp': DateTime.now().toIso8601String(),
      ...?data,
    };
    _logEvent(Level.info, '[NETWORK] $event: $message', data: networkData);
  }

  /// Core logging method with filtering and enhancement
  void _logEvent(Level level, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    if (!_isInitialized) return;

    try {
      // Filter sensitive data
      final sanitizedMessage = _sanitizeMessage(message);
      final sanitizedData = _sanitizeData(data);

      // Create log event
      final logEvent = LogEvent(
        level: level,
        message: sanitizedMessage,
        timestamp: DateTime.now(),
        error: error,
        stackTrace: stackTrace,
        data: sanitizedData,
      );

      // Add to recent events
      _recentEvents.add(logEvent);
      if (_recentEvents.length > 100) {
        _recentEvents.removeAt(0);
      }

      // Use logger
      switch (level) {
        case Level.debug:
          _logger.d(sanitizedMessage, error: error, stackTrace: stackTrace);
          break;
        case Level.info:
          _logger.i(sanitizedMessage, error: error, stackTrace: stackTrace);
          break;
        case Level.warning:
          _logger.w(sanitizedMessage, error: error, stackTrace: stackTrace);
          break;
        case Level.error:
          _logger.e(sanitizedMessage, error: error, stackTrace: stackTrace);
          break;
        case Level.fatal:
          _logger.f(sanitizedMessage, error: error, stackTrace: stackTrace);
          break;
        default:
          _logger.i(sanitizedMessage, error: error, stackTrace: stackTrace);
      }

      // Report critical errors
      if (level == Level.error || level == Level.fatal) {
        ProductionErrorHandler().reportError(
          error: error ?? Exception(sanitizedMessage),
          stackTrace: stackTrace,
          context: 'Logger',
          additionalData: sanitizedData,
        );
      }

    } catch (e) {
      // Fallback logging if main logger fails
      print('Logging failed: $e');
      print('Original message: $message');
    }
  }

  /// Sanitize message to remove sensitive information
  String _sanitizeMessage(String message) {
    String sanitized = message;
    
    for (final keyword in _sensitiveKeywords) {
      // Replace sensitive patterns with [REDACTED]
      final pattern = RegExp('($keyword[\\s:=]+)([^\\s,}])+', caseSensitive: false);
      sanitized = sanitized.replaceAll(pattern, '\$1[REDACTED]');
    }

    // Remove IP addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
      '[IP_REDACTED]'
    );

    return sanitized;
  }

  /// Sanitize data map to remove sensitive information
  Map<String, dynamic>? _sanitizeData(Map<String, dynamic>? data) {
    if (data == null) return null;

    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      if (_isSensitiveKey(entry.key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  /// Check if key contains sensitive information
  bool _isSensitiveKey(String key) {
    return _sensitiveKeywords.any((keyword) => 
      key.toLowerCase().contains(keyword));
  }

  /// Map security level to log level
  Level _mapSecurityLevel(SecurityLevel securityLevel) {
    switch (securityLevel) {
      case SecurityLevel.critical:
        return Level.fatal;
      case SecurityLevel.high:
        return Level.error;
      case SecurityLevel.medium:
        return Level.warning;
      case SecurityLevel.low:
      case SecurityLevel.info:
        return Level.info;
    }
  }

  /// Write to dedicated security log file
  Future<void> _writeSecurityLog(String event, String message, SecurityLevel level, Map<String, dynamic> data) async {
    if (!_enableSecurityLogging) return;

    try {
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': level.toString(),
        'event': event,
        'message': message,
        'data': data,
      };

      await _securityLogFile.writeAsString(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      print('Failed to write security log: $e');
    }
  }

  /// Track performance metrics for analysis
  void _trackPerformanceMetric(String operation, Duration duration, Map<String, dynamic>? metrics) {
    if (!_enablePerformanceLogging) return;

    final existing = _performanceMetrics[operation];
    if (existing != null) {
      existing.addMeasurement(duration, metrics);
    } else {
      _performanceMetrics[operation] = PerformanceMetric(operation)
        ..addMeasurement(duration, metrics);
    }
  }

  /// Start log rotation to manage file sizes
  void _startLogRotation() {
    _logRotationTimer = Timer.periodic(Duration(hours: 6), (timer) async {
      await _rotateLogsIfNeeded();
    });
  }

  /// Rotate logs if they exceed size limits
  Future<void> _rotateLogsIfNeeded() async {
    if (!_enableFileLogging) return;

    try {
      const maxFileSize = 10 * 1024 * 1024; // 10 MB

      if (await _logFile.length() > maxFileSize) {
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
        final archiveName = '${_logFile.path}.$timestamp.archive';
        await _logFile.rename(archiveName);
        
        // Create new log file
        await _initializeLogFiles();
        i('Log rotated - archived to: $archiveName');
      }

      // Clean old archives (keep last 7 days)
      await _cleanOldArchives();

    } catch (e) {
      e('Log rotation failed: $e');
    }
  }

  /// Clean old log archives
  Future<void> _cleanOldArchives() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/logs');
      
      final cutoffTime = DateTime.now().subtract(Duration(days: 7));
      
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.contains('.archive')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await entity.delete();
            d('Deleted old log archive: ${entity.path}');
          }
        }
      }
    } catch (e) {
      e('Archive cleanup failed: $e');
    }
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _analyzePerformanceMetrics();
    });
  }

  /// Analyze performance metrics for insights
  void _analyzePerformanceMetrics() {
    if (_performanceMetrics.isEmpty) return;

    try {
      final analysisData = <String, dynamic>{};
      
      for (final metric in _performanceMetrics.values) {
        analysisData[metric.operation] = {
          'avg_duration_ms': metric.averageDuration.inMilliseconds,
          'max_duration_ms': metric.maxDuration.inMilliseconds,
          'min_duration_ms': metric.minDuration.inMilliseconds,
          'call_count': metric.callCount,
        };

        // Alert on performance degradation
        if (metric.averageDuration > Duration(milliseconds: 5000)) {
          w('Performance degradation detected for ${metric.operation}: ${metric.averageDuration.inMilliseconds}ms avg');
        }
      }

      // Write performance analysis to file
      _writePerformanceAnalysis(analysisData);

    } catch (e) {
      e('Performance analysis failed: $e');
    }
  }

  /// Write performance analysis to file
  Future<void> _writePerformanceAnalysis(Map<String, dynamic> analysis) async {
    if (!_enablePerformanceLogging) return;

    try {
      final analysisEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'analysis': analysis,
      };

      await _performanceLogFile.writeAsString(
        '${jsonEncode(analysisEntry)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      print('Failed to write performance analysis: $e');
    }
  }

  /// Get logging statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _isInitialized,
      'min_log_level': _minLogLevel.toString(),
      'recent_events_count': _recentEvents.length,
      'performance_metrics_count': _performanceMetrics.length,
      'configuration': {
        'file_logging': _enableFileLogging,
        'performance_logging': _enablePerformanceLogging,
        'security_logging': _enableSecurityLogging,
      },
      'file_info': _enableFileLogging ? {
        'main_log': _logFile.path,
        'performance_log': _performanceLogFile.path,
        'security_log': _securityLogFile.path,
      } : null,
    };
  }

  /// Export recent logs for debugging
  List<Map<String, dynamic>> exportRecentLogs({int? limit}) {
    final exportLimit = limit ?? 50;
    return _recentEvents
        .take(exportLimit)
        .map((event) => event.toMap())
        .toList();
  }

  /// Flush all pending log writes
  Future<void> flush() async {
    // Implementation would flush any pending writes
    // This is a placeholder for actual flush logic
  }

  /// Dispose resources
  void dispose() {
    _logRotationTimer?.cancel();
    _performanceTimer?.cancel();
    _performanceMetrics.clear();
    _recentEvents.clear();
    _isInitialized = false;
  }
}

/// Security logging levels
enum SecurityLevel { info, low, medium, high, critical }

/// Log event model
class LogEvent {
  final Level level;
  final String message;
  final DateTime timestamp;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? data;

  const LogEvent({
    required this.level,
    required this.message,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'level': level.toString(),
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'error': error?.toString(),
      'has_stack_trace': stackTrace != null,
      'data': data,
    };
  }
}

/// Performance metric tracking
class PerformanceMetric {
  final String operation;
  final List<Duration> _measurements = [];
  int get callCount => _measurements.length;

  PerformanceMetric(this.operation);

  void addMeasurement(Duration duration, Map<String, dynamic>? metrics) {
    _measurements.add(duration);
    if (_measurements.length > 100) {
      _measurements.removeAt(0);
    }
  }

  Duration get averageDuration {
    if (_measurements.isEmpty) return Duration.zero;
    final totalMs = _measurements.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ _measurements.length);
  }

  Duration get maxDuration => _measurements.isEmpty 
    ? Duration.zero 
    : _measurements.reduce((a, b) => a > b ? a : b);

  Duration get minDuration => _measurements.isEmpty
    ? Duration.zero
    : _measurements.reduce((a, b) => a < b ? a : b);
}

/// Production log filter
class ProductionFilter extends LogFilter {
  final Level minLevel;
  
  ProductionFilter(this.minLevel);

  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= minLevel.index;
  }
}

/// Production log printer with structured output
class ProductionPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.time);
    final level = event.level.toString().toUpperCase();
    
    return [
      '[$timestamp] [$level] ${event.message}'
    ];
  }
}

/// Multi-output logger for console and file
class MultiOutput extends LogOutput {
  final List<LogOutput> outputs;
  
  MultiOutput(this.outputs);

  @override
  void output(OutputEvent event) {
    for (final output in outputs) {
      try {
        output.output(event);
      } catch (e) {
        // Continue with other outputs even if one fails
      }
    }
  }
}

/// File output for persistent logging
class FileOutput extends LogOutput {
  final File Function() getFile;
  
  FileOutput(this.getFile);

  @override
  void output(OutputEvent event) {
    try {
      final file = getFile();
      final logLine = '${event.lines.join('\n')}\n';
      file.writeAsStringSync(logLine, mode: FileMode.append);
    } catch (e) {
      // Fail silently for file logging errors
    }
  }
}