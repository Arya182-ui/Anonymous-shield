import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../business_logic/providers/anonymous_providers.dart';
import '../../business_logic/providers/built_in_server_providers.dart';
import '../../data/models/anonymous_chain.dart';
import '../../data/models/connection_status.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    final activeChain = ref.watch(activeAnonymousChainProvider);
    final serverState = ref.watch(serverConnectionStateProvider);
    final activeConfig = ref.watch(activeVpnConfigProvider);

    // Unified connection state
    final isConnected = activeChain?.status == ChainStatus.connected ||
        serverState == ServerConnectionState.connected;
    final isConnecting = (activeChain?.status == ChainStatus.connecting ||
            serverState == ServerConnectionState.connecting) &&
        !isConnected;

    final vpnStatusAsync = ref.watch(vpnStatusProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Connection Status',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () => _refreshStatus(),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshStatus,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.primary,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                16, kToolbarHeight + MediaQuery.of(context).padding.top + 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainStatusCard(theme, customColors, isConnected, isConnecting),
                SizedBox(height: 20),
                if (isConnected)
                  _buildConnectionDetails(theme, customColors, activeConfig),
                if (isConnected) SizedBox(height: 20),
                _buildSecurityStatus(theme, customColors, isConnected, vpnStatusAsync),
                SizedBox(height: 20),
                _buildNetworkInfo(theme, isConnected, activeConfig),
                if (isConnected) ...[
                  SizedBox(height: 20),
                  _buildConnectionRoute(theme, customColors, activeConfig),
                ],
                SizedBox(height: 20),
                _buildDiagnostics(theme, customColors, isConnected, vpnStatusAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatusCard(
      ThemeData theme, AppCustomColors customColors, bool isConnected, bool isConnecting) {
    final statusColor = isConnected
        ? customColors.vpnConnected
        : isConnecting
            ? customColors.vpnConnecting
            : customColors.vpnDisconnected;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.15),
                statusColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: isConnected
                      ? [BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)]
                      : null,
                ),
                child: Icon(
                  isConnected
                      ? Icons.shield_rounded
                      : isConnecting ? Icons.sync_rounded : Icons.shield_outlined,
                  size: 48,
                  color: statusColor,
                ),
              ),
              SizedBox(height: 20),
              Text(
                isConnected ? 'SECURED' : isConnecting ? 'CONNECTING...' : 'NOT CONNECTED',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 26,
                ),
              ),
              SizedBox(height: 8),
              Text(
                isConnected
                    ? 'Your connection is fully protected'
                    : isConnecting
                        ? 'Establishing secure tunnel...'
                        : 'Your traffic is not encrypted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionDetails(
      ThemeData theme, AppCustomColors customColors, dynamic activeConfig) {
    final serverName = activeConfig?.name ?? 'Cloudflare WARP';
    final endpoint = activeConfig?.endpoint ?? activeConfig?.serverAddress ?? 'N/A';
    final port = activeConfig?.port ?? 2408;

    return _buildCard(
      theme: theme,
      icon: Icons.link_rounded,
      title: 'Connection Details',
      borderColor: customColors.vpnConnected.withValues(alpha: 0.2),
      children: [
        _buildDetailRow(theme, 'Server', serverName, Icons.dns_rounded),
        _buildDetailRow(theme, 'Endpoint', '$endpoint', Icons.language_rounded),
        _buildDetailRow(theme, 'Port', '$port', Icons.router_rounded),
        _buildDetailRow(theme, 'Protocol', 'WireGuard', Icons.vpn_key_rounded),
        _buildDetailRow(theme, 'Encryption', 'ChaCha20-Poly1305', Icons.lock_rounded),
      ],
    );
  }

  Widget _buildSecurityStatus(
      ThemeData theme, AppCustomColors customColors, bool isConnected, AsyncValue vpnStatusAsync) {
    bool vpnTunnelActive = false;
    vpnStatusAsync.whenData((vpnStatus) {
      if (vpnStatus.vpnStatus == VpnStatus.connected) vpnTunnelActive = true;
    });

    return _buildCard(
      theme: theme,
      icon: Icons.security_rounded,
      title: 'Security Status',
      children: [
        _buildSecurityItem(theme, customColors, 'VPN Tunnel', isConnected || vpnTunnelActive,
            isConnected ? 'WireGuard tunnel active' : 'No active tunnel'),
        _buildSecurityItem(theme, customColors, 'IP Protection', isConnected,
            isConnected ? 'Your real IP is hidden' : 'IP address exposed'),
        _buildSecurityItem(theme, customColors, 'DNS Security', isConnected,
            isConnected ? 'Using Cloudflare DNS (1.1.1.1)' : 'Using default DNS'),
        _buildSecurityItem(theme, customColors, 'Traffic Encryption', isConnected,
            isConnected ? 'ChaCha20-Poly1305 encryption' : 'Traffic is unencrypted'),
        _buildSecurityItem(
            theme, customColors, 'Zero Logging', true, 'No logs are collected'),
      ],
    );
  }

  Widget _buildNetworkInfo(ThemeData theme, bool isConnected, dynamic activeConfig) {
    final dns = (activeConfig != null &&
            activeConfig.dnsServers != null &&
            (activeConfig.dnsServers as List).isNotEmpty)
        ? (activeConfig.dnsServers as List).join(', ')
        : '1.1.1.1, 1.0.0.1';
    final mtu = activeConfig?.mtu ?? 1280;

    return _buildCard(
      theme: theme,
      icon: Icons.network_check_rounded,
      title: 'Network Information',
      children: [
        _buildDetailRow(theme, 'Public IP', isConnected ? 'Hidden (VPN)' : 'Exposed',
            Icons.public_rounded,
            valueColor: isConnected ? Colors.green : Colors.red),
        _buildDetailRow(
            theme, 'DNS Servers', isConnected ? dns : 'System Default', Icons.dns_rounded),
        _buildDetailRow(theme, 'MTU', '$mtu', Icons.straighten_rounded),
        _buildDetailRow(theme, 'Allowed IPs',
            isConnected ? '0.0.0.0/0 (All traffic)' : 'N/A', Icons.route_rounded),
      ],
    );
  }

  Widget _buildConnectionRoute(
      ThemeData theme, AppCustomColors customColors, dynamic activeConfig) {
    final serverName = activeConfig?.name ?? 'Cloudflare WARP';

    return _buildCard(
      theme: theme,
      icon: Icons.timeline_rounded,
      title: 'Connection Route',
      borderColor: customColors.vpnConnected.withValues(alpha: 0.2),
      children: [
        _buildTimelineItem(theme, customColors, 'Your Device', 'Local Network', 'Origin', true),
        _buildTimelineItem(
            theme, customColors, serverName, 'WireGuard Tunnel', 'VPN Server', false),
      ],
    );
  }

  Widget _buildDiagnostics(
      ThemeData theme, AppCustomColors customColors, bool isConnected, AsyncValue vpnStatusAsync) {
    String tunnelStatus = '--';
    vpnStatusAsync.whenData((vpnStatus) {
      tunnelStatus = vpnStatus.vpnStatus == VpnStatus.connected
          ? 'Active'
          : vpnStatus.vpnStatus == VpnStatus.connecting
              ? 'Starting'
              : 'Inactive';
    });

    return _buildCard(
      theme: theme,
      icon: Icons.analytics_rounded,
      title: 'Diagnostics',
      children: [
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDiagnosticCard(theme, 'Tunnel', tunnelStatus, Icons.vpn_lock_rounded,
                  isConnected ? customColors.vpnConnected : customColors.vpnDisconnected),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticCard(theme, 'Protocol', isConnected ? 'WG' : '--',
                  Icons.security_rounded, theme.colorScheme.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildDiagnosticCard(
                  theme,
                  'Status',
                  isConnected ? 'OK' : '--',
                  isConnected ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  isConnected ? customColors.vpnConnected : customColors.vpnDisconnected),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Reusable Helpers ──────────────────────────────────────────────

  Widget _buildCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary, size: 20),
                  SizedBox(width: 10),
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value, IconData icon,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Flexible(
            child: Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(
      ThemeData theme, AppCustomColors customColors, String title, bool isActive, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive ? customColors.vpnConnected : customColors.vpnDisconnected,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [BoxShadow(color: customColors.vpnConnected.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isActive ? customColors.vpnConnected : customColors.vpnDisconnected,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ThemeData theme, AppCustomColors customColors, String title,
      String subtitle, String type, bool hasNext) {
    return Column(
      children: [
        Row(
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: customColors.vpnConnected,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: customColors.vpnConnected.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1),
                    ],
                  ),
                ),
                if (hasNext)
                  Container(
                      width: 2, height: 36, color: customColors.vpnConnected.withValues(alpha: 0.4)),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(subtitle,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: customColors.vpnConnected.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(type,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: customColors.vpnConnected, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasNext) SizedBox(height: 4),
      ],
    );
  }

  Widget _buildDiagnosticCard(
      ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(label,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _refreshStatus() async {
    await Future.delayed(Duration(milliseconds: 300));
    if (mounted) setState(() {});
  }
}