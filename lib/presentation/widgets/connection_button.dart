import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_theme.dart';

class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  const ConnectionButton({
    Key? key,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getGradient(theme, customColors),
          boxShadow: [
            BoxShadow(
              color: _getShadowColor(customColors).withOpacity(0.3),
              blurRadius: isConnected || isConnecting ? 30 : 20,
              spreadRadius: isConnected || isConnecting ? 4 : 1,
            ),
            if (isConnected)
              BoxShadow(
                color: customColors.vpnConnected.withOpacity(0.2),
                blurRadius: 50,
                spreadRadius: 8,
              ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                   AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: isConnecting
                      ? SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          isConnected ? Icons.power_settings_new : Icons.power_settings_new,
                          key: ValueKey(isConnected),
                          size: 64,
                          color: Colors.white.withOpacity(isConnected ? 1.0 : 0.6),
                        ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _getButtonText(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (!isConnecting)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        _getSubText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Gradient _getGradient(ThemeData theme, AppCustomColors customColors) {
    if (isConnected) {
      return RadialGradient(
        colors: [
          customColors.vpnConnected,
          Color(0xFF00C853),
        ],
        center: Alignment(-0.3, -0.3),
        radius: 1.5,
      );
    } else if (isConnecting) {
      return RadialGradient(
        colors: [
          customColors.vpnConnecting,
          Color(0xFFE65100), 
        ],
        center: Alignment(-0.3, -0.3),
        radius: 1.5,
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.surfaceContainerHighest,
          Color(0xFF1E1E2C),
        ],
      );
    }
  }

  Color _getShadowColor(AppCustomColors customColors) {
    if (isConnected) {
      return customColors.vpnConnected;
    } else if (isConnecting) {
      return customColors.vpnConnecting;
    } else {
      return Colors.black;
    }
  }

  String _getButtonText() {
    if (isConnecting) {
      return 'CONNECTING';
    } else if (isConnected) {
      return 'STOP';
    } else {
      return 'START';
    }
  }

  String _getSubText() {
    if (isConnected) {
      return 'SECURE';
    } else {
      return 'TAP TO SECURE';
    }
  }
}