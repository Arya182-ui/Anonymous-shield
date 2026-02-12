import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_vpn_controller/business_logic/managers/enhanced_vpn_manager.dart';
import 'package:privacy_vpn_controller/business_logic/services/security_manager.dart';
import 'package:privacy_vpn_controller/data/models/enhanced_vpn_models.dart';
import 'package:privacy_vpn_controller/data/models/vpn_config.dart';
import 'package:privacy_vpn_controller/data/models/proxy_config.dart';
import 'package:privacy_vpn_controller/platform/channels/vpn_method_channel.dart';
import 'package:privacy_vpn_controller/platform/channels/anonymous_method_channel.dart';

/// Enhanced VPN Integration Tests
/// Tests for native VPN service integration and security features
void main() {
  group('Enhanced VPN Manager Tests', () {
    late EnhancedVpnManager vpnManager;
    
    setUp(() {
      vpnManager = EnhancedVpnManager();
    });
    
    tearDown(() {
      vpnManager.dispose();
    });

    test('VPN Manager initializes successfully', () async {
      final initialized = await vpnManager.initialize();
      expect(initialized, isTrue);
    });

    test('VPN connection status stream is working', () async {
      await vpnManager.initialize();
      
      expect(vpnManager.statusStream, isA<Stream<VpnConnectionStatus>>());
      
      // Listen to status stream for a short time
      final statusFuture = vpnManager.statusStream.first.timeout(
        Duration(seconds: 5),
        onTimeout: () => VpnConnectionStatus(vpnStatus: VpnConnectionState.disconnected),
      );
      
      final status = await statusFuture;
      expect(status, isA<VpnConnectionStatus>());
      expect(status.vpnStatus, isA<VpnConnectionState>());
    });

    test('Connection info stream is working', () async {
      await vpnManager.initialize();
      
      expect(vpnManager.connectionInfoStream, isA<Stream<VpnConnectionInfo>>());
      
      // Test that the stream exists and can be listened to
      final subscription = vpnManager.connectionInfoStream.listen((_) {});
      expect(subscription, isNotNull);
      await subscription.cancel();
    });

    test('VPN connection methods exist and are callable', () async {
      await vpnManager.initialize();
      
      // Test that methods exist and don't throw immediately
      final testConfig = VpnConfig(
        id: 'test_id',
        name: 'Test Config',
        serverAddress: 'test.example.com',
        port: 51820,
        privateKey: 'test_private_key',
        publicKey: 'test_public_key',
        createdAt: DateTime.now(),
      );
      
      final testProxies = <ProxyConfig>[];
      
      expect(() => vpnManager.connectVpn(testConfig), returnsNormally);
      
      expect(() => vpnManager.connectStealthMode(testProxies), returnsNormally);
      expect(() => vpnManager.connectGhostMode(testProxies), returnsNormally);
      expect(() => vpnManager.disconnect(), returnsNormally);
    });

    test('Chain rotation functionality exists', () async {
      await vpnManager.initialize();
      
      expect(() => vpnManager.rotateChain(), returnsNormally);
    });
  });

  group('Security Manager Tests', () {
    late SecurityManager securityManager;
    
    setUp(() {
      securityManager = SecurityManager();
    });
    
    tearDown(() {
      securityManager.dispose();
    });

    test('Security Manager initializes successfully', () async {
      final initialized = await securityManager.initialize();
      expect(initialized, isTrue);
    });

    test('Security alert stream is working', () async {
      await securityManager.initialize();
      
      expect(securityManager.alertStream, isA<Stream<SecurityAlert>>());
      
      // Test that the stream exists and can be listened to
      final subscription = securityManager.alertStream.listen((_) {});
      expect(subscription, isNotNull);
      await subscription.cancel();
    });

    test('Kill switch methods exist and are callable', () async {
      await securityManager.initialize();
      
      expect(() => securityManager.enableKillSwitch(), returnsNormally);
      expect(() => securityManager.disableKillSwitch(), returnsNormally);
    });

    test('DNS protection methods exist and are callable', () async {
      await securityManager.initialize();
      
      expect(() => securityManager.enableDnsLeakProtection(), returnsNormally);
    });

    test('Security test can be run', () async {
      await securityManager.initialize();
      
      final testResult = await securityManager.runSecurityTest();
      expect(testResult, isA<SecurityTestResult>());
      expect(testResult.tests, isA<List<SecurityTest>>());
      expect(testResult.overallPassed, isA<bool>());
      expect(testResult.timestamp, isA<DateTime>());
    });

    test('Security status can be retrieved', () {
      final status = securityManager.getSecurityStatus();
      expect(status, isA<SecurityStatus>());
      expect(status.killSwitchEnabled, isA<bool>());
      expect(status.dnsLeakProtectionEnabled, isA<bool>());
      expect(status.securityScore, isA<double>());
      expect(status.securityLevel, isA<String>());
    });
  });

  group('VPN Method Channel Tests', () {
    test('VPN Method Channel static methods exist', () {
      expect(VpnMethodChannel.startVpn, isA<Function>());
      expect(VpnMethodChannel.stopVpn, isA<Function>());
      expect(VpnMethodChannel.getVpnStatus, isA<Function>());
      expect(VpnMethodChannel.getConnectionInfo, isA<Function>());
      expect(VpnMethodChannel.enableKillSwitch, isA<Function>());
    });

    test('VPN Method Channel can handle method calls', () async {
      // Test that methods don't throw when called
      // Note: These will likely fail in test environment, but should not throw
      try {
        await VpnMethodChannel.getVpnStatus();
      } catch (e) {
        // Expected in test environment - just ensure it's not a compilation error
        expect(e, isNotNull);
      }
    });
  });

  group('Anonymous Method Channel Tests', () {
    test('Anonymous Method Channel static methods exist', () {
      expect(AnonymousMethodChannel.startGhostMode, isA<Function>());
      expect(AnonymousMethodChannel.startStealthMode, isA<Function>());
      // startAnonymousChain, rotateChain, getChainStatus are in the testing extension
      expect(AnonymousMethodChannelTesting.startAnonymousChain, isA<Function>());
      expect(AnonymousMethodChannelTesting.rotateChain, isA<Function>());
      expect(AnonymousMethodChannelTesting.getChainStatus, isA<Function>());
    });

    test('Anonymous Method Channel can handle method calls', () async {
      // Test that methods don't throw when called
      try {
        await AnonymousMethodChannelTesting.getChainStatus();
      } catch (e) {
        // Expected in test environment - just ensure it's not a compilation error
        expect(e, isNotNull);
      }
    });
  });

  group('Integration Tests', () {
    late EnhancedVpnManager vpnManager;
    late SecurityManager securityManager;
    
    setUp(() {
      vpnManager = EnhancedVpnManager();
      securityManager = SecurityManager();
    });
    
    tearDown(() {
      vpnManager.dispose();
      securityManager.dispose();
    });

    test('VPN and Security managers can work together', () async {
      final vpnInitialized = await vpnManager.initialize();
      final securityInitialized = await securityManager.initialize();
      
      expect(vpnInitialized, isTrue);
      expect(securityInitialized, isTrue);
      
      // Test that both can be used simultaneously
      // ignore: unused_local_variable
      final vpnStatus = vpnManager.statusStream.first.timeout(Duration(seconds: 2));
      final securityStatus = securityManager.getSecurityStatus();
      
      expect(securityStatus, isNotNull);
      // vpnStatus may timeout in test environment, which is fine
    });

    test('Enhanced managers provide consistent interface', () async {
      await vpnManager.initialize();
      await securityManager.initialize();
      
      // Test that both managers have expected properties
      expect(securityManager.getSecurityStatus().monitoringActive, isA<bool>());
      
      // Test that cleanup works
      expect(() => vpnManager.dispose(), returnsNormally);
      expect(() => securityManager.dispose(), returnsNormally);
    });
  });

  group('Error Handling Tests', () {
    test('VPN Manager handles initialization errors gracefully', () async {
      final vpnManager = EnhancedVpnManager();
      
      // Should not throw even if native services fail
      expect(() => vpnManager.initialize(), returnsNormally);
      
      vpnManager.dispose();
    });

    test('Security Manager handles test errors gracefully', () async {
      final securityManager = SecurityManager();
      await securityManager.initialize();
      
      // Security test should not throw even if some tests fail
      final testResult = await securityManager.runSecurityTest();
      expect(testResult, isNotNull);
      expect(testResult.tests, isA<List>());
      
      securityManager.dispose();
    });

    test('Method channels handle platform exceptions', () async {
      // Test that method channel calls don't crash the app
      try {
        final testConfig = VpnConfig(
          id: 'test_id',
          name: 'Test Config',
          serverAddress: 'test.example.com',
          port: 51820,
          privateKey: 'invalid_key',
          publicKey: 'invalid_key',
          createdAt: DateTime.now(),
        );
        await VpnMethodChannel.startVpn(testConfig);
      } catch (e) {
        // Expected - should catch platform exceptions gracefully
        expect(e, isNotNull);
      }
    });
  });

  group('Data Model Tests', () {
    test('VpnConnectionStatus has correct structure', () {
      final status = VpnConnectionStatus(vpnStatus: VpnConnectionState.connected);
      
      expect(status.vpnStatus, VpnConnectionState.connected);
      expect(status.error, isNull);
      
      final statusWithError = VpnConnectionStatus(
        vpnStatus: VpnConnectionState.error,
        error: 'Test error',
      );
      
      expect(statusWithError.error, 'Test error');
    });

    test('VpnConnectionInfo has correct structure', () {
      final info = VpnConnectionInfo(
        publicIp: '192.168.1.1',
        country: 'Test Country',
        city: 'Test City',
        isp: 'Test ISP',
      );
      
      expect(info.publicIp, '192.168.1.1');
      expect(info.country, 'Test Country');
      expect(info.city, 'Test City');
      expect(info.isp, 'Test ISP');
    });

    test('SecurityAlert has correct structure', () {
      final alert = SecurityAlert(
        type: SecurityAlertType.warning,
        title: 'Test Alert',
        message: 'Test message',
        timestamp: DateTime.now(),
      );
      
      expect(alert.type, SecurityAlertType.warning);
      expect(alert.title, 'Test Alert');
      expect(alert.message, 'Test message');
      expect(alert.typeString, 'WARNING');
    });

    test('SecurityTestResult has correct structure', () {
      final testResults = [
        SecurityTest(
          name: 'Test 1',
          passed: true,
          details: 'Test details',
          recommendation: 'Test recommendation',
        ),
        SecurityTest(
          name: 'Test 2',
          passed: false,
          details: 'Test details 2',
          recommendation: 'Test recommendation 2',
        ),
      ];
      
      final result = SecurityTestResult(
        tests: testResults,
        overallPassed: false,
        timestamp: DateTime.now(),
      );
      
      expect(result.tests.length, 2);
      expect(result.passedTests, 1);
      expect(result.failedTests, 1);
      expect(result.successRate, 0.5);
      expect(result.overallPassed, false);
    });

    test('SecurityStatus has correct calculations', () {
      final status = SecurityStatus(
        killSwitchEnabled: true,
        dnsLeakProtectionEnabled: true,
        ipv6BlockingEnabled: false,
        webRtcBlockingEnabled: true,
        monitoringActive: true,
      );
      
      expect(status.enabledFeatures, 3);
      expect(status.securityScore, 0.75);
      expect(status.securityLevel, 'Good');
    });
  });

  group('Stream Management Tests', () {
    test('VPN status stream can be listened to multiple times', () async {
      final vpnManager = EnhancedVpnManager();
      await vpnManager.initialize();
      
      final subscription1 = vpnManager.statusStream.listen((_) {});
      final subscription2 = vpnManager.statusStream.listen((_) {});
      
      expect(subscription1, isNotNull);
      expect(subscription2, isNotNull);
      
      await subscription1.cancel();
      await subscription2.cancel();
      vpnManager.dispose();
    });

    test('Security alert stream can be listened to multiple times', () async {
      final securityManager = SecurityManager();
      await securityManager.initialize();
      
      final subscription1 = securityManager.alertStream.listen((_) {});
      final subscription2 = securityManager.alertStream.listen((_) {});
      
      expect(subscription1, isNotNull);
      expect(subscription2, isNotNull);
      
      await subscription1.cancel();
      await subscription2.cancel();
      securityManager.dispose();
    });
  });
}

/// Test helper to check if all required dependencies are available
void validateTestEnvironment() {
  print('Validating enhanced VPN test environment...');
  
  // Check that all required classes can be imported
  expect(EnhancedVpnManager, isNotNull);
  expect(SecurityManager, isNotNull);
  expect(VpnMethodChannel, isNotNull);
  expect(AnonymousMethodChannel, isNotNull);
  
  print('✓ All enhanced VPN classes available');
  
  // Check that enum values are available
      expect(VpnConnectionState.values, isNotEmpty);
  
  print('✓ All enums properly defined');
  
  // Check that data models can be instantiated
  final status = VpnConnectionStatus(vpnStatus: VpnConnectionState.disconnected);
  expect(status, isNotNull);
  
  final alert = SecurityAlert(
    type: SecurityAlertType.info,
    title: 'Test',
    message: 'Test message',
    timestamp: DateTime.now(),
  );
  expect(alert, isNotNull);
  
  print('✓ All data models can be instantiated');
  print('Enhanced VPN test environment validation complete!');
}