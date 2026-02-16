import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Real IP information fetched from external APIs
class IpInfo {
  final String ip;
  final String? city;
  final String? region;
  final String? country;
  final String? countryCode;
  final String? org;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final DateTime fetchedAt;

  const IpInfo({
    required this.ip,
    this.city,
    this.region,
    this.country,
    this.countryCode,
    this.org,
    this.timezone,
    this.latitude,
    this.longitude,
    required this.fetchedAt,
  });

  String get displayLocation {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    if (parts.isEmpty) return 'Unknown';
    return parts.join(', ');
  }

  bool get isCloudflare =>
      org != null && org!.toLowerCase().contains('cloudflare');

  @override
  String toString() => 'IpInfo($ip, $displayLocation, org: $org)';
}

/// Service to check real public IP and geolocation via external APIs.
/// This shows the ACTUAL IP that websites see — not a fake in-app display.
///
/// API selection notes:
/// - All APIs use HTTPS to avoid WARP/Cloudflare blocking plain HTTP.
/// - Avoid 1.1.1.1/cdn-cgi/trace — routing conflict when going through WARP
///   (traffic to 1.1.1.1 loops since WARP IS Cloudflare).
/// - Avoid ip-api.com — HTTP-only free tier, blocked by WARP.
class IpInfoService {
  static final IpInfoService _instance = IpInfoService._internal();
  factory IpInfoService() => _instance;
  IpInfoService._internal();

  final Logger _logger = Logger();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 10),
  ));

  IpInfo? _lastResult;
  IpInfo? get lastResult => _lastResult;

  /// Wait for VPN tunnel to actually pass traffic before checking IP.
  /// Returns true if tunnel is ready.
  Future<bool> _waitForTunnelReady({int maxAttempts = 3}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        // Use a tiny HTTPS request to test if traffic flows through tunnel
        final resp = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        )).head('https://www.gstatic.com/generate_204');
        if (resp.statusCode == 204 || resp.statusCode == 200) {
          _logger.i('Tunnel ready (attempt ${i + 1})');
          return true;
        }
      } catch (_) {
        _logger.d('Tunnel not ready yet (attempt ${i + 1}/$maxAttempts)');
        if (i < maxAttempts - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    }
    return false;
  }

  /// Fetch real public IP info from multiple fallback APIs.
  /// [retryDelay] — if all APIs fail, wait and retry once (for VPN tunnel warmup).
  /// [waitForTunnel] — if true, first probe the tunnel before calling IP APIs.
  Future<IpInfo?> fetchCurrentIpInfo({
    bool retry = true,
    bool waitForTunnel = false,
  }) async {
    // If requested, wait until the VPN tunnel is actually passing traffic
    if (waitForTunnel) {
      final ready = await _waitForTunnelReady();
      if (!ready) {
        _logger.w('Tunnel not ready after probes, trying IP APIs anyway...');
      }
    }

    // Try multiple HTTPS APIs in order of reliability
    // All HTTPS — avoids WARP blocking HTTP and Cloudflare/1.1.1.1 routing conflicts
    final apis = [
      _fetchFromIpify,        // Fast, simple, always works over HTTPS
      _fetchFromIpInfo,        // Rich geo data
      _fetchFromSeeIp,         // Lightweight HTTPS fallback
      _fetchFromIfConfig,      // Another reliable HTTPS option
    ];

    for (final apiFn in apis) {
      try {
        final result = await apiFn();
        if (result != null) {
          _lastResult = result;
          _logger.i('IP check: ${result.ip} -> ${result.displayLocation} (${result.org})');
          return result;
        }
      } catch (e) {
        _logger.w('IP API failed, trying next: $e');
      }
    }

    // All failed — if VPN just connected the tunnel might not be fully ready.
    if (retry) {
      _logger.w('All IP APIs failed, retrying in 5s (tunnel warmup)...');
      await Future.delayed(const Duration(seconds: 5));
      return fetchCurrentIpInfo(retry: false, waitForTunnel: false);
    }

    _logger.e('All IP check APIs failed');
    return null;
  }

  /// api.ipify.org - HTTPS, fast, always works, no rate limit concerns
  Future<IpInfo?> _fetchFromIpify() async {
    final resp = await _dio.get('https://api.ipify.org?format=json');

    if (resp.statusCode == 200 && resp.data is Map) {
      final d = resp.data as Map<String, dynamic>;
      final ip = d['ip'] as String?;
      if (ip != null && ip.isNotEmpty) {
        return IpInfo(
          ip: ip,
          fetchedAt: DateTime.now(),
        );
      }
    }
    return null;
  }

  /// ipinfo.io - free (50k req/month), rich geo data, HTTPS
  Future<IpInfo?> _fetchFromIpInfo() async {
    final resp = await _dio.get(
      'https://ipinfo.io/json',
      options: Options(headers: {'Accept': 'application/json'}),
    );

    if (resp.statusCode == 200 && resp.data is Map) {
      final d = resp.data as Map<String, dynamic>;
      double? lat, lon;
      final loc = d['loc'] as String?;
      if (loc != null && loc.contains(',')) {
        final parts = loc.split(',');
        lat = double.tryParse(parts[0]);
        lon = double.tryParse(parts[1]);
      }
      return IpInfo(
        ip: d['ip'] ?? '',
        city: d['city'],
        region: d['region'],
        country: d['country'],
        countryCode: d['country'],
        org: d['org'],
        timezone: d['timezone'],
        latitude: lat,
        longitude: lon,
        fetchedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// api.seeip.org - HTTPS, simple, no key needed
  Future<IpInfo?> _fetchFromSeeIp() async {
    final resp = await _dio.get('https://api.seeip.org/jsonip?');

    if (resp.statusCode == 200 && resp.data is Map) {
      final d = resp.data as Map<String, dynamic>;
      final ip = d['ip'] as String?;
      if (ip != null && ip.isNotEmpty) {
        return IpInfo(
          ip: ip,
          fetchedAt: DateTime.now(),
        );
      }
    }
    return null;
  }

  /// ifconfig.me - HTTPS, widely used, returns IP as plain text
  Future<IpInfo?> _fetchFromIfConfig() async {
    final resp = await _dio.get(
      'https://ifconfig.me/ip',
      options: Options(
        headers: {'Accept': 'text/plain'},
        responseType: ResponseType.plain,
      ),
    );

    if (resp.statusCode == 200 && resp.data is String) {
      final ip = (resp.data as String).trim();
      if (ip.isNotEmpty && ip.length < 50) {
        return IpInfo(
          ip: ip,
          fetchedAt: DateTime.now(),
        );
      }
    }
    return null;
  }
}
