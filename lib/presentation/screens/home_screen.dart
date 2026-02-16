import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../core/theme/app_theme.dart';
import '../../business_logic/managers/auto_vpn_config_manager.dart';
import '../../business_logic/providers/built_in_server_providers.dart';
import '../../platform/services/wireguard_vpn_service.dart';
import '../widgets/connection_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final Logger _logger = Logger();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final AutoVpnConfigManager _autoManager = AutoVpnConfigManager();

  // Connection tracking
  DateTime? _connectedSince;
  final Stopwatch _connectionTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeVpn();
  }

  Future<void> _initializeVpn() async {
    try {
      await _autoManager.initialize();
      if (mounted) {
        await _checkVpnState();
      }
    } catch (e) {
      _logger.e('VPN initialization failed', error: e);
    }
  }

  Future<void> _checkVpnState() async {
    try {
      final wgService = WireGuardVpnService();
      await wgService.initialize();
      final isConnected = await wgService.isConnected;
      final currentState = ref.read(serverConnectionStateProvider);

      if (isConnected && currentState != ServerConnectionState.connected) {
        ref.read(serverConnectionStateProvider.notifier).state =
            ServerConnectionState.connected;
        _connectedSince = DateTime.now();
        _connectionTimer.start();
      } else if (!isConnected &&
          currentState == ServerConnectionState.connected) {
        ref.read(serverConnectionStateProvider.notifier).state =
            ServerConnectionState.disconnected;
        _connectedSince = null;
        _connectionTimer.stop();
        _connectionTimer.reset();
      }
      if (mounted) setState(() {});
    } catch (e) {
      _logger.e('Failed to check VPN state', error: e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVpnState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final connectionState = ref.read(serverConnectionStateProvider);

    if (connectionState == ServerConnectionState.connected) {
      await _disconnect();
    } else if (connectionState == ServerConnectionState.disconnected ||
        connectionState == ServerConnectionState.error) {
      await _connect();
    }
  }

  Future<void> _connect() async {
    ref.read(serverConnectionStateProvider.notifier).state =
        ServerConnectionState.connecting;

    try {
      _logger.i('Starting VPN connection...');

      final config = await _autoManager.getBestAvailableConfig();
      if (config == null) {
        throw Exception('No VPN configuration available');
      }

      ref.read(activeVpnConfigProvider.notifier).state = config;

      final wgService = WireGuardVpnService();
      await wgService.initialize();
      await wgService.connect(config);

      _connectedSince = DateTime.now();
      _connectionTimer.reset();
      _connectionTimer.start();

      ref.read(serverConnectionStateProvider.notifier).state =
          ServerConnectionState.connected;
      _logger.i('VPN connected successfully');
    } catch (e) {
      _logger.e('VPN connection failed', error: e);
      ref.read(serverConnectionStateProvider.notifier).state =
          ServerConnectionState.error;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    ref.read(serverConnectionStateProvider.notifier).state =
        ServerConnectionState.disconnecting;

    try {
      _logger.i('Disconnecting VPN...');

      final wgService = WireGuardVpnService();
      await wgService.disconnect();

      _connectedSince = null;
      _connectionTimer.stop();
      _connectionTimer.reset();

      ref.read(serverConnectionStateProvider.notifier).state =
          ServerConnectionState.disconnected;
      ref.read(activeVpnConfigProvider.notifier).state = null;

      _logger.i('VPN disconnected');
    } catch (e) {
      _logger.e('VPN disconnect failed', error: e);
      ref.read(serverConnectionStateProvider.notifier).state =
          ServerConnectionState.error;
    }
  }

  String _formatUptime() {
    if (_connectedSince == null) return '00:00:00';
    final duration = _connectionTimer.elapsed;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionStateProvider);
    final activeConfig = ref.watch(activeVpnConfigProvider);
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;

    final isConnected = connectionState == ServerConnectionState.connected;
    final isConnecting = connectionState == ServerConnectionState.connecting ||
        connectionState == ServerConnectionState.disconnecting;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Status Card
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStatusCard(
                  theme, customColors, isConnected, isConnecting),
            ),

            const Spacer(),

            // Connect Button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnecting ? _pulseAnimation.value : 1.0,
                  child: ConnectionButton(
                    isConnected: isConnected,
                    isConnecting: isConnecting,
                    onTap: _handleConnect,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Status Text
            Text(
              isConnected
                  ? 'Connected'
                  : isConnecting
                      ? 'Connecting...'
                      : 'Tap to Connect',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            // Connection Info (when connected)
            if (isConnected) ...[
              _buildConnectionInfo(theme, customColors, activeConfig),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, AppCustomColors customColors,
      bool isConnected, bool isConnecting) {
    Color cardColor;
    Color iconColor;
    String statusText;
    String subText;
    IconData icon;

    if (isConnected) {
      cardColor = customColors.success;
      iconColor = customColors.vpnConnected;
      statusText = 'PROTECTED';
      subText = 'Your connection is secure';
      icon = Icons.shield;
    } else if (isConnecting) {
      cardColor = customColors.vpnConnecting;
      iconColor = customColors.vpnConnecting;
      statusText = 'CONNECTING';
      subText = 'Establishing secure tunnel...';
      icon = Icons.sync;
    } else {
      cardColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.outline;
      statusText = 'NOT PROTECTED';
      subText = 'Your connection is not secure';
      icon = Icons.shield_outlined;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cardColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(
      ThemeData theme, AppCustomColors customColors, dynamic activeConfig) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: customColors.vpnConnected.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          _infoRow(
            theme,
            Icons.timer_outlined,
            'Duration',
            _formatUptime(),
          ),
          if (activeConfig != null) ...[
            const Divider(height: 24),
            _infoRow(
              theme,
              Icons.dns_outlined,
              'Server',
              activeConfig.name ?? 'Auto',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
