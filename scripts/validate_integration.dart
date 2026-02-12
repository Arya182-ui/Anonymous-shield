#!/usr/bin/env dart

import 'dart:io';

/// Enhanced VPN Integration Validation Script
/// Validates that all enhanced VPN components are properly integrated
void main(List<String> args) async {
  print('🚀 Enhanced VPN Integration Validation Script');
  print('=' * 50);
  
  final validator = IntegrationValidator();
  
  try {
    await validator.validateAll();
    print('\n✅ All validations passed! Enhanced VPN integration is complete.');
  } catch (e) {
    print('\n❌ Validation failed: $e');
    exit(1);
  }
}

class IntegrationValidator {
  static const String basePath = 'd:/Anynomous';
  
  /// Validate all enhanced VPN integration components
  Future<void> validateAll() async {
    print('\n📋 Starting comprehensive validation...\n');
    
    await _validateProjectStructure();
    await _validateNativeServices();
    await _validateMethodChannels();
    await _validateEnhancedManagers();
    await _validateSecurityServices();
    await _validateUIIntegration();
    await _validateTestSuite();
    
    print('\n🎉 All components validated successfully!');
  }
  
  /// Validate project structure and required files
  Future<void> _validateProjectStructure() async {
    print('🔍 Validating project structure...');
    
    final requiredFiles = [
      // Native Android services
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/vpn/VpnControllerService.kt',
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/anonymity/GhostModeManager.kt',
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/anonymity/TrafficObfuscator.kt',
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/anonymity/ProxyChainManager.kt',
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/security/KillSwitchManager.kt',
      'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services/security/DnsLeakShield.kt',
      
      // Flutter method channels
      'lib/platform/channels/vpn_method_channel.dart',
      'lib/platform/channels/anonymous_method_channel.dart',
      
      // Enhanced managers
      'lib/business_logic/managers/enhanced_vpn_manager.dart',
      'lib/business_logic/services/security_manager.dart',
      
      // Enhanced UI
      'lib/presentation/screens/enhanced_control_screen.dart',
      'lib/presentation/screens/enhanced_status_screen.dart',
      
      // Tests
      'test/enhanced_vpn_test.dart',
    ];
    
    for (final file in requiredFiles) {
      await _checkFileExists(file);
    }
    
    print('✅ Project structure validation passed');
  }
  
  /// Validate native Android services
  Future<void> _validateNativeServices() async {
    print('🔍 Validating native Android services...');
    
    final services = {
      'VpnControllerService.kt': [
        'class VpnControllerService',
        'startVpn',
        'stopVpn',
        'startAnonymousChain',
        'GhostModeManager',
        'KillSwitchManager',
      ],
      'GhostModeManager.kt': [
        'class GhostModeManager',
        'startGhostMode',
        'startStealthMode',
        'startParanoidMode',
        'generateGhostChain',
      ],
      'KillSwitchManager.kt': [
        'class KillSwitchManager',
        'enableKillSwitch',
        'disableKillSwitch',
        'shouldAllowConnection',
      ],
      'DnsLeakShield.kt': [
        'class DnsLeakShield',
        'enableDnsProtection',
        'performDnsLeakTest',
      ],
    };
    
    for (final entry in services.entries) {
      await _validateFileContains(
        'android/app/src/main/kotlin/com/anynomous/privacy_vpn_controller/services',
        entry.key,
        entry.value,
      );
    }
    
    print('✅ Native Android services validation passed');
  }
  
  /// Validate Flutter method channels
  Future<void> _validateMethodChannels() async {
    print('🔍 Validating Flutter method channels...');
    
    final channels = {
      'vpn_method_channel.dart': [
        'class VpnMethodChannel',
        'startVpn',
        'stopVpn',
        'getVpnStatus',
        'getConnectionInfo',
        'enableKillSwitch',
      ],
      'anonymous_method_channel.dart': [
        'class AnonymousMethodChannel', 
        'startAnonymousChain',
        'startGhostMode',
        'rotateChain',
      ],
    };
    
    for (final entry in channels.entries) {
      await _validateFileContains(
        'lib/platform/channels',
        entry.key,
        entry.value,
      );
    }
    
    print('✅ Flutter method channels validation passed');
  }
  
  /// Validate enhanced managers
  Future<void> _validateEnhancedManagers() async {
    print('🔍 Validating enhanced managers...');
    
    final managers = {
      'enhanced_vpn_manager.dart': [
        'class EnhancedVpnManager',
        'connectVpn',
        'connectStealthMode',
        'connectGhostMode',
        'statusStream',
        'connectionInfoStream',
      ],
      'security_manager.dart': [
        'class SecurityManager',
        'enableKillSwitch',
        'runSecurityTest',
        'alertStream',
      ],
    };
    
    for (final entry in managers.entries) {
      if (entry.key == 'enhanced_vpn_manager.dart') {
        await _validateFileContains(
          'lib/business_logic/managers',
          entry.key,
          entry.value,
        );
      } else {
        await _validateFileContains(
          'lib/business_logic/services',
          entry.key,
          entry.value,
        );
      }
    }
    
    print('✅ Enhanced managers validation passed');
  }
  
  /// Validate security services
  Future<void> _validateSecurityServices() async {
    print('🔍 Validating security services...');
    
    final securityFeatures = [
      'SecurityAlert',
      'SecurityTestResult',
      'SecurityStatus',
      'enableKillSwitch',
      'enableDnsLeakProtection',
      'runSecurityTest',
    ];
    
    await _validateFileContains(
      'lib/business_logic/services',
      'security_manager.dart',
      securityFeatures,
    );
    
    print('✅ Security services validation passed');
  }
  
  /// Validate UI integration
  Future<void> _validateUIIntegration() async {
    print('🔍 Validating UI integration...');
    
    final uiComponents = {
      'enhanced_control_screen.dart': [
        'EnhancedVpnManager',
        'SecurityManager',
        '_handleConnectionToggle',
        '_showSecuritySettings',
      ],
      'enhanced_status_screen.dart': [
        'EnhancedVpnManager',
        'SecurityManager',
        '_buildSecurityTestResults',
        '_buildNativeVpnStatusCard',
      ],
    };
    
    for (final entry in uiComponents.entries) {
      await _validateFileContains(
        'lib/presentation/screens',
        entry.key,
        entry.value,
      );
    }
    
    print('✅ UI integration validation passed');
  }
  
  /// Validate test suite
  Future<void> _validateTestSuite() async {
    print('🔍 Validating test suite...');
    
    final testComponents = [
      'Enhanced VPN Manager Tests',
      'Security Manager Tests',
      'VPN Method Channel Tests',
      'Integration Tests',
      'Error Handling Tests',
    ];
    
    await _validateFileContains(
      'test',
      'enhanced_vpn_test.dart',
      testComponents,
    );
    
    print('✅ Test suite validation passed');
  }
  
  /// Check if a file exists
  Future<void> _checkFileExists(String relativePath) async {
    final file = File('$basePath/$relativePath');
    if (!await file.exists()) {
      throw Exception('Required file not found: $relativePath');
    }
    print('  ✓ $relativePath');
  }
  
  /// Validate that a file contains required content
  Future<void> _validateFileContains(String directory, String filename, List<String> requiredContent) async {
    final file = File('$basePath/$directory/$filename');
    
    if (!await file.exists()) {
      throw Exception('File not found: $directory/$filename');
    }
    
    final content = await file.readAsString();
    
    for (final required in requiredContent) {
      if (!content.contains(required)) {
        throw Exception('File $directory/$filename missing required content: $required');
      }
    }
    
    print('  ✓ $directory/$filename (${requiredContent.length} components)');
  }
}

/// Additional validation utilities
class ValidationUtils {
  /// Check if pubspec.yaml has required dependencies
  static Future<void> validateDependencies() async {
    final pubspec = File('$IntegrationValidator.basePath/pubspec.yaml');
    
    if (!await pubspec.exists()) {
      throw Exception('pubspec.yaml not found');
    }
    
    final content = await pubspec.readAsString();
    final requiredDeps = [
      'flutter_riverpod',
      'logger',
      'connectivity_plus',
    ];
    
    for (final dep in requiredDeps) {
      if (!content.contains(dep)) {
        print('⚠️  Warning: Missing dependency: $dep');
      }
    }
  }
  
  /// Check Android manifest permissions
  static Future<void> validateAndroidPermissions() async {
    final manifest = File('${IntegrationValidator.basePath}/android/app/src/main/AndroidManifest.xml');
    
    if (!await manifest.exists()) {
      print('⚠️  Warning: AndroidManifest.xml not found');
      return;
    }
    
    final content = await manifest.readAsString();
    final requiredPermissions = [
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.net.VpnService',
    ];
    
    for (final perm in requiredPermissions) {
      if (!content.contains(perm)) {
        print('⚠️  Warning: Missing permission: $perm');
      }
    }
  }
}

/// Validation report generator
class ValidationReport {
  static final List<String> _results = [];
  
  static void addResult(String component, bool passed, [String? details]) {
    final status = passed ? '✅' : '❌';
    final result = '$status $component${details != null ? ' - $details' : ''}';
    _results.add(result);
    print(result);
  }
  
  static void generateReport() {
    print('\n📊 VALIDATION REPORT');
    print('=' * 30);
    
    final passed = _results.where((r) => r.startsWith('✅')).length;
    final failed = _results.where((r) => r.startsWith('❌')).length;
    
    print('Total Components: ${_results.length}');
    print('Passed: $passed');
    print('Failed: $failed');
    print('Success Rate: ${((passed / _results.length) * 100).toStringAsFixed(1)}%');
    
    print('\nDetailed Results:');
    _results.forEach(print);
  }
}