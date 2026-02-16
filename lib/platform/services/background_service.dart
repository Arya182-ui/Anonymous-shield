import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Background service helper for ensuring VPN/Ghost mode
/// continues running when the app is in the background.
///
/// Handles:
/// - Battery optimization exemption (prevents Android from killing the service)
/// - Background execution checks
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final Logger _logger = Logger();

  static const MethodChannel _systemChannel =
      MethodChannel('com.privacyvpn.privacy_vpn_controller/system');

  /// Check if app is exempted from battery optimization
  Future<bool> isBatteryOptimizationExempted() async {
    try {
      final result = await _systemChannel.invokeMethod<Map>(
        'isBatteryOptimizationExempted',
      );
      return result?['exempted'] == true;
    } catch (e) {
      _logger.w('Could not check battery optimization: $e');
      return false;
    }
  }

  /// Request user to exempt app from battery optimization.
  /// Opens Android system dialog directly.
  /// Returns true if the request was shown to the user.
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await _systemChannel.invokeMethod<Map>(
        'requestBatteryOptimizationExemption',
      );
      if (result?['alreadyExempted'] == true) {
        _logger.i('Battery optimization already exempted');
        return false; // No need to show — already good
      }
      return result?['requested'] == true;
    } catch (e) {
      _logger.e('Failed to request battery optimization exemption: $e');
      return false;
    }
  }

  /// Ensure battery optimization is disabled for reliable background operation.
  /// Call this before starting Ghost mode or any long-running VPN.
  Future<void> ensureBackgroundPermissions() async {
    final exempted = await isBatteryOptimizationExempted();
    if (!exempted) {
      _logger.i('Battery optimization not exempted — requesting');
      await requestBatteryOptimizationExemption();
    } else {
      _logger.d('Battery optimization already exempted');
    }
  }
}
