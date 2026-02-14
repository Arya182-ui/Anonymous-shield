import 'dart:async';
import 'package:logger/logger.dart';
import '../logging/production_logger.dart';
import '../../data/storage/secure_storage.dart';
import '../../platform/channels/optimized_method_channel.dart';
import '../../business_logic/managers/vpn_manager.dart';
import '../../business_logic/managers/enhanced_vpn_manager.dart';
import '../../business_logic/managers/wireguard_manager.dart';
import '../../business_logic/managers/proxy_manager.dart';
import '../../business_logic/managers/auto_vpn_config_manager.dart';
import '../../business_logic/services/security_manager.dart';

/// Lightweight app initializer that runs heavy work in the background
/// while the splash screen is already visible to the user.
class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  AppInitializer._internal();

  final ProductionLogger _logger = ProductionLogger();
  final Completer<bool> _initCompleter = Completer<bool>();

  bool _isStarted = false;
  bool get isComplete => _initCompleter.isCompleted;

  /// Future that completes when all background init is done.
  Future<bool> get ready => _initCompleter.future;

  /// Kick off all heavy initialization in the background.
  /// Safe to call multiple times — only runs once.
  void startBackgroundInit() {
    if (_isStarted) return;
    _isStarted = true;
    _runInit();
  }

  Future<void> _runInit() async {
    try {
      _logger.i('Background initialization starting...');
      final sw = Stopwatch()..start();

      // ── Phase 1: Secure storage (needed by others) ──
      try {
        final secureStorage = SecureStorage();
        await secureStorage.initialize().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            _logger.w('Secure storage timed out – using fallback');
            throw TimeoutException('Secure storage timeout');
          },
        );
        _logger.i('✓ Secure storage initialized');
      } catch (e) {
        _logger.e('✗ Secure storage init failed', error: e);
      }

      // ── Phase 2: Parallel batch – independent systems ──
      await Future.wait([
        _initEnhancedVpn(),
        _initWireGuard(),
        _initLegacyVpn(),
        _initSecurity(),
        _initProxy(),
        _initMethodChannels(),
      ]);

      // ── Phase 3: AutoVpnConfig – depends on WireGuard being ready ──
      await _initAutoVpn();

      sw.stop();
      _logger.i('Background initialization complete in ${sw.elapsedMilliseconds}ms');
      _initCompleter.complete(true);
    } catch (e, stack) {
      _logger.e('Background initialization failed', error: e, stackTrace: stack);
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(false);
      }
    }
  }

  // ─── Individual initializers ───────────────────────────

  Future<void> _initEnhancedVpn() async {
    try {
      final m = EnhancedVpnManager();
      await m.initialize().timeout(const Duration(seconds: 12));
      _logger.i('✓ Enhanced VPN Manager');
    } catch (e) {
      _logger.e('✗ Enhanced VPN Manager', error: e);
    }
  }

  Future<void> _initWireGuard() async {
    try {
      final m = WireGuardManager();
      await m.initialize().timeout(const Duration(seconds: 10));
      _logger.i('✓ WireGuard Manager');
    } catch (e) {
      _logger.e('✗ WireGuard Manager', error: e);
    }
  }

  Future<void> _initLegacyVpn() async {
    try {
      final m = VpnManager();
      await m.initialize().timeout(const Duration(seconds: 10));
      _logger.i('✓ Legacy VPN Manager');
    } catch (e) {
      _logger.e('✗ Legacy VPN Manager', error: e);
    }
  }

  Future<void> _initSecurity() async {
    try {
      final m = SecurityManager();
      final ok = await m.initialize().timeout(const Duration(seconds: 12));
      if (ok) {
        _logger.i('✓ Security Manager');
        try {
          await m.enableKillSwitch();
          await m.enableDnsLeakProtection();
          await m.enableIpv6Protection();
          _logger.i('✓ Security features enabled');
        } catch (e) {
          _logger.w('Some security features failed', error: e);
        }
      } else {
        _logger.w('✗ Security Manager init returned false');
      }
    } catch (e) {
      _logger.e('✗ Security Manager', error: e);
    }
  }

  Future<void> _initProxy() async {
    try {
      final m = ProxyManager();
      await m.initialize().timeout(const Duration(seconds: 10));
      _logger.i('✓ Proxy Manager');
    } catch (e) {
      _logger.e('✗ Proxy Manager', error: e);
    }
  }

  Future<void> _initAutoVpn() async {
    try {
      final m = AutoVpnConfigManager();
      await m.initialize().timeout(const Duration(seconds: 15));
      _logger.i('✓ Auto VPN Config Manager');
    } catch (e) {
      _logger.e('✗ Auto VPN Config Manager', error: e);
    }
  }

  Future<void> _initMethodChannels() async {
    try {
      await AppMethodChannels.initializeAll().timeout(const Duration(seconds: 8));
      _logger.i('✓ Method channels');
    } catch (e) {
      _logger.e('✗ Method channels', error: e);
    }
  }
}
