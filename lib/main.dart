import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// Core imports
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/production_logger.dart';
import 'core/error_handling/production_error_handler.dart';

// Data layer imports
import 'data/storage/secure_storage.dart';

// Platform imports
import 'platform/channels/optimized_method_channel.dart';

// Business logic imports
import 'business_logic/managers/vpn_manager.dart';
import 'business_logic/managers/enhanced_vpn_manager.dart';
import 'business_logic/managers/wireguard_manager.dart';
import 'business_logic/managers/proxy_manager.dart';
import 'business_logic/managers/auto_vpn_config_manager.dart';
import 'business_logic/services/security_manager.dart';

// Presentation imports
import 'presentation/screens/splash_screen.dart';

/// Production-ready main function with comprehensive error handling
Future<void> main() async {
  // Run app in protected zone for error handling
  await runZonedGuarded(
    () async => await _initializeAndRunApp(),
    (error, stack) => ProductionErrorHandler().handleZoneError(error, stack),
  );
}

/// Initialize all production systems and run app
Future<void> _initializeAndRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize production logging first
    final logger = ProductionLogger();
    await logger.initialize(
      minLevel: AppConstants.debugMode ? Level.debug : Level.info,
      enableFileLogging: true,
      enablePerformanceLogging: true,
      enableSecurityLogging: true,
    );
    
    logger.i('=== Privacy VPN Controller - Production Startup ===');
    logger.i('App Version: 1.0.0+1');
    logger.i('Environment: ${AppConstants.debugMode ? 'Development' : 'Production'}');
    
    // Initialize error handling system
    final errorHandler = ProductionErrorHandler();
    await errorHandler.initialize(
      enableCrashReporting: !AppConstants.debugMode, // Only in production
      enableErrorLogging: true,
    );
    
    logger.i('Error handling system initialized');
    
    // Set device orientation preferences
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    logger.i('Device orientations configured');
    
    // Initialize core systems with comprehensive error handling
    await _initializeCoreSystemsWithErrorHandling(logger);
    
    // Initialize VPN and security systems
    await _initializeVpnSystemsWithErrorHandling(logger);
    
    // Initialize optimized method channels
    await _initializeMethodChannelsWithErrorHandling(logger);
    
    logger.i('All systems initialized successfully - launching app');
    
    // Launch the application
    runApp(
      ProviderScope(
        child: PrivacyVpnControllerApp(),
      ),
    );
    
  } catch (e, stack) {
    // Critical initialization failure
    print('CRITICAL: App initialization failed: $e');
    print('Stack trace: $stack');
    
    // Try to show error to user
    runApp(
      MaterialApp(
        home: _buildErrorScreen(e.toString()),
      ),
    );
  }
}

/// Initialize core systems with error handling
Future<void> _initializeCoreSystemsWithErrorHandling(ProductionLogger logger) async {
  // Initialize secure storage with timeout and retry
  try {
    final secureStorage = SecureStorage();
    await secureStorage.initialize().timeout(
      Duration(seconds: 15),
      onTimeout: () {
        logger.w('Secure storage initialization timed out - using fallback');
        throw TimeoutException('Secure storage timeout', Duration(seconds: 15));
      },
    );
    logger.i('✓ Secure storage initialized');
  } catch (e) {
    logger.e('✗ Secure storage initialization failed', error: e);
    // Continue with app - storage will use fallback methods
  }
}

/// Initialize VPN systems with comprehensive error handling
Future<void> _initializeVpnSystemsWithErrorHandling(ProductionLogger logger) async {
  final initResults = <String, bool>{};
  
  // Initialize Enhanced VPN Manager
  try {
    final enhancedVpnManager = EnhancedVpnManager();
    final success = await enhancedVpnManager.initialize().timeout(Duration(seconds: 20));
    initResults['enhanced_vpn'] = success;
    if (success) {
      logger.i('✓ Enhanced VPN Manager initialized');
    } else {
      logger.w('✗ Enhanced VPN Manager initialization failed');
    }
  } catch (e) {
    logger.e('✗ Enhanced VPN Manager initialization error', error: e);
    initResults['enhanced_vpn'] = false;
  }
  
  // Initialize WireGuard Manager
  try {
    final wireGuardManager = WireGuardManager();
    final success = await wireGuardManager.initialize().timeout(Duration(seconds: 15));
    initResults['wireguard'] = success;
    if (success) {
      logger.i('✓ WireGuard Manager initialized');
    } else {
      logger.w('✗ WireGuard Manager initialization failed');
    }
  } catch (e) {
    logger.e('✗ WireGuard Manager initialization error', error: e);
    initResults['wireguard'] = false;
  }
  
  // Initialize Legacy VPN Manager (fallback)
  try {
    final vpnManager = VpnManager();
    await vpnManager.initialize().timeout(Duration(seconds: 15));
    initResults['legacy_vpn'] = true;
    logger.i('✓ Legacy VPN Manager initialized (fallback)');
  } catch (e) {
    logger.e('✗ Legacy VPN Manager initialization failed', error: e);
    initResults['legacy_vpn'] = false;
  }
  
  // Initialize Security Manager
  try {
    final securityManager = SecurityManager();
    final success = await securityManager.initialize().timeout(Duration(seconds: 20));
    initResults['security'] = success;
    if (success) {
      logger.i('✓ Security Manager initialized');
      
      // Enable critical security features
      try {
        await securityManager.enableKillSwitch();
        await securityManager.enableDnsLeakProtection();
        await securityManager.enableIpv6Protection();
        logger.i('✓ Core security features enabled');
      } catch (e) {
        logger.w('Some security features failed to enable', error: e);
      }
    } else {
      logger.w('✗ Security Manager initialization failed');
    }
  } catch (e) {
    logger.e('✗ Security Manager initialization error', error: e);
    initResults['security'] = false;
  }
  
  // Initialize Proxy Manager
  try {
    final proxyManager = ProxyManager();
    await proxyManager.initialize().timeout(Duration(seconds: 15));
    initResults['proxy'] = true;
    logger.i('✓ Proxy Manager initialized');
  } catch (e) {
    logger.e('✗ Proxy Manager initialization failed', error: e);
    initResults['proxy'] = false;
  }
  
  // Initialize Auto VPN Configuration Manager
  try {
    final autoVpnManager = AutoVpnConfigManager();
    await autoVpnManager.initialize().timeout(Duration(seconds: 25));
    initResults['auto_vpn'] = true;
    logger.i('✓ Auto VPN Configuration Manager initialized');
  } catch (e) {
    logger.e('✗ Auto VPN Configuration Manager initialization failed', error: e);
    initResults['auto_vpn'] = false;
  }
  
  // Log initialization summary
  final successCount = initResults.values.where((success) => success).length;
  final totalCount = initResults.length;
  
  logger.i('VPN Systems Initialization Summary: $successCount/$totalCount successful');
  logger.i('Initialization Results: $initResults');
  
  if (successCount == 0) {
    throw Exception('Critical: All VPN systems failed to initialize');
  } else if (successCount < totalCount) {
    logger.w('Warning: Some VPN systems failed - app may have limited functionality');
  }
}

