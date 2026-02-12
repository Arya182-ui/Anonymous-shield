import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

// Core imports
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';

// Data layer imports
import 'data/storage/secure_storage.dart';

// Platform imports
import 'platform/channels/vpn_channel.dart';
import 'platform/channels/proxy_channel.dart';

// Business logic imports
import 'business_logic/managers/vpn_manager.dart';
import 'business_logic/managers/proxy_manager.dart';
import 'business_logic/managers/auto_vpn_config_manager.dart'; // NEW

// Presentation imports
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: AppConstants.debugMode ? Level.debug : Level.info,
  );
  
  try {
    logger.i('Initializing Privacy VPN Controller...');
    
    // Set preferred orientations (portrait for phones, both for tablets)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Initialize secure storage
    final secureStorage = SecureStorage();
    await secureStorage.initialize();
    logger.i('Secure storage initialized');
    
    // Initialize method channels
    final vpnChannel = VpnMethodChannel();
    await vpnChannel.initialize();
    logger.i('VPN method channel initialized');
    
    final proxyChannel = ProxyMethodChannel();
    await proxyChannel.initialize();
    logger.i('Proxy method channel initialized');
    
    // Initialize VPN manager
    final vpnManager = VpnManager();
    await vpnManager.initialize();
    logger.i('VPN manager initialized');
    
    // Initialize proxy manager
    final proxyManager = ProxyManager();
    await proxyManager.initialize();
    logger.i('Proxy manager initialized');
    
    // Initialize auto VPN configuration manager - NEW
    final autoVpnManager = AutoVpnConfigManager();
    await autoVpnManager.initialize();
    logger.i('Auto VPN configuration manager initialized');
    
    // Set system UI overlay style (dark status bar)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0D1117),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    logger.i('App initialization complete');
    
    runApp(
      ProviderScope(
        child: PrivacyVpnApp(),
      ),
    );
  } catch (e, stack) {
    logger.f('Failed to initialize app', error: e, stackTrace: stack);
    
    // Run minimal error app
    runApp(
      MaterialApp(
        title: 'Privacy VPN Controller - Error',
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrivacyVpnApp extends ConsumerWidget {
  const PrivacyVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      
      // Privacy-first: No analytics or crash reporting
      // No Firebase, no Crashlytics, no tracking
      
      home: const SplashScreen(),
      
      // Route configuration would go here for navigation
      // Using simple Navigator for now
      
      builder: (context, child) {
        // Error handling wrapper
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.darkTheme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: AppTheme.darkTheme.textTheme.headlineSmall,
                  ),
                  if (AppConstants.debugMode) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        errorDetails.exception.toString(),
                        textAlign: TextAlign.center,
                        style: AppTheme.darkTheme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        };
        
        return child!;
      },
    );
  }
}
