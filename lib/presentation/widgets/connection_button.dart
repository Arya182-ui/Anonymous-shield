import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getGradient(),
          boxShadow: [
            BoxShadow(
              color: _getShadowColor().withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnecting)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  isConnected ? Icons.shield : Icons.shield_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              SizedBox(height: 6),
              Text(
                _getButtonText(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isConnecting)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    _getSubText(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Gradient _getGradient() {
    if (isConnected) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
      );
    } else if (isConnecting) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF424242), Color(0xFF616161)],
      );
    }
  }

  Color _getShadowColor() {
    if (isConnected) {
      return Color(0xFF4CAF50);
    } else if (isConnecting) {
      return Color(0xFF2196F3);
    } else {
      return Color(0xFF616161);
    }
  }

  String _getButtonText() {
    if (isConnecting) {
      return 'Connecting...';
    } else if (isConnected) {
      return 'DISCONNECT';
    } else {
      return 'CONNECT';
    }
  }

  String _getSubText() {
    if (isConnected) {
      return 'Protected';
    } else {
      return 'Tap to connect';
    }
  }
}