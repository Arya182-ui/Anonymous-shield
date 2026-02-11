import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Logger _logger = Logger();
  
  // Performance metrics
  final Map<String, PerformanceMetric> _metrics = {};
  final List<MemoryUsage> _memoryHistory = [];
  final List<NetworkMetric> _networkMetrics = [];
  
  Timer? _monitoringTimer;
  DateTime _sessionStart = DateTime.now();
  
  static const MethodChannel _channel = MethodChannel('privacy_vpn_controller/performance');

  /// Initialize performance monitoring
  Future<void> initialize() async {
    _sessionStart = DateTime.now();
    
    if (!AppConstants.debugMode) {
      // Start periodic monitoring in production
      _startPeriodicMonitoring();
    }
    
    _logger.i('Performance Monitor initialized');
  }

  /// Start periodic monitoring
  void _startPeriodicMonitoring() {
    _monitoringTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _collectSystemMetrics();
    });
  }

  /// Collect system performance metrics
  Future<void> _collectSystemMetrics() async {
    try {
      final memoryInfo = await _getMemoryUsage();
      final cpuUsage = await _getCpuUsage();
      final batteryInfo = await _getBatteryInfo();
      
      final usage = MemoryUsage(
        timestamp: DateTime.now(),
        usedMemoryMB: memoryInfo['used'] ?? 0,
        totalMemoryMB: memoryInfo['total'] ?? 0,
        cpuUsagePercent: cpuUsage,
        batteryLevel: batteryInfo['level'] ?? 0,
        isCharging: batteryInfo['charging'] ?? false,
      );
      
      _memoryHistory.add(usage);
      
      // Keep only last 24 hours of data
      final cutoff = DateTime.now().subtract(Duration(hours: 24));
      _memoryHistory.removeWhere((u) => u.timestamp.isBefore(cutoff));
      
      _checkPerformanceThresholds(usage);
      
    } catch (e) {
      _logger.w('Failed to collect system metrics: $e');
    }
  }

  /// Get memory usage info
  Future<Map<String, dynamic>> _getMemoryUsage() async {
    try {
      return await _channel.invokeMethod('getMemoryUsage');
    } catch (e) {
      _logger.w('Native memory info unavailable: $e');
      return {'used': 0, 'total': 0};
    }
  }

  /// Get CPU usage
  Future<double> _getCpuUsage() async {
    try {
      final result = await _channel.invokeMethod('getCpuUsage');
      return result?.toDouble() ?? 0.0;
    } catch (e) {
      _logger.w('Native CPU info unavailable: $e');
      return 0.0;
    }
  }

  /// Get battery info
  Future<Map<String, dynamic>> _getBatteryInfo() async {
    try {
      return await _channel.invokeMethod('getBatteryInfo');
    } catch (e) {
      _logger.w('Native battery info unavailable: $e');
      return {'level': 0, 'charging': false};
    }
  }

  /// Check performance thresholds
  void _checkPerformanceThresholds(MemoryUsage usage) {
    // High memory usage warning
    if (usage.memoryUsagePercent > 80.0) {
      _logger.w('High memory usage: ${usage.memoryUsagePercent.toStringAsFixed(1)}%');
    }
    
    // High CPU usage warning
    if (usage.cpuUsagePercent > 70.0) {
      _logger.w('High CPU usage: ${usage.cpuUsagePercent.toStringAsFixed(1)}%');
    }
    
    // Low battery warning when VPN active
    if (usage.batteryLevel < 15 && !usage.isCharging) {
      _logger.w('Low battery with VPN active: ${usage.batteryLevel}%');
    }
  }

  /// Start measuring operation performance
  PerformanceMeasurement startMeasurement(String operation) {
    final measurement = PerformanceMeasurement(operation);
    measurement.start();
    return measurement;
  }

  /// Record operation completion
  void recordOperation(String operation, Duration duration, {
    bool successful = true,
    String? errorType,
  }) {
    final metric = _metrics[operation] ??= PerformanceMetric(operation);
    metric.recordExecution(duration, successful, errorType);
  }

  /// Record network operation
  void recordNetworkOperation(String operation, {
    required int bytesTransferred,
    required Duration duration,
    required bool successful,
    String? errorType,
  }) {
    final metric = NetworkMetric(
      operation: operation,
      timestamp: DateTime.now(),
      bytesTransferred: bytesTransferred,
      duration: duration,
      successful: successful,
      errorType: errorType,
    );
    
    _networkMetrics.add(metric);
    
    // Keep only last 1000 network operations
    if (_networkMetrics.length > 1000) {
      _networkMetrics.removeAt(0);
    }
  }

  /// Get performance summary
  PerformanceSummary getSummary() {
    final sessionDuration = DateTime.now().difference(_sessionStart);
    
    return PerformanceSummary(
      sessionDuration: sessionDuration,
      operationMetrics: Map.unmodifiable(_metrics),
      currentMemoryUsage: _memoryHistory.isNotEmpty ? _memoryHistory.last : null,
      averageMemoryUsage: _calculateAverageMemoryUsage(),
      networkSummary: _calculateNetworkSummary(),
      errorRate: _calculateErrorRate(),
    );
  }

  /// Calculate average memory usage
  double _calculateAverageMemoryUsage() {
    if (_memoryHistory.isEmpty) return 0.0;
    
    final total = _memoryHistory
        .map((u) => u.memoryUsagePercent)
        .reduce((a, b) => a + b);
    
    return total / _memoryHistory.length;
  }

  /// Calculate network summary
  NetworkSummary _calculateNetworkSummary() {
    if (_networkMetrics.isEmpty) {
      return NetworkSummary(
        totalOperations: 0,
        totalBytes: 0,
        averageDuration: Duration.zero,
        successRate: 0.0,
      );
    }
    
    final totalBytes = _networkMetrics
        .map((m) => m.bytesTransferred)
        .reduce((a, b) => a + b);
    
    final totalDuration = _networkMetrics
        .map((m) => m.duration.inMilliseconds)
        .reduce((a, b) => a + b);
    
    final successfulOps = _networkMetrics.where((m) => m.successful).length;
    
    return NetworkSummary(
      totalOperations: _networkMetrics.length,
      totalBytes: totalBytes,
      averageDuration: Duration(milliseconds: totalDuration ~/ _networkMetrics.length),
      successRate: successfulOps / _networkMetrics.length * 100.0,
    );
  }

  /// Calculate overall error rate
  double _calculateErrorRate() {
    if (_metrics.isEmpty) return 0.0;
    
    int totalExecutions = 0;
    int totalErrors = 0;
    
    for (final metric in _metrics.values) {
      totalExecutions += metric.totalExecutions;
      totalErrors += metric.errorCount;
    }
    
    return totalExecutions > 0 ? (totalErrors / totalExecutions * 100.0) : 0.0;
  }

  /// Get memory usage trend
  List<MemoryUsage> getMemoryTrend({Duration? timeRange}) {
    if (timeRange == null) return List.unmodifiable(_memoryHistory);
    
    final cutoff = DateTime.now().subtract(timeRange);
    return _memoryHistory.where((u) => u.timestamp.isAfter(cutoff)).toList();
  }

  /// Check if performance is degraded
  bool isPerformanceDegraded() {
    final summary = getSummary();
    
    return summary.averageMemoryUsage > 75.0 || 
           summary.errorRate > 5.0 ||
           (summary.currentMemoryUsage?.cpuUsagePercent ?? 0) > 80.0;
  }

  /// Reset performance metrics
  void reset() {
    _metrics.clear();
    _memoryHistory.clear();
    _networkMetrics.clear();
    _sessionStart = DateTime.now();
    _logger.i('Performance metrics reset');
  }

  /// Dispose performance monitor
  void dispose() {
    _monitoringTimer?.cancel();
    _logger.d('Performance Monitor disposed');
  }
}

