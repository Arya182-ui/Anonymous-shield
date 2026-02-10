import 'package:flutter/material.dart';
import '../../data/models/anonymous_chain.dart';

class AnonymousModeSelector extends StatelessWidget {
  final Function(AnonymousMode) onModeSelected;
  final AnonymousMode? selectedMode;

  const AnonymousModeSelector({
    Key? key,
    required this.onModeSelected,
    this.selectedMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.white70,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Choose Your Anonymity Level',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Ghost Mode
          _AnonymousModeCard(
            mode: AnonymousMode.ghost,
            title: '🥷 Ghost Mode',
            subtitle: 'Maximum anonymity (5+ hops)',
            description: 'Undetectable browsing with military-grade protection',
            color: Colors.purple,
            isSelected: selectedMode == AnonymousMode.ghost,
            onTap: () => onModeSelected(AnonymousMode.ghost),
          ),
          
          SizedBox(height: 12),
          
          // Stealth Mode
          _AnonymousModeCard(
            mode: AnonymousMode.stealth,
            title: '🎭 Stealth Mode',
            subtitle: 'Bypass censorship (DPI evasion)',
            description: 'Defeat government firewalls and deep packet inspection',
            color: Colors.green,
            isSelected: selectedMode == AnonymousMode.stealth,
            onTap: () => onModeSelected(AnonymousMode.stealth),
          ),
          
          SizedBox(height: 12),
          
          // Turbo Mode
          _AnonymousModeCard(
            mode: AnonymousMode.turbo,
            title: '⚡ Turbo Mode',
            subtitle: 'Fast anonymity (optimized)',
            description: 'Balance between speed and privacy protection',
            color: Colors.blue,
            isSelected: selectedMode == AnonymousMode.turbo,
            onTap: () => onModeSelected(AnonymousMode.turbo),
          ),
        ],
      ),
    );
  }
}

class _AnonymousModeCard extends StatelessWidget {
  final AnonymousMode mode;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnonymousModeCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.8) : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getModeIcon(),
                color: color,
                size: 20,
              ),
            ),
            
            SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected ? color : Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getModeIcon() {
    switch (mode) {
      case AnonymousMode.ghost:
        return Icons.visibility_off;
      case AnonymousMode.stealth:
        return Icons.security;
      case AnonymousMode.turbo:
        return Icons.speed;
      case AnonymousMode.tor:
        return Icons.layers;
      case AnonymousMode.paranoid:
        return Icons.shield;
      default:
        return Icons.vpn_key;
    }
  }
}