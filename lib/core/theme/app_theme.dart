import 'package:flutter/material.dart';

class AppTheme {
  // Privacy-focused color scheme - Dark theme with security-minded colors
  static const Color _primarySeedColor = Color(0xFF1B5E20); // Deep green for privacy
  static const Color _surfaceColor = Color(0xFF0D1117); // GitHub-dark surface
  static const Color _errorColor = Color(0xFFCF6679); // Soft red for errors
  static const Color _successColor = Color(0xFF4CAF50); // Green for success
  static const Color _warningColor = Color(0xFFFF9800); // Orange for warnings
  
  // Generate Material 3 color scheme
  static ColorScheme get _darkColorScheme {
    return ColorScheme.fromSeed(
      seedColor: _primarySeedColor,
      brightness: Brightness.dark,
      error: _errorColor,
      surface: _surfaceColor,
      onSurface: const Color(0xFFF0F6FF),
    );
  }
  
  // App custom colors extension
  static const AppCustomColors customColors = AppCustomColors(
    success: _successColor,
    onSuccess: Color(0xFF003300),
    warning: _warningColor, 
    onWarning: Color(0xFF332200),
    vpnConnected: Color(0xFF00E676),
    vpnDisconnected: Color(0xFF757575),
    vpnConnecting: Color(0xFFFFB74D),
    vpnError: _errorColor,
    proxyEnabled: Color(0xFF5C6BC0),
    killSwitchActive: Color(0xFFE53935),
  );
  
  static ThemeData get darkTheme {
    final colorScheme = _darkColorScheme;
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      
      // Typography
      textTheme: _buildTextTheme(colorScheme),
      
      // App Bar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 4,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      
      // Card
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return customColors.success;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return customColors.success.withOpacity(0.5);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
  
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
    );
  }
}

@immutable
class AppCustomColors {
  const AppCustomColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.vpnConnected,
    required this.vpnDisconnected,
    required this.vpnConnecting,
    required this.vpnError,
    required this.proxyEnabled,
    required this.killSwitchActive,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color vpnConnected;
  final Color vpnDisconnected;
  final Color vpnConnecting;
  final Color vpnError;
  final Color proxyEnabled;
  final Color killSwitchActive;
}

// Extension to access custom colors
extension CustomColorsExtension on ColorScheme {
  AppCustomColors get customColors => AppTheme.customColors;
}