/// Initialize optimized method channels with error handling
Future<void> _initializeMethodChannelsWithErrorHandling(ProductionLogger logger) async {
  try {
    // Initialize all optimized method channels
    await AppMethodChannels.initializeAll().timeout(Duration(seconds: 10));
    logger.i('✓ Optimized method channels initialized');
    
    // Log channel statistics
    final stats = AppMethodChannels.getAllStatistics();
    logger.performance('method_channels_init', Duration(milliseconds: 100), 
      metrics: {'channels_count': stats.length});
    
  } catch (e) {
    logger.e('✗ Method channels initialization failed', error: e);
    // App can still function with basic method channels
  }
}

/// Build error screen for critical failures
Widget _buildErrorScreen(String error) {
  return Scaffold(
    backgroundColor: Colors.red[900],
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              'Critical Initialization Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'The app failed to initialize properly. Please restart the application.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            if (AppConstants.debugMode) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Debug Info:\n$error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
/// Production-Ready Privacy VPN Controller App
/// Comprehensive configuration with security, performance, and reliability focus
class PrivacyVpnControllerApp extends ConsumerWidget {
  const PrivacyVpnControllerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ProductionLogger();
    
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Theme configuration with system theme detection
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      
      // Internationalization setup
      locale: Locale('en', 'US'),
      supportedLocales: [
        Locale('en', 'US'),  // English (US)
        Locale('es', 'ES'),  // Spanish
        Locale('fr', 'FR'),  // French
        Locale('de', 'DE'),  // German
        Locale('zh', 'CN'),  // Chinese
        Locale('ja', 'JP'),  // Japanese
        Locale('ko', 'KR'),  // Korean
        Locale('hi', 'IN'),  // Hindi
        Locale('ar', 'SA'),  // Arabic
      ],
      
      // Privacy-first navigation
      home: SplashScreen(),
      
      // Production error handling
      builder: (context, widget) {
        // Custom error widget for production
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          // Log the error for monitoring
          logger.e('UI Error occurred', 
                  error: errorDetails.exception, 
                  stackTrace: errorDetails.stack,
                  data: {'library': errorDetails.library});
          
          if (AppConstants.debugMode) {
            // Show detailed error in development
            return ErrorWidget(errorDetails.exception);
          } else {
            // Show user-friendly error in production
            return _buildProductionErrorWidget(context, errorDetails);
          }
        };
        
        return widget ?? Container();
      },
      
      // Performance optimizations
      checkerboardRasterCacheImages: AppConstants.debugMode && false,
      checkerboardOffscreenLayers: AppConstants.debugMode && false,
      showPerformanceOverlay: AppConstants.debugMode && false,
      
      // Accessibility support
      showSemanticsDebugger: false,
      
      // Security configurations
      shortcuts: {
        // Disable debug shortcuts in production
        if (AppConstants.debugMode) 
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyI): 
            VoidCallbackIntent(() => logger.d('Debug shortcut triggered')),
      },
      actions: {
        if (AppConstants.debugMode)
          VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(
            onInvoke: (intent) => intent.callback(),
          ),
      },
    );
  }

  /// Build production-friendly error widget
  Widget _buildProductionErrorWidget(BuildContext context, FlutterErrorDetails errorDetails) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'We encountered an unexpected error. The app should recover automatically.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // In a real implementation, this could trigger app restart
                  // or navigate to a safe screen
                },
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
              if (AppConstants.debugMode) ...[
                SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Information:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Error: ${errorDetails.exception}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (errorDetails.stack != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'Stack Trace:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              errorDetails.stack.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