/// Performance measurement helper
class PerformanceMeasurement {
  final String operation;
  late DateTime _startTime;
  
  PerformanceMeasurement(this.operation);
  
  void start() {
    _startTime = DateTime.now();
  }
  
  Duration stop() {
    final duration = DateTime.now().difference(_startTime);
    PerformanceMonitor().recordOperation(operation, duration);
    return duration;
  }
  
  Duration stopWithResult(bool successful, {String? errorType}) {
    final duration = DateTime.now().difference(_startTime);
    PerformanceMonitor().recordOperation(operation, duration, 
        successful: successful, errorType: errorType);
    return duration;
  }
}

/// Performance metric for operations
class PerformanceMetric {
  final String operation;
  final List<Duration> _executionTimes = [];
  final List<String> _errorTypes = [];
  int _successCount = 0;
  int _errorCount = 0;
  
  PerformanceMetric(this.operation);
  
  void recordExecution(Duration duration, bool successful, String? errorType) {
    _executionTimes.add(duration);
    
    if (successful) {
      _successCount++;
    } else {
      _errorCount++;
      if (errorType != null) {
        _errorTypes.add(errorType);
      }
    }
    
    // Keep only last 100 executions
    if (_executionTimes.length > 100) {
      _executionTimes.removeAt(0);
    }
  }
  
