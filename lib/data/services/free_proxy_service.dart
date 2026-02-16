import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// A tested, working free SOCKS5 proxy
class FreeProxy {
  final String host;
  final int port;
  final int latencyMs;
  final String? countryCode;
  final DateTime testedAt;

  const FreeProxy({
    required this.host,
    required this.port,
    required this.latencyMs,
    this.countryCode,
    required this.testedAt,
  });

  String get address => '$host:$port';

  @override
  String toString() => 'FreeProxy($host:$port, ${latencyMs}ms, $countryCode)';
}

/// Fetches and tests free SOCKS5 proxies from open-source GitHub lists.
/// Used as fallback when Tor is unavailable or blocked.
class FreeProxyService {
  static final FreeProxyService _instance = FreeProxyService._internal();
  factory FreeProxyService() => _instance;
  FreeProxyService._internal();

  final Logger _logger = Logger();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  final Random _random = Random.secure();

  /// Cached working proxies
  List<FreeProxy> _cachedProxies = [];
  DateTime? _lastFetchTime;

  /// Open-source SOCKS5 proxy list URLs
  static const List<String> _proxyListUrls = [
    'https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/socks5.txt',
    'https://raw.githubusercontent.com/ShiftyTR/Proxy-List/master/socks5.txt',
    'https://raw.githubusercontent.com/hookzof/socks5_list/master/proxy.txt',
    'https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks5.txt',
    'https://raw.githubusercontent.com/jetkai/proxy-list/main/online-proxies/txt/proxies-socks5.txt',
  ];

  /// Cache validity duration
  static const Duration _cacheValidity = Duration(minutes: 30);

  /// Get working proxies (from cache or fresh fetch + test)
  Future<List<FreeProxy>> getWorkingProxies({
    int count = 5,
    List<String> excludeCountries = const [],
    Duration testTimeout = const Duration(seconds: 5),
  }) async {
    // Return cache if still valid
    if (_cachedProxies.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidity) {
      _logger.d('Returning ${_cachedProxies.length} cached proxies');
      var result = _cachedProxies;
      if (excludeCountries.isNotEmpty) {
        result = result
            .where((p) =>
                p.countryCode == null ||
                !excludeCountries.contains(p.countryCode))
            .toList();
      }
      return result.take(count).toList();
    }

    return await _fetchAndTestProxies(
      count: count,
      excludeCountries: excludeCountries,
      testTimeout: testTimeout,
    );
  }

  /// Get a single random working proxy
  Future<FreeProxy?> getRandomProxy({
    List<String> excludeCountries = const [],
  }) async {
    final proxies = await getWorkingProxies(
      count: 3,
      excludeCountries: excludeCountries,
    );
    if (proxies.isEmpty) return null;
    return proxies[_random.nextInt(proxies.length)];
  }

  /// Fetch proxy lists and test them
  Future<List<FreeProxy>> _fetchAndTestProxies({
    int count = 5,
    List<String> excludeCountries = const [],
    Duration testTimeout = const Duration(seconds: 3),
  }) async {
    _logger.i('Fetching fresh SOCKS5 proxy lists...');

    final rawProxies = <String>{};

    // Fetch from multiple sources in parallel (with individual timeouts)
    final futures = _proxyListUrls.map((url) => _fetchProxyList(url));
    final results = await Future.wait(futures);

    for (final list in results) {
      rawProxies.addAll(list);
    }

    _logger.i('Fetched ${rawProxies.length} raw proxies, testing...');

    if (rawProxies.isEmpty) {
      _logger.w('No proxies fetched from any source');
      return [];
    }

    // Shuffle and take a smaller batch to test (speed > coverage)
    final shuffled = rawProxies.toList()..shuffle(_random);
    final testBatch = shuffled.take(30).toList(); // Test max 30 (was 50)

    // Test proxies in parallel batches of 15 (was 10) with early exit
    final workingProxies = <FreeProxy>[];
    for (int i = 0; i < testBatch.length && workingProxies.length < count; i += 15) {
      final batch = testBatch.skip(i).take(15);
      final testFutures = batch.map((proxy) => _testProxy(proxy, testTimeout));
      final testResults = await Future.wait(testFutures);

      for (final result in testResults) {
        if (result != null) {
          workingProxies.add(result);
        }
      }

      // Early exit: stop testing once we have enough
      if (workingProxies.length >= count) break;
    }

    // Sort by latency
    workingProxies.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));

    // Filter by excluded countries
    var filtered = workingProxies;
    if (excludeCountries.isNotEmpty) {
      filtered = workingProxies
          .where((p) =>
              p.countryCode == null ||
              !excludeCountries.contains(p.countryCode))
          .toList();
    }

    // Cache results
    _cachedProxies = filtered;
    _lastFetchTime = DateTime.now();

    _logger.i('Found ${filtered.length} working proxies');
    return filtered.take(count).toList();
  }

  /// Fetch a single proxy list URL
  Future<List<String>> _fetchProxyList(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data is String) {
        final lines = (response.data as String)
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e.contains(':'))
            .where((e) {
          // Basic validation: host:port format
          final parts = e.split(':');
          if (parts.length != 2) return false;
          final port = int.tryParse(parts[1]);
          return port != null && port > 0 && port <= 65535;
        }).toList();

        _logger.d('Fetched ${lines.length} proxies from $url');
        return lines;
      }
    } catch (e) {
      _logger.w('Failed to fetch proxy list from $url: $e');
    }
    return [];
  }

  /// Test a single SOCKS5 proxy with handshake validation
  Future<FreeProxy?> _testProxy(String proxyStr, Duration timeout) async {
    final parts = proxyStr.split(':');
    if (parts.length != 2) return null;

    final host = parts[0];
    final port = int.tryParse(parts[1]);
    if (port == null) return null;

    Socket? socket;
    try {
      final sw = Stopwatch()..start();

      // Connect to proxy
      socket = await Socket.connect(host, port, timeout: timeout);

      // SOCKS5 greeting: version=5, 1 auth method, no-auth
      socket.add([0x05, 0x01, 0x00]);
      await socket.flush();

      // Wait for response with timeout
      final response = await socket.first.timeout(timeout);

      sw.stop();

      // Validate SOCKS5 response: version=5, method=0 (no auth)
      if (response.length >= 2 && response[0] == 0x05 && response[1] == 0x00) {
        return FreeProxy(
          host: host,
          port: port,
          latencyMs: sw.elapsedMilliseconds,
          testedAt: DateTime.now(),
        );
      }
    } catch (_) {
      // Proxy failed — silently ignore
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
    return null;
  }

  /// Clear the proxy cache
  void clearCache() {
    _cachedProxies.clear();
    _lastFetchTime = null;
    _logger.d('Proxy cache cleared');
  }

  /// Get number of cached proxies
  int get cachedCount => _cachedProxies.length;
}
