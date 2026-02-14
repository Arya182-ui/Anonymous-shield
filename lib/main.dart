import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'dart:async';

// Core imports
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/production_logger.dart';
import 'core/error_handling/production_error_handler.dart';
import 'core/services/app_initializer.dart';

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

/// Initialize minimal systems and launch UI immediately.
/// Heavy VPN/security initialization runs in the background while
/// the splash screen is already visible to the user.
Future<void> _initializeAndRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // ── Lightweight setup only (< 500ms) ──
    final logger = ProductionLogger();
    await logger.initialize(
      minLevel: Level.info,
      enableFileLogging: true,
      enablePerformanceLogging: true,
      enableSecurityLogging: true,
    );
    
    logger.i('=== Privacy VPN Controller - Fast Startup ===');
    logger.i('App Version: 1.0.0+1');
    logger.i('Environment: ${AppConstants.debugMode ? 'Development' : 'Production'}');
    
    // Initialize error handling (lightweight)
    final errorHandler = ProductionErrorHandler();
    await errorHandler.initialize(
      enableCrashReporting: !AppConstants.debugMode,
      enableErrorLogging: true,
    );
    
    // Set device orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    logger.i('Minimal setup done – launching UI immediately');
    
    // ── Kick off heavy init in background (runs while splash is visible) ──
    AppInitializer().startBackgroundInit();
    
    // ── Show UI NOW – splash screen will wait for background init ──
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
      
      // Theme configuration with dark theme (privacy-focused design)
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Always use dark theme for privacy focus
      
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
