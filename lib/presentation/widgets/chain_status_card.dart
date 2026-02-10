import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_logic/providers/anonymous_providers.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/proxy_config.dart';

class ChainStatusCard extends ConsumerWidget {
  const ChainStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChain = ref.watch(activeAnonymousChainProvider);
    final features = ref.watch(anonymousFeaturesProvider);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(activeChain?.status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Status Header
          Row(
            children: [
              // Status Indicator
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getStatusColor(activeChain?.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _getStatusColor(activeChain?.status),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(activeChain?.status),
                  color: _getStatusColor(activeChain?.status),
                  size: 24,
                ),
              ),
              
              SizedBox(width: 16),
              
              // Status Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(activeChain),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getSubStatusText(activeChain),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Protection Level Indicator
              if (activeChain != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getProtectionColor(activeChain.mode).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${activeChain.hopCount} hops',
                    style: TextStyle(
                      color: _getProtectionColor(activeChain.mode),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          // Chain Details
          if (activeChain != null) ...[
            SizedBox(height: 16),
            _buildChainDetails(activeChain, features),
          ],
        ],
      ),
    );
  }

  Widget _buildChainDetails(AnonymousChain chain, AnonymousFeatures features) {
    return Column(
      children: [
        // Chain Mode and Route
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode: ${chain.mode.name.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (chain.isConnected && chain.uptime != null)
                    Text(
                      'Uptime: ${_formatDuration(chain.uptime!)}',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            
            // Active Features
            Wrap(
              spacing: 4,
              children: [
                if (features.trafficObfuscation)
                  _FeatureChip(
                    label: 'Obfuscated',
                    color: Colors.purple,
                    icon: Icons.shield,
                  ),
                if (features.dpiBypass)
                  _FeatureChip(
                    label: 'DPI Bypass',
                    color: Colors.green,
                    icon: Icons.security,
                  ),
                if (features.autoIpRotation)
                  _FeatureChip(
                    label: 'Auto-Rotate',
                    color: Colors.blue,
                    icon: Icons.refresh,
                  ),
              ],
            ),
          ],
        ),
        
        SizedBox(height: 12),
        
        // Proxy Chain Visualization
        if (chain.proxyChain.isNotEmpty)
          _buildChainVisualization(chain),
      ],
    );
  }

  Widget _buildChainVisualization(AnonymousChain chain) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.computer,
            color: Colors.white70,
            size: 16,
          ),
          
          ...chain.proxyChain.asMap().entries.map((entry) {
            final index = entry.key;
            final proxy = entry.value;
            
            return Expanded(
              child: Row(
                children: [
                  // Arrow
                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.white30,
                    ),
                  ),
                  
                  // Proxy Node
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getProxyRoleColor(proxy.role ?? ProxyRole.middle).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      proxy.flagEmoji ?? '🌐',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          
          Expanded(
            child: Container(
              height: 2,
              color: Colors.white30,
            ),
          ),
          
          Icon(
            Icons.language,
            color: Colors.green,
            size: 16,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ChainStatus? status) {
    switch (status) {
      case ChainStatus.connected:
        return Colors.green;
      case ChainStatus.connecting:
        return Colors.blue;
      case ChainStatus.rotating:
        return Colors.orange;
      case ChainStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ChainStatus? status) {
    switch (status) {
      case ChainStatus.connected:
        return Icons.verified_user;
      case ChainStatus.connecting:
        return Icons.sync;
      case ChainStatus.rotating:
        return Icons.refresh;
      case ChainStatus.error:
        return Icons.error;
      default:
        return Icons.security;
    }
  }

  String _getStatusText(AnonymousChain? chain) {
    if (chain == null) return 'Inactive';
    
    switch (chain.status) {
      case ChainStatus.connected:
        return 'Anonymous';
      case ChainStatus.connecting:
        return 'Connecting...';
      case ChainStatus.rotating:
        return 'Rotating Chain...';
      case ChainStatus.error:
        return 'Connection Error';
      default:
        return 'Inactive';
    }
  }

  String _getSubStatusText(AnonymousChain? chain) {
    if (chain == null) return 'Select an anonymous mode to connect';
    
    switch (chain.status) {
      case ChainStatus.connected:
        return 'Your identity is fully protected';
      case ChainStatus.connecting:
        return 'Establishing ${chain.hopCount}-hop anonymous tunnel...';
      case ChainStatus.rotating:
        return 'Changing exit node for enhanced anonymity';
      case ChainStatus.error:
        return 'Failed to establish anonymous connection';
      default:
        return 'Anonymous protection is inactive';
    }
  }

  Color _getProtectionColor(AnonymousMode mode) {
    switch (mode) {
      case AnonymousMode.ghost:
        return Colors.purple;
      case AnonymousMode.stealth:
        return Colors.green;
      case AnonymousMode.turbo:
        return Colors.blue;
      case AnonymousMode.tor:
        return Colors.deepOrange;
      case AnonymousMode.paranoid:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getProxyRoleColor(ProxyRole role) {
    switch (role) {
      case ProxyRole.entry:
        return Colors.blue;
      case ProxyRole.middle:
        return Colors.orange;
      case ProxyRole.exit:
        return Colors.green;
      case ProxyRole.bridge:
        return Colors.purple;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _FeatureChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 8,
          ),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}