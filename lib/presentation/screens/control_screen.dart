import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../core/theme/app_theme.dart';
import 'package:privacy_vpn_controller/data/models/anonymous_chain.dart';
import 'package:privacy_vpn_controller/business_logic/providers/anonymous_providers.dart';
import 'package:privacy_vpn_controller/presentation/widgets/connection_button.dart';
import 'package:privacy_vpn_controller/presentation/screens/mode_info_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/status_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/config_screen.dart';
import 'package:privacy_vpn_controller/data/models/connection_status.dart';
// Built-in servers imports
import '../../business_logic/managers/auto_vpn_config_manager.dart';
import '../../business_logic/providers/built_in_server_providers.dart';
import 'vpn_main_screen_example.dart';

class ControlScreen extends ConsumerStatefulWidget {
  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> 
    with TickerProviderStateMixin {
  
  final Logger _logger = Logger();
  late AnimationController _pulseController;
  late AnimationController _mapController; // Added for map animation
  late Animation<double> _pulseAnimation;
  AnonymousMode _selectedMode = AnonymousMode.turbo;
  
  // Auto VPN Configuration Manager
  final AutoVpnConfigManager _autoManager = AutoVpnConfigManager();
  bool _isAutoManagerInitialized = false;
  
  // Real connection tracking
  DateTime? _connectedSince;
  final Stopwatch _connectionTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Map animation
    _mapController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Initialize auto VPN configuration
    _initializeAutoVpn();
  }
  
  Future<void> _initializeAutoVpn() async {
    try {
      await _autoManager.initialize();
      if (mounted) {
        setState(() {
          _isAutoManagerInitialized = true;
        });
      }
    } catch (e) {
      _logger.e('Failed to initialize auto VPN manager', error: e);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose(); // Dispose map controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChain = ref.watch(activeAnonymousChainProvider);
    final serverState = ref.watch(serverConnectionStateProvider);
    final theme = Theme.of(context);
    
    // Unified connection state: connected if EITHER system is connected
    final isEffectivelyConnected = activeChain?.status == ChainStatus.connected 
        || serverState == ServerConnectionState.connected;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Privacy Controller', 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.colorScheme.surface.withOpacity(0.5),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded),
            color: theme.colorScheme.surfaceContainer,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'modes') {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => ModeInfoScreen()),
                );
              } else if (value == 'servers') {
                // Navigate to built-in servers screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VpnMainScreen()),
                );
              } else if (value == 'config') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigScreen()),
                );
              } else if (value == 'privacy') {
                _showPrivacyInfo();
              } else if (value == 'status') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StatusScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              _buildMenuItem(context, 'modes', Icons.info_outline, 'VPN Modes'),
              _buildMenuItem(context, 'servers', Icons.dns, 'Free VPN Servers'), // NEW
              _buildMenuItem(context, 'config', Icons.settings, 'Configuration'),
              _buildMenuItem(context, 'status', Icons.analytics_outlined, 'Connection Status'),
              _buildMenuItem(context, 'privacy', Icons.privacy_tip_outlined, 'Privacy Info'),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _mapController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WorldMapPainter(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    rotation: _mapController.value,
                  ),
                );
              },
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(activeChain),
                  SizedBox(height: 32),
                  _buildConnectSection(activeChain),
                  SizedBox(height: 48),
                  _buildQuickActions(),
                  if (isEffectivelyConnected) ...[
                    SizedBox(height: 24),
                    _buildConnectionInfo(activeChain),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(BuildContext context, String value, IconData icon, String text) {
    final theme = Theme.of(context);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AnonymousChain? activeChain) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    final serverState = ref.watch(serverConnectionStateProvider);
    
    // Unified state: connected if EITHER system is connected
    final isConnected = activeChain?.status == ChainStatus.connected 
        || serverState == ServerConnectionState.connected;
    final isConnecting = (activeChain?.status == ChainStatus.connecting 
        || serverState == ServerConnectionState.connecting) && !isConnected;
    
    // Watch both VPN and proxy status for comprehensive display
    final vpnStatusAsync = ref.watch(vpnStatusProvider);
    final proxyStatusAsync = ref.watch(proxyStatusProvider);
    
    // Determine colors based on state
    Color cardColor;
    Color iconColor;
    String statusText;
    String subText;

    if (isConnected) {
      cardColor = customColors.success;
      iconColor = customColors.vpnConnected;
      statusText = 'PROTECTED';
      
      // Build comprehensive status text
      var statusParts = <String>[];
      
      vpnStatusAsync.whenData((vpnStatus) {
        if (vpnStatus.vpnStatus == VpnStatus.connected) {
          statusParts.add('VPN Active');
        }
      });
      
      proxyStatusAsync.whenData((proxyStatus) {
        if (proxyStatus == ProxyStatus.enabled) {
          statusParts.add('Proxy Chain Active');
        }
      });
      
      if (statusParts.isEmpty) {
        subText = 'Traffic is encrypted & anonymous';
      } else {
        subText = '${statusParts.join(' • ')} • Anonymous';
      }
    } else if (isConnecting) {
      cardColor = customColors.vpnConnecting;
      iconColor = customColors.vpnConnecting;
      statusText = 'SECURING...';
      subText = 'Establishing secure tunnel';
    } else {
      cardColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.outline;
      statusText = 'UNPROTECTED';
      subText = 'Tap to secure your connection';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: cardColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isConnected || isConnecting)
                      BoxShadow(
                        color: iconColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Icon(
                  isConnected 
                    ? Icons.shield 
                    : isConnecting 
                    ? Icons.sync 
                    : Icons.shield_outlined,
                  color: iconColor,
                  size: 32,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (activeChain?.mode != null && isConnected)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_outlined, 
                                size: 12, 
                                color: customColors.success
                              ),
                              SizedBox(width: 6),
                              Text(
                                '${activeChain!.mode.toString().split('.').last.toUpperCase()} MODE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildConnectSection(AnonymousChain? activeChain) {
    final serverState = ref.watch(serverConnectionStateProvider);
    
    // Unified: connected if EITHER system reports connected
    final isConnected = activeChain?.status == ChainStatus.connected
        || serverState == ServerConnectionState.connected;
    final isConnecting = (activeChain?.status == ChainStatus.connecting
        || serverState == ServerConnectionState.connecting) && !isConnected;
    final isDisconnecting = activeChain?.status == ChainStatus.disconnecting
        || serverState == ServerConnectionState.disconnecting;
    final hasError = activeChain?.status == ChainStatus.error
        || serverState == ServerConnectionState.error;
    
    return Column(
      children: [
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: (isConnecting || isDisconnecting)
                    ? _pulseAnimation.value : 1.0,
                child: ConnectionButton(
                  isConnected: isConnected,
                  isConnecting: isConnecting || isDisconnecting,
                  onTap: () => _handleUnifiedToggle(),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),
        Text(
          isConnected 
            ? 'VPN Connected${activeChain?.mode != null ? ' (${activeChain!.mode.name.toUpperCase()})' : ''}'
            : isConnecting
            ? 'Establishing Secure Connection...'
            : isDisconnecting
            ? 'Disconnecting...'
            : hasError
            ? 'Connection Error - Tap to Retry'
            : 'Tap to Connect',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: hasError ? Colors.red : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 8),
          Text(
            'Connection failed. Tap to retry.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.white70, size: 20),
            SizedBox(width: 8),
            Text(
              'Quick Connect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // Auto VPN Actions - NEW
        if (_isAutoManagerInitialized) _buildAutoVpnActions(),
        SizedBox(height: 16),
        // Anonymous Mode Actions
        Row(
          children: [
            Icon(Icons.security, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text(
              'Anonymous Modes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildAnonymousActions(),
      ],
    );
  }

  Widget _buildAutoVpnActions() {
    final connectionState = ref.watch(serverConnectionStateProvider);
    final activeConfig = ref.watch(activeVpnConfigProvider);
    
    return Column(
      children: [
        // Main Auto Connect Button
        Container(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: connectionState == ServerConnectionState.connecting 
                || connectionState == ServerConnectionState.disconnecting
                ? null : () {
              _handleAutoConnect();
            },
            icon: connectionState == ServerConnectionState.connecting 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : connectionState == ServerConnectionState.disconnecting
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : connectionState == ServerConnectionState.connected
                        ? Icon(Icons.power_settings_new, size: 24)
                        : Icon(Icons.auto_awesome, size: 24),
            label: Text(
              connectionState == ServerConnectionState.connected 
                  ? 'Disconnect from ${activeConfig?.name ?? "Server"}'
                  : connectionState == ServerConnectionState.connecting 
                      ? 'Connecting...'
                      : connectionState == ServerConnectionState.disconnecting
                          ? 'Disconnecting...'
                          : 'Auto Connect to Best Server',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: connectionState == ServerConnectionState.connected
                  ? Colors.green
                  : connectionState == ServerConnectionState.error
                      ? Colors.red.shade700
                      : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Quick VPN Options Row
        Row(
          children: [
            Expanded(
              child: _buildQuickVpnCard(
                'Cloudflare WARP',
                'Unlimited & Fast',
                Icons.cloud,
                Colors.orange,
                () => _handleWarpConnect(),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildQuickVpnCard(
                'Streaming',
                'Video optimized',
                Icons.play_circle_filled,
                Colors.red,
                () => _handleStreamingConnect(),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildQuickVpnCard(
                'Browse Servers',
                'Choose manually',
                Icons.list,
                Colors.blue,
                () => _openServersList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildQuickVpnCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _QuickActionButton(
          icon: Icons.flash_on,
          label: 'Turbo Mode',
          color: _selectedMode == AnonymousMode.turbo ? Colors.green : null,
          isSelected: _selectedMode == AnonymousMode.turbo,
          onTap: () => _selectMode(AnonymousMode.turbo),
        ),
        _QuickActionButton(
          icon: Icons.security,
          label: 'Stealth Mode',
          color: _selectedMode == AnonymousMode.stealth ? Colors.orange : null,
          isSelected: _selectedMode == AnonymousMode.stealth,
          onTap: () => _selectMode(AnonymousMode.stealth),
        ),
        _QuickActionButton(
          icon: Icons.shield,
          label: 'Ghost Mode',
          color: _selectedMode == AnonymousMode.ghost ? Colors.red : null,
          isSelected: _selectedMode == AnonymousMode.ghost,
          onTap: () => _selectMode(AnonymousMode.ghost),
        ),
      ],
    );
  }

  Widget _buildConnectionInfo(AnonymousChain? activeChain) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    final activeConfig = ref.watch(activeVpnConfigProvider);
    
    // Real connection duration
    final duration = _connectedSince != null 
        ? DateTime.now().difference(_connectedSince!) 
        : Duration.zero;
    final timeStr = '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    
    // Real server name
    final serverName = activeConfig?.name ?? 'Cloudflare WARP';
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: customColors.vpnConnected.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, color: theme.colorScheme.primary, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Connection Info',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildConnectionDetail('Server', serverName),
              _buildConnectionDetail('Protocol', 'WireGuard'),
              _buildConnectionDetail('Encryption', 'ChaCha20-Poly1305'),
              _buildConnectionDetail('DNS', '1.1.1.1 (Cloudflare)'),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Uptime', timeStr, Icons.timer),
                  _buildStatCard('Port', '${activeConfig?.port ?? 2408}', Icons.router),
                  _buildStatCard('Status', 'Active', Icons.check_circle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionDetail(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: customColors.vpnConnected.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customColors.vpnConnected.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: customColors.vpnConnected),
          SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: customColors.vpnConnected,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _selectMode(AnonymousMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  /// Unified toggle: disconnects from whichever system is active,
  /// or connects via auto-connect (direct WireGuard VPN).
  void _handleUnifiedToggle() async {
    final activeChain = ref.read(activeAnonymousChainProvider);
    final serverState = ref.read(serverConnectionStateProvider);
    
    final isConnected = activeChain?.status == ChainStatus.connected 
        || serverState == ServerConnectionState.connected;
    
    if (isConnected) {
      // --- DISCONNECT from whichever is active ---
      await _handleUnifiedDisconnect();
    } else {
      // --- CONNECT via auto-connect (fastest path) ---
      await _handleAutoConnect();
    }
  }

  /// Disconnect from both state systems to ensure clean state
  Future<void> _handleUnifiedDisconnect() async {
    try {
      final activeChain = ref.read(activeAnonymousChainProvider);
      final serverState = ref.read(serverConnectionStateProvider);
      
      // Update both UIs to disconnecting
      if (activeChain != null) {
        ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.disconnecting);
      }
      if (serverState == ServerConnectionState.connected) {
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnecting;
      }
      
      // Disconnect through auto manager (covers WireGuard tunnel)
      await _autoManager.disconnect();
      
      // Also disconnect chain service if it was used  
      if (activeChain != null) {
        final chainService = ref.read(anonymousChainServiceProvider);
        try { await chainService.disconnect(ref); } catch (_) {}
      }
      
      // Clear BOTH state systems
      ref.read(activeAnonymousChainProvider.notifier).clearChain();
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
      ref.read(activeVpnConfigProvider.notifier).state = null;
      
      // Stop timer
      _connectionTimer.stop();
      _connectionTimer.reset();
      _connectedSince = null;
      
      _logger.d('Disconnected from VPN (unified)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VPN Disconnected'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      _logger.e('Failed to disconnect: $e');
      // Revert states on error
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
        }
      });
    }
  }

  void _showPrivacyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1D1E33),
        title: Text('Privacy VPN', style: TextStyle(color: Colors.white)),
        content: Text(
          '• Zero-logging policy\n'
          '• No user accounts required\n'
          '• Open source friendly\n'
          '• No tracking or analytics\n'
          '• Free servers included\n'
          '• Built-in auto configuration',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // Auto VPN Action Handlers - Using real VPN connection
  Future<void> _handleAutoConnect() async {
    if (!_isAutoManagerInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto VPN manager not ready. Please wait...'), backgroundColor: Colors.orange),
      );
      return;
    }

    final currentState = ref.read(serverConnectionStateProvider);
    
    // If already connected, disconnect first
    if (currentState == ServerConnectionState.connected) {
      try {
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnecting;
        final success = await _autoManager.disconnect();
        if (success) {
          ref.read(activeVpnConfigProvider.notifier).state = null;
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
          // Also clear anonymous chain state and timer
          ref.read(activeAnonymousChainProvider.notifier).clearChain();
          _connectionTimer.stop();
          _connectionTimer.reset();
          _connectedSince = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('VPN Disconnected'), backgroundColor: Colors.grey),
            );
          }
        } else {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
        }
      } catch (e) {
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      }
      return;
    }

    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final success = await _autoManager.oneClickConnect();

      if (success && _autoManager.currentConfig != null) {
        ref.read(activeVpnConfigProvider.notifier).state = _autoManager.currentConfig;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;
        
        // Start connection timer
        _connectedSince = DateTime.now();
        _connectionTimer.reset();
        _connectionTimer.start();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${_autoManager.currentConfig!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not establish VPN connection. Please try a different server.');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(label: 'RETRY', textColor: Colors.white, onPressed: _handleAutoConnect),
          ),
        );
      }
      
      // Clear error state after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
        }
      });
    }
  }

  Future<void> _handleWarpConnect() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final warpConfig = await ref.read(warpConfigProvider.future);

      if (warpConfig != null) {
        // Actually connect using the auto manager's connectWithConfig
        final success = await _autoManager.connectWithConfig(warpConfig);
        
        if (success) {
          ref.read(activeVpnConfigProvider.notifier).state = warpConfig;
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;
          
          // Start connection timer
          _connectedSince = DateTime.now();
          _connectionTimer.reset();
          _connectionTimer.start();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected to Cloudflare WARP'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('WARP VPN tunnel could not be established');
        }
      } else {
        throw Exception('WARP configuration generation failed. Check your network.');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WARP connection failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(label: 'RETRY', textColor: Colors.white, onPressed: _handleWarpConnect),
          ),
        );
      }
      
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
        }
      });
    }
  }

  Future<void> _handleStreamingConnect() async {
    if (!_isAutoManagerInitialized) return;

    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final config = await _autoManager.getStreamingOptimizedConfig();

      if (config != null) {
        // Actually connect using the auto manager
        final success = await _autoManager.connectWithConfig(config);
        
        if (success) {
          ref.read(activeVpnConfigProvider.notifier).state = config;
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;
          
          // Start connection timer
          _connectedSince = DateTime.now();
          _connectionTimer.reset();
          _connectionTimer.start();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected to streaming server: ${config.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Streaming server VPN tunnel failed');
        }
      } else {
        throw Exception('No streaming-optimized servers available');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Streaming connection failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
        }
      });
    }
  }

  void _openServersList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VpnMainScreen()),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor.withOpacity(0.2) 
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
              ? activeColor.withOpacity(0.5)
              : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: activeColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? activeColor : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  final Color color;
  final double rotation;

  _WorldMapPainter({required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Draw concentric circles
    canvas.drawCircle(center, 100, paint);
    canvas.drawCircle(center, 180, paint..strokeWidth = 0.5);
    canvas.drawCircle(center, 260, paint..strokeWidth = 0.3);

    // Grid lines
    final gridPath = Path();
    for (var i = 0; i < size.width; i += 40) {
      gridPath.moveTo(i.toDouble(), 0);
      gridPath.lineTo(i.toDouble(), size.height);
    }
    for (var i = 0; i < size.height; i += 40) {
      gridPath.moveTo(0, i.toDouble());
      gridPath.lineTo(size.width, i.toDouble());
    }
    canvas.drawPath(gridPath, paint..color = color.withOpacity(0.05));
    
    // Rotating nodes
    final nodes = [
      Offset(centerX - 80, centerY - 60),
      Offset(centerX + 60, centerY - 80), 
      Offset(centerX + 120, centerY - 40),
      Offset(centerX + 180, centerY + 20),
      Offset(centerX - 120, centerY + 40),
      Offset(centerX - 50, centerY + 150),
      Offset(centerX + 90, centerY + 120),
    ];

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(rotation * 2 * 3.14159);
    canvas.translate(-centerX, -centerY);

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      canvas.drawCircle(node, 4, dotPaint);
      
      // Draw lines between some nodes
      if (i > 0) {
        canvas.drawLine(nodes[i-1], node, paint..strokeWidth = 0.5);
      }
      // Connect to center
      canvas.drawLine(center, node, paint..strokeWidth = 0.2);
    }
    
    // Draw "satellite"
    final satelliteX = centerX + 180 * math.cos(rotation * 4 * 3.14159);
    final satelliteY = centerY + 180 * math.sin(rotation * 4 * 3.14159);
    canvas.drawCircle(Offset(satelliteX, satelliteY), 6, dotPaint..color = color.withOpacity(1.0));
    canvas.drawCircle(Offset(satelliteX, satelliteY), 10, paint..style = PaintingStyle.stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) => 
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}