  Duration get averageExecutionTime {
    if (_executionTimes.isEmpty) return Duration.zero;
    
    final total = _executionTimes
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
        
    return Duration(milliseconds: total ~/ _executionTimes.length);
  }
  
  Duration? get maxExecutionTime => 
      _executionTimes.isEmpty ? null : 
      _executionTimes.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  
  Duration? get minExecutionTime => 
      _executionTimes.isEmpty ? null : 
      _executionTimes.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  
  double get successRate => 
      totalExecutions > 0 ? (_successCount / totalExecutions * 100.0) : 0.0;
  
  int get totalExecutions => _successCount + _errorCount;
  int get errorCount => _errorCount;
  
  Map<String, int> get errorTypeCounts {
    final counts = <String, int>{};
    for (final type in _errorTypes) {
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }
}

/// Memory usage data
class MemoryUsage {
  final DateTime timestamp;
  final int usedMemoryMB;
  final int totalMemoryMB;
  final double cpuUsagePercent;
  final int batteryLevel;
  final bool isCharging;
  
  const MemoryUsage({
    required this.timestamp,
    required this.usedMemoryMB,
    required this.totalMemoryMB,
    required this.cpuUsagePercent,
    required this.batteryLevel,
    required this.isCharging,
  });
  
  double get memoryUsagePercent => 
      totalMemoryMB > 0 ? (usedMemoryMB / totalMemoryMB * 100.0) : 0.0;
}

/// Network operation metric
class NetworkMetric {
  final String operation;
  final DateTime timestamp;
  final int bytesTransferred;
  final Duration duration;
  final bool successful;
  final String? errorType;
  
  const NetworkMetric({
    required this.operation,
    required this.timestamp,
    required this.bytesTransferred,
    required this.duration,
    required this.successful,
    this.errorType,
  });
  
  double get transferRateMBps => 
      duration.inMilliseconds > 0 ? 
      (bytesTransferred / 1024 / 1024) / (duration.inMilliseconds / 1000) : 0.0;
}

/// Network operations summary
class NetworkSummary {
  final int totalOperations;
  final int totalBytes;
  final Duration averageDuration;
  final double successRate;
  
  const NetworkSummary({
    required this.totalOperations,
    required this.totalBytes,
    required this.averageDuration,
    required this.successRate,
  });
  
  double get totalMB => totalBytes / 1024 / 1024;
}

/// Overall performance summary
class PerformanceSummary {
  final Duration sessionDuration;
  final Map<String, PerformanceMetric> operationMetrics;
  final MemoryUsage? currentMemoryUsage;
  final double averageMemoryUsage;
  final NetworkSummary networkSummary;
  final double errorRate;
  
  const PerformanceSummary({
    required this.sessionDuration,
    required this.operationMetrics,
    required this.currentMemoryUsage,
    required this.averageMemoryUsage,
    required this.networkSummary,
    required this.errorRate,
  });
  
  Map<String, dynamic> toJson() => {
    'sessionDurationMinutes': sessionDuration.inMinutes,
    'operationCount': operationMetrics.length,
    'currentMemoryUsageMB': currentMemoryUsage?.usedMemoryMB,
    'averageMemoryUsagePercent': averageMemoryUsage.toStringAsFixed(1),
    'networkOperations': networkSummary.totalOperations,
    'networkSuccessRate': networkSummary.successRate.toStringAsFixed(1),
    'overallErrorRate': errorRate.toStringAsFixed(1),
  };
}