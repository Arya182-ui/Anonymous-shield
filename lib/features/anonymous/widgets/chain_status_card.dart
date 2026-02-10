import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/anonymous_chain.dart';
import '../providers/anonymous_providers.dart';

class ChainStatusCard extends ConsumerWidget {
  const ChainStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChain = ref.watch(activeChainProvider);
    final isConnecting = ref.watch(isConnectingProvider);
    final connectionProgress = ref.watch(connectionProgressProvider);

    if (activeChain == null) {
      return const _EmptyStateCard();
    }

    return Card(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: _getGradientColors(activeChain.status),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChainHeader(activeChain, isConnecting),
            const SizedBox(height: 12),
            _buildConnectionStatus(activeChain, isConnecting, connectionProgress),
            const SizedBox(height: 12),
            _buildChainMetrics(activeChain),
          ],
        ),
      ),
    );
  }

  Widget _buildChainHeader(AnonymousChain chain, bool isConnecting) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getModeIcon(chain.mode),
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chain.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                chain.modeDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        if (isConnecting)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusText(chain.status),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectionStatus(AnonymousChain chain, bool isConnecting, double progress) {
    if (isConnecting) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing secure chain... ${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      );
    }

    if (chain.isConnected) {
      return Row(
        children: [
          Icon(
            Icons.verified_user,
            color: Colors.white.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Secure connection established',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.warning,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Connection inactive',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildChainMetrics(AnonymousChain chain) {
    return Row(
      children: [
        Expanded(
          child: _buildMetric(
            'Hops',
            '${chain.proxyChain.length}',
            Icons.route,
          ),
        ),
        Expanded(
          child: _buildMetric(
            'Countries',
            '${_getUniqueCountries(chain).length}',
            Icons.language,
          ),
        ),
        Expanded(
          child: _buildMetric(
            'Uptime',
            _formatUptime(chain.uptime),
            Icons.timer,
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(ChainStatus status) {
    switch (status) {
      case ChainStatus.connected:
        return [Colors.green.shade300, Colors.green.shade600];
      case ChainStatus.connecting:
        return [Colors.orange.shade300, Colors.orange.shade600];
      case ChainStatus.disconnecting:
        return [Colors.red.shade300, Colors.red.shade600];
      case ChainStatus.rotating:
        return [Colors.blue.shade300, Colors.blue.shade600];
      case ChainStatus.inactive:
        return [Colors.grey.shade400, Colors.grey.shade700];
      case ChainStatus.error:
        return [Colors.red.shade400, Colors.red.shade700];
    }
  }

  IconData _getModeIcon(AnonymousMode mode) {
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
      case AnonymousMode.custom:
        return Icons.settings;
    }
  }

  String _getStatusText(ChainStatus status) {
    switch (status) {
      case ChainStatus.connected:
        return 'ACTIVE';
      case ChainStatus.connecting:
        return 'CONNECTING';
      case ChainStatus.disconnecting:
        return 'DISCONNECTING';
      case ChainStatus.rotating:
        return 'ROTATING';
      case ChainStatus.inactive:
        return 'INACTIVE';
      case ChainStatus.error:
        return 'ERROR';
    }
  }

  Set<String> _getUniqueCountries(AnonymousChain chain) {
    return chain.proxyChain
        .map((proxy) => proxy.country ?? 'Unknown')
        .toSet();
  }

  String _formatUptime(Duration? uptime) {
    if (uptime == null) return '--';
    
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '<1m';
    }
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.link_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Active Chain',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select an anonymous mode to establish\na secure proxy chain',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}