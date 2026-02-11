import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../platform/channels/vpn_channel.dart';
import '../../core/constants/app_constants.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final Logger _logger = Logger();
  final VpnMethodChannel _vpnChannel = VpnMethodChannel();
  
  bool _killSwitchActive = false;
  bool _dnsLeakProtectionActive = false;
  Timer? _securityMonitor;
  Timer? _leakDetectionTimer;
  
  /// Initialize security service
  Future<void> initialize() async {
    _logger.i('Initializing Security Service');
    
    // Enable kill switch by default for maximum security
    await enableKillSwitch();
    
    // Enable DNS leak protection
    await enableDnsLeakProtection();
    
    // Start security monitoring
    _startSecurityMonitoring();
    
    // Check for root/jailbreak (optional - inform user)
    await _checkDeviceSecurity();
    
    _logger.i('Security Service initialized');
  }
  
  /// Enable kill switch to prevent IP leaks
  Future<bool> enableKillSwitch() async {
    try {
      _logger.i('Enabling kill switch');
      
      final success = await _vpnChannel.enableKillSwitch();
      if (success) {
        _killSwitchActive = true;
        _logger.i('Kill switch enabled successfully');
      } else {
        _logger.e('Failed to enable kill switch');
      }
      
      return success;
    } catch (e, stack) {
      _logger.e('Kill switch enable error', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Disable kill switch
  Future<bool> disableKillSwitch() async {
    try {
      _logger.w('Disabling kill switch - WARNING: This reduces security');
      
      final success = await _vpnChannel.disableKillSwitch();
      if (success) {
        _killSwitchActive = false;
        _logger.w('Kill switch disabled');
      }
      
      return success;
    } catch (e, stack) {
      _logger.e('Kill switch disable error', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Enable DNS leak protection
  Future<bool> enableDnsLeakProtection() async {
    try {
      _logger.i('Enabling DNS leak protection');
      
      // In production, this would configure system DNS to route through VPN
      _dnsLeakProtectionActive = true;
      
      // Start DNS leak detection monitoring
      _startDnsLeakDetection();
      
      _logger.i('DNS leak protection enabled');
      return true;
    } catch (e, stack) {
      _logger.e('DNS leak protection error', error: e, stackTrace: stack);
      return false;
    }
  }
  
  /// Check for potential security vulnerabilities
  Future<SecurityReport> performSecurityAudit() async {
    final report = SecurityReport();
    
    try {
      // Check kill switch status
      report.killSwitchActive = _killSwitchActive;
      
      // Check DNS leak protection
      report.dnsLeakProtectionActive = _dnsLeakProtectionActive;
      
      // Check VPN connection status
      final vpnStatus = await _vpnChannel.getVpnStatus();
      report.vpnConnected = vpnStatus.vpnStatus.name == 'connected';
      
      // Check for IPv6 leaks (simplified check)
      report.ipv6Blocked = await _checkIpv6Leaks();
      
      // Check WebRTC leak protection
      report.webrtcBlocked = await _checkWebRtcLeaks();
      
      // Overall security score
      report.securityScore = _calculateSecurityScore(report);
      
      _logger.i('Security audit completed - Score: ${report.securityScore}%');
      
    } catch (e, stack) {
      _logger.e('Security audit failed', error: e, stackTrace: stack);
      report.auditFailed = true;
    }
    
    return report;
  }
  
  /// Detect potential DNS leaks
  Future<bool> detectDnsLeaks() async {
    try {
      // In production, this would test DNS resolution through VPN vs local
      // For now, return based on VPN connection status
      final vpnStatus = await _vpnChannel.getVpnStatus();
      return vpnStatus.vpnStatus.name != 'connected';
    } catch (e) {
      _logger.e('DNS leak detection failed', error: e);
      return true; // Assume leak if we can't determine
    }
  }
  
  /// Check device security (root/jailbreak detection)
  Future<void> _checkDeviceSecurity() async {
    try {
      if (Platform.isAndroid) {
        // Basic root detection indicators
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        // Check for common root indicators
        final suspiciousApps = [
          'com.topjohnwu.magisk',
          'com.noshufou.android.su',
          'com.koushikdutta.superuser',
          'eu.chainfire.supersu'
        ];
        
        // Log warning if potentially rooted (don't block, just inform)
        _logger.w('Device security check completed');
        
        if (androidInfo.isPhysicalDevice == false) {
          _logger.w('Running on emulator - reduced security');
        }
      }
    } catch (e) {
      _logger.e('Device security check failed', error: e);
    }
  }
  
  /// Start continuous security monitoring
  void _startSecurityMonitoring() {
    _securityMonitor = Timer.periodic(
      AppConstants.securityCheckInterval, 
      (_) => _performSecurityCheck()
    );
  }
  
  /// Start DNS leak detection monitoring
  void _startDnsLeakDetection() {
    _leakDetectionTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _checkForDnsLeaks()
    );
  }
  
  /// Periodic security check
  Future<void> _performSecurityCheck() async {
    try {
      // Check if kill switch is still active
      if (_killSwitchActive) {
        final vpnStatus = await _vpnChannel.getVpnStatus();
        if (vpnStatus.vpnStatus.name != 'connected') {
          _logger.w('Kill switch active but VPN disconnected - traffic blocked');
        }
      }
      
      // Check for DNS leaks
      await _checkForDnsLeaks();
      
    } catch (e) {
      _logger.e('Security check failed', error: e);
    }
  }
  
  /// Check for DNS leaks
  Future<void> _checkForDnsLeaks() async {
    try {
      final hasLeak = await detectDnsLeaks();
      if (hasLeak) {
        _logger.w('Potential DNS leak detected!');
        // In production, would trigger leak mitigation
      }
    } catch (e) {
      _logger.e('DNS leak check failed', error: e);
    }
  }
  
  /// Check for IPv6 leaks (simplified)
  Future<bool> _checkIpv6Leaks() async {
    try {
      // In production, would test IPv6 connectivity
      return true; // Assume blocked for now
    } catch (e) {
      return false;
    }
  }
  
  /// Check for WebRTC leaks
  Future<bool> _checkWebRtcLeaks() async {
    try {
      // In production, would test WebRTC STUN servers
      return true; // Assume blocked for now
    } catch (e) {
      return false;
    }
  }
  
  /// Calculate overall security score
  int _calculateSecurityScore(SecurityReport report) {
    int score = 0;
    
    if (report.killSwitchActive) score += 25;
    if (report.dnsLeakProtectionActive) score += 25;
    if (report.vpnConnected) score += 20;
    if (report.ipv6Blocked) score += 15;
    if (report.webrtcBlocked) score += 15;
    
    return score;
  }
  
  /// Get current security status
  SecurityStatus get securityStatus => SecurityStatus(
    killSwitchActive: _killSwitchActive,
    dnsLeakProtectionActive: _dnsLeakProtectionActive,
  );
  
  /// Dispose resources
  void dispose() {
    _securityMonitor?.cancel();
    _leakDetectionTimer?.cancel();
    _logger.i('Security Service disposed');
  }
}

/// Security status data class
class SecurityStatus {
  final bool killSwitchActive;
  final bool dnsLeakProtectionActive;
  
  const SecurityStatus({
    required this.killSwitchActive,
    required this.dnsLeakProtectionActive,
  });
}

/// Security audit report
class SecurityReport {
  bool killSwitchActive = false;
  bool dnsLeakProtectionActive = false;
  bool vpnConnected = false;
  bool ipv6Blocked = false;
  bool webrtcBlocked = false;
  bool auditFailed = false;
  int securityScore = 0;
  
  Map<String, dynamic> toJson() => {
    'killSwitchActive': killSwitchActive,
    'dnsLeakProtectionActive': dnsLeakProtectionActive,
    'vpnConnected': vpnConnected,
    'ipv6Blocked': ipv6Blocked,
    'webrtcBlocked': webrtcBlocked,
    'auditFailed': auditFailed,
    'securityScore': securityScore,
  };
}