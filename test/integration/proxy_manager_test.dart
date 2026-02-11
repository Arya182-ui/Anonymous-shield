import 'package:flutter_test/flutter_test.dart';
import 'package:privacy_vpn_controller/business_logic/managers/proxy_manager.dart';
import 'package:privacy_vpn_controller/data/models/proxy_config.dart';
import 'package:privacy_vpn_controller/data/models/connection_status.dart';

void main() {
  group('Proxy Manager Integration Tests', () {
    late ProxyManager proxyManager;
    
    setUp(() {
      proxyManager = ProxyManager();
    });
    
    testWidgets('Proxy Manager initializes successfully', (WidgetTester tester) async {
      // Test initialization
      try {
        await proxyManager.initialize();
        expect(true, true); // If we get here, initialization succeeded
      } catch (e) {
        fail('Proxy Manager initialization failed: $e');
      }
    });
    
    testWidgets('Can create SOCKS5 proxy configuration', (WidgetTester tester) async {
      // Create test SOCKS5 proxy config
      final testProxy = ProxyConfig.socks5(
        name: 'Test SOCKS5 Proxy',
        host: '192.168.1.100',
        port: 1080,
        username: 'testuser',
        password: 'testpass',
      );
      
      expect(testProxy.name, 'Test SOCKS5 Proxy');
      expect(testProxy.type, ProxyType.socks5);
      expect(testProxy.host, '192.168.1.100');
      expect(testProxy.port, 1080);
      expect(testProxy.username, 'testuser');
      expect(testProxy.password, 'testpass');
    });
    
    testWidgets('Can create proxy chain configuration', (WidgetTester tester) async {
      // Create a test proxy chain
      final entryProxy = ProxyConfig(
        id: 'entry_001',
        name: 'Entry Proxy',
        type: ProxyType.socks5,
        role: ProxyRole.entry,
        host: 'entry.proxy.com',
        port: 1080,
        createdAt: DateTime.now(),
      );
      
      final exitProxy = ProxyConfig(
        id: 'exit_001',
        name: 'Exit Proxy',
        type: ProxyType.socks5,
        role: ProxyRole.exit,
        host: 'exit.proxy.com',
        port: 1080,
        createdAt: DateTime.now(),
      );
      
      final proxyChain = [entryProxy, exitProxy];
      
      expect(proxyChain.length, 2);
      expect(proxyChain.first.role, ProxyRole.entry);
      expect(proxyChain.last.role, ProxyRole.exit);
    });
    
    testWidgets('Proxy status stream is accessible', (WidgetTester tester) async {
      await proxyManager.initialize();
      
      // Test that status stream is available
      expect(proxyManager.statusStream, isNotNull);
      
      // Test that we can listen to status changes
      bool streamWorking = false;
      
      final subscription = proxyManager.statusStream.listen((status) {
        streamWorking = true;
        expect(status, isA<ProxyStatus>());
      });
      
      subscription.cancel();
      expect(streamWorking, false); // No status updates yet, this is expected
    });
    
    testWidgets('Proxy connection handles errors gracefully', (WidgetTester tester) async {
      await proxyManager.initialize();
      
      // Create invalid proxy to test error handling
      final invalidProxy = ProxyConfig(
        id: 'invalid_proxy',
        name: 'Invalid Proxy',
        type: ProxyType.socks5,
        host: 'invalid.proxy.address',
        port: 99999, // Invalid port
        createdAt: DateTime.now(),
      );
      
      // This should fail gracefully and return false
      final result = await proxyManager.startProxy(invalidProxy);
      expect(result, false); // Connection should fail
    });
    
    testWidgets('Proxy URL generation works correctly', (WidgetTester tester) async {
      final socks5Proxy = ProxyConfig.socks5(
        name: 'Test SOCKS5',
        host: 'proxy.example.com',
        port: 1080,
        username: 'user',
        password: 'pass',
      );
      
      final proxyUrl = socks5Proxy.getProxyUrl();
      expect(proxyUrl, 'socks5://user:pass@proxy.example.com:1080');
    });
  });
}