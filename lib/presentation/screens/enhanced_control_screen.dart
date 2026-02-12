import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../core/theme/app_theme.dart';
import 'package:privacy_vpn_controller/data/models/anonymous_chain.dart';
import 'package:privacy_vpn_controller/data/models/enhanced_vpn_models.dart';
import 'package:privacy_vpn_controller/business_logic/providers/anonymous_providers.dart';
import 'package:privacy_vpn_controller/presentation/widgets/connection_button.dart';
import 'package:privacy_vpn_controller/presentation/screens/mode_info_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/status_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/config_screen.dart';
import 'package:privacy_vpn_controller/data/models/proxy_config.dart';
// Enhanced VPN and Security imports
import '../../business_logic/managers/enhanced_vpn_manager.dart';
import '../../business_logic/services/security_manager.dart';
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
  late AnimationController _mapController;
  late Animation<double> _pulseAnimation;
  
  // Enhanced managers
  final EnhancedVpnManager _vpnManager = EnhancedVpnManager();
  final SecurityManager _securityManager = SecurityManager();
  final AutoVpnConfigManager _autoManager = AutoVpnConfigManager();
  
  // State tracking
  AnonymousMode _selectedMode = AnonymousMode.turbo;
  bool _isVpnManagerInitialized = false;
  // ignore: unused_field
  bool _isSecurityManagerInitialized = false;
  bool _isAutoManagerInitialized = false;
  
  // Connection streams
  StreamSubscription? _vpnStatusSubscription;
  StreamSubscription? _securityAlertSubscription;
  StreamSubscription? _connectionInfoSubscription;
  
  // Current connection info
  VpnConnectionInfo? _connectionInfo;
  List<SecurityAlert> _securityAlerts = [];

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

    _mapController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Initialize enhanced managers
    _initializeManagers();
  }
  
  Future<void> _initializeManagers() async {
    try {
      _logger.i('Initializing enhanced managers');
      
      // Initialize VPN Manager
      final vpnSuccess = await _vpnManager.initialize();
      if (vpnSuccess && mounted) {
        setState(() {
          _isVpnManagerInitialized = true;
        });
        
        // Subscribe to VPN status updates
        _vpnStatusSubscription = _vpnManager.statusStream.listen(
          (status) => _onVpnStatusChanged(status),
          onError: (error) => _logger.e('VPN status stream error: $error'),
        );
        
        // Subscribe to connection info updates
        _connectionInfoSubscription = _vpnManager.connectionInfoStream.listen(
          (info) => _onConnectionInfoChanged(info),
          onError: (error) => _logger.e('Connection info stream error: $error'),
        );
      }
      
      // Initialize Security Manager
      final securitySuccess = await _securityManager.initialize();
      if (securitySuccess && mounted) {
        setState(() {
          _isSecurityManagerInitialized = true;
        });
        
        // Subscribe to security alerts
        _securityAlertSubscription = _securityManager.alertStream.listen(
          (alert) => _onSecurityAlert(alert),
          onError: (error) => _logger.e('Security alert stream error: $error'),
        );
        
        // Enable basic security features by default
        await _securityManager.enableKillSwitch();
        await _securityManager.enableDnsLeakProtection();
      }
      
      // Initialize Auto VPN Manager
      await _autoManager.initialize();
      if (mounted) {
        setState(() {
          _isAutoManagerInitialized = true;
        });
      }
      
      _logger.i('Managers initialized - VPN: $vpnSuccess, Security: $securitySuccess');
      
    } catch (e) {
      _logger.e('Failed to initialize managers', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize VPN services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVpnStatusChanged(VpnConnectionStatus status) {
    if (!mounted) return;
    
    _logger.i('VPN status changed: ${status.vpnStatus}');
    
    // Update Riverpod state for UI compatibility
    final activeChainNotifier = ref.read(activeAnonymousChainProvider.notifier);
    final currentChain = ref.read(activeAnonymousChainProvider);
    
    ChainStatus chainStatus;
    switch (status.vpnStatus) {
      case VpnConnectionState.connected:
        chainStatus = ChainStatus.connected;
        break;
      case VpnConnectionState.connecting:
        chainStatus = ChainStatus.connecting;
        break;
      case VpnConnectionState.disconnecting:
        chainStatus = ChainStatus.disconnecting;
        break;
      case VpnConnectionState.disconnected:
        chainStatus = ChainStatus.inactive;
        break;
      case VpnConnectionState.error:
        chainStatus = ChainStatus.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VPN connection error: ${status.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
    
    if (currentChain != null) {
      activeChainNotifier.updateChainStatus(chainStatus);
    }
  }

  void _onConnectionInfoChanged(VpnConnectionInfo info) {
    if (!mounted) return;
    
    setState(() {
      _connectionInfo = info;
    });
    
    _logger.d('Connection info updated: ${info.publicIp} (${info.country})');
  }

  void _onSecurityAlert(SecurityAlert alert) {
    if (!mounted) return;
    
    setState(() {
      _securityAlerts.insert(0, alert);
      
      // Keep only last 10 alerts
      if (_securityAlerts.length > 10) {
        _securityAlerts.removeLast();
      }
    });
    
    // Show critical alerts as snackbars
    if (alert.type == SecurityAlertType.critical) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Security Alert: ${alert.title}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Details',
            onPressed: () => _showSecurityAlertDetails(alert),
          ),
        ),
      );
    }
    
    _logger.w('Security alert: ${alert.typeString} - ${alert.title}');
  }

  @override
  void dispose() {
    _vpnStatusSubscription?.cancel();
    _securityAlertSubscription?.cancel();
    _connectionInfoSubscription?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    _vpnManager.dispose();
    _securityManager.dispose();
    super.dispose();
  }

  // Enhanced connection handling
  Future<void> _handleConnectionToggle() async {
    if (!_isVpnManagerInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VPN manager not ready')),
      );
      return;
    }

    try {
      final activeChain = ref.read(activeAnonymousChainProvider);
      final isConnected = activeChain?.status == ChainStatus.connected;
      
      if (isConnected) {
        // Disconnect
        _logger.i('Disconnecting VPN');
        await _vpnManager.disconnect();
      } else {
        // Connect with selected mode
        _logger.i('Connecting with mode: $_selectedMode');
        
        final proxyChain = _generateProxyChain(_selectedMode);
        switch (_selectedMode) {
          case AnonymousMode.turbo:
            await _vpnManager.connectTurboMode(proxyChain);
            break;
            
          case AnonymousMode.stealth:
            await _vpnManager.connectStealthMode(proxyChain);
            break;
            
          case AnonymousMode.ghost:
            await _vpnManager.connectGhostMode(proxyChain);
            break;
            
          case AnonymousMode.tor:
          case AnonymousMode.paranoid:
          case AnonymousMode.custom:
            await _vpnManager.connectGhostMode(proxyChain);
            break;
        }
        
        // Update active chain state
        ref.read(activeAnonymousChainProvider.notifier).setChain(AnonymousChain(
          id: 'chain_${DateTime.now().millisecondsSinceEpoch}',
          name: '${_selectedMode.name} Chain',
          mode: _selectedMode,
          proxyChain: proxyChain,
          status: ChainStatus.connecting,
          connectedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      _logger.e('Connection toggle failed', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectMode(AnonymousMode mode) {
    setState(() {
      _selectedMode = mode;
    });
    _logger.i('Selected anonymous mode: $mode');
  }

  List<ProxyConfig> _generateProxyChain(AnonymousMode mode) {
    switch (mode) {
      case AnonymousMode.turbo:
        return [
          ProxyConfig(
            id: 'turbo_single',
            name: 'Turbo Proxy',
            type: ProxyType.shadowsocks,
            role: ProxyRole.entry,
            host: 'turbo.proxy.net',
            port: 8388,
            method: 'chacha20-ietf-poly1305',
            password: 'turbo_key',
            country: 'Singapore',
            countryCode: 'SG',
            flagEmoji: '🇸🇬',
            createdAt: DateTime.now(),
          ),
        ];
      case AnonymousMode.stealth:
        return [
          ProxyConfig(
            id: 'stealth_entry',
            name: 'Stealth Entry',
            type: ProxyType.shadowsocks,
            role: ProxyRole.entry,
            host: 'entry.stealth.net',
            port: 8388,
            method: 'chacha20-ietf-poly1305',
            password: 'stealth_entry',
            country: 'Netherlands',
            countryCode: 'NL',
            flagEmoji: '🇳🇱',
            createdAt: DateTime.now(),
          ),
          ProxyConfig(
            id: 'stealth_exit',
            name: 'Stealth Exit',
            type: ProxyType.shadowsocks,
            role: ProxyRole.exit,
            host: 'exit.stealth.net',
            port: 8389,
            method: 'chacha20-ietf-poly1305',
            password: 'stealth_exit',
            country: 'Switzerland',
            countryCode: 'CH',
            flagEmoji: '🇨🇭',
            createdAt: DateTime.now(),
          ),
        ];
      case AnonymousMode.ghost:
        return [
          ProxyConfig(
            id: 'ghost_entry',
            name: 'Ghost Entry',
            type: ProxyType.shadowsocks,
            role: ProxyRole.entry,
            host: 'entry1.ghost.net',
            port: 8388,
            method: 'chacha20-ietf-poly1305',
            password: 'ghost_entry',
            country: 'India',
            countryCode: 'IN',
            flagEmoji: '🇮🇳',
            createdAt: DateTime.now(),
          ),
          ProxyConfig(
            id: 'ghost_middle',
            name: 'Ghost Middle',
            type: ProxyType.shadowsocks,
            role: ProxyRole.middle,
            host: 'middle.ghost.net',
            port: 8389,
            method: 'chacha20-ietf-poly1305',
            password: 'ghost_middle',
            country: 'Romania',
            countryCode: 'RO',
            flagEmoji: '🇷🇴',
            createdAt: DateTime.now(),
          ),
          ProxyConfig(
            id: 'ghost_exit',
            name: 'Ghost Exit',
            type: ProxyType.shadowsocks,
            role: ProxyRole.exit,
            host: 'exit.ghost.net',
            port: 8390,
            method: 'chacha20-ietf-poly1305',
            password: 'ghost_exit',
            country: 'Iceland',
            countryCode: 'IS',
            flagEmoji: '🇮🇸',
            createdAt: DateTime.now(),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChain = ref.watch(activeAnonymousChainProvider);
    final theme = Theme.of(context);
    
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VpnMainScreen()),
                );
              } else if (value == 'config') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigScreen()),
                );
              } else if (value == 'security') {
                _showSecuritySettings();
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
              _buildMenuItem(context, 'servers', Icons.dns, 'Free VPN Servers'),
              _buildMenuItem(context, 'config', Icons.settings, 'Configuration'),
              _buildMenuItem(context, 'security', Icons.security, 'Security Settings'),
              _buildMenuItem(context, 'status', Icons.analytics_outlined, 'Connection Status'),
              _buildMenuItem(context, 'privacy', Icons.privacy_tip_outlined, 'Privacy Info'),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
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
                  if (activeChain?.status == ChainStatus.connected) ...[
                    SizedBox(height: 24),
                    _buildConnectionInfo(activeChain),
                  ],
                  if (_securityAlerts.isNotEmpty) ...[
                    SizedBox(height: 24),
                    _buildSecurityAlerts(),
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
    final isConnected = activeChain?.status == ChainStatus.connected;
    final isConnecting = activeChain?.status == ChainStatus.connecting;
    
    // Determine colors based on state
    Color cardColor;
    Color iconColor;
    String statusText;
    String subText;

    if (isConnected) {
      cardColor = customColors.success;
      iconColor = customColors.vpnConnected;
      statusText = 'PROTECTED';
      
      // Enhanced status with connection info
      if (_connectionInfo != null) {
        subText = 'IP: ${_connectionInfo!.publicIp} • ${_connectionInfo!.country}';
      } else {
        subText = 'Traffic is encrypted & anonymous';
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
    final isConnected = activeChain?.status == ChainStatus.connected;
    final isConnecting = activeChain?.status == ChainStatus.connecting;
    final isDisconnecting = activeChain?.status == ChainStatus.disconnecting;
    final hasError = activeChain?.status == ChainStatus.error;
    
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
                  onTap: () => _handleConnectionToggle(),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),
        Text(
          isConnected 
            ? 'Anonymous Mode: ${activeChain?.mode.name.toUpperCase()}'
            : isConnecting
            ? 'Establishing Anonymous Connection...'
            : isDisconnecting
            ? 'Disconnecting...'
            : hasError
            ? 'Connection Error - Tap to Retry'
            : 'Tap to Connect Anonymously',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: hasError ? Colors.red : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasError && activeChain != null) ...[
          SizedBox(height: 8),
          Text(
            'Failed to establish ${activeChain.mode.name} connection',
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
        
        // Auto VPN Actions
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
        Container(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: connectionState == ServerConnectionState.connecting ? null : () {
              _handleAutoConnect();
            },
            icon: connectionState == ServerConnectionState.connecting 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.auto_awesome, size: 24),
            label: Text(
              connectionState == ServerConnectionState.connected 
                  ? 'Connected to ${activeConfig?.name ?? "Server"}'
                  : connectionState == ServerConnectionState.connecting 
                      ? 'Connecting...'
                      : 'Auto Connect to Best Server',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: connectionState == ServerConnectionState.connected
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
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
                    'Connection Analytics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Enhanced connection details with real data
              if (_connectionInfo != null) ...[
                _buildConnectionDetail('IP Address', _connectionInfo!.publicIp),
                _buildConnectionDetail('Country', _connectionInfo!.country),
                _buildConnectionDetail('ISP', _connectionInfo!.isp),
                _buildConnectionDetail('City', _connectionInfo!.city),
              ],
              
              _buildConnectionDetail('Mode', activeChain?.mode.toString().split('.').last.toUpperCase() ?? 'Unknown'),
              _buildConnectionDetail('Routing', '${activeChain?.proxyChain.length ?? 0} Relay Hops'),
              _buildConnectionDetail('Protocol', 'WireGuard + ChaCha20'),
              _buildConnectionDetail('Encryption', '256-bit AES'),
              
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Latency', _connectionInfo?.latency ?? '42ms', Icons.speed),
                  _buildStatCard('Data', _connectionInfo?.dataUsage ?? '0 MB', Icons.download),
                  _buildStatCard('Time', _formatConnectionTime(), Icons.timer),
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
          Icon(icon, color: customColors.vpnConnected, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
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

  Widget _buildSecurityAlerts() {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: theme.colorScheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Security Alerts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Show recent alerts
          ...(_securityAlerts.take(3).map((alert) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  _getAlertIcon(alert.type),
                  color: _getAlertColor(alert.type),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _showSecurityAlertDetails(alert),
                  child: Text('Details'),
                ),
              ],
            ),
          ))),
          
          if (_securityAlerts.length > 3)
            TextButton(
              onPressed: () => _showAllSecurityAlerts(),
              child: Text('View All (${_securityAlerts.length})'),
            ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(SecurityAlertType type) {
    switch (type) {
      case SecurityAlertType.info:
        return Icons.info_outline;
      case SecurityAlertType.warning:
        return Icons.warning_amber_outlined;
      case SecurityAlertType.critical:
        return Icons.error_outline;
    }
  }

  Color _getAlertColor(SecurityAlertType type) {
    switch (type) {
      case SecurityAlertType.info:
        return Colors.blue;
      case SecurityAlertType.warning:
        return Colors.orange;
      case SecurityAlertType.critical:
        return Colors.red;
    }
  }

  String _formatConnectionTime() {
    if (_connectionInfo?.connectionStartTime == null) return '00:00';
    
    final duration = DateTime.now().difference(_connectionInfo!.connectionStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  // Auto VPN handlers (enhanced with real VPN manager)
  Future<void> _handleAutoConnect() async {
    if (!_isAutoManagerInitialized || !_isVpnManagerInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VPN managers not ready'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      // Use auto manager to get best config, then connect with enhanced VPN manager
      final success = await _autoManager.oneClickConnect();
      
      if (success && _autoManager.currentConfig != null) {
        final config = _autoManager.currentConfig!;
        
        // Connect using enhanced VPN manager
        await _vpnManager.connectVpn(config);
        
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${config.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Auto connection failed');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
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

      if (warpConfig != null && _isVpnManagerInitialized) {
        // Connect using enhanced VPN manager  
        await _vpnManager.connectVpn(warpConfig);
        
        ref.read(activeVpnConfigProvider.notifier).state = warpConfig;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to Cloudflare WARP'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('WARP configuration failed');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WARP connection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
        }
      });
    }
  }

  Future<void> _handleStreamingConnect() async {
    if (!_isAutoManagerInitialized || !_isVpnManagerInitialized) return;

    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final config = await _autoManager.getStreamingOptimizedConfig();

      if (config != null) {
        // Connect using enhanced VPN manager
        await _vpnManager.connectVpn(config);
        
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to streaming server'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('No streaming servers available');
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streaming connection failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openServersList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VpnMainScreen()),
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => _SecuritySettingsDialog(securityManager: _securityManager),
    );
  }

  void _showSecurityAlertDetails(SecurityAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Security Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${alert.typeString}'),
            SizedBox(height: 8),
            Text('Title: ${alert.title}'),
            SizedBox(height: 8),
            Text('Message: ${alert.message}'),
            SizedBox(height: 8),
            Text('Time: ${alert.timestamp}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllSecurityAlerts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All Security Alerts'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _securityAlerts.length,
            itemBuilder: (context, index) {
              final alert = _securityAlerts[index];
              return ListTile(
                leading: Icon(_getAlertIcon(alert.type), color: _getAlertColor(alert.type)),
                title: Text(alert.title),
                subtitle: Text(alert.message),
                trailing: Text('${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}'),
                onTap: () => _showSecurityAlertDetails(alert),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
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
          '• Native VPN integration\n'
          '• Advanced security features\n'
          '• Kill switch protection\n'
          '• DNS leak shield\n'
          '• Anonymous proxy chains\n'
          '• Real-time security monitoring',
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
}

// Security settings dialog
class _SecuritySettingsDialog extends StatefulWidget {
  final SecurityManager securityManager;
  
  const _SecuritySettingsDialog({required this.securityManager});
  
  @override
  _SecuritySettingsDialogState createState() => _SecuritySettingsDialogState();
}

class _SecuritySettingsDialogState extends State<_SecuritySettingsDialog> {
  late SecurityStatus _status;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _status = widget.securityManager.getSecurityStatus();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Security Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text('Kill Switch'),
            subtitle: Text('Block traffic when VPN disconnects'),
            value: _status.killSwitchEnabled,
            onChanged: _isLoading ? null : (value) => _toggleKillSwitch(value),
          ),
          SwitchListTile(
            title: Text('DNS Leak Protection'),
            subtitle: Text('Route DNS through VPN tunnel'),
            value: _status.dnsLeakProtectionEnabled,
            onChanged: _isLoading ? null : (value) => _toggleDnsProtection(value),
          ),
          SwitchListTile(
            title: Text('IPv6 Blocking'),
            subtitle: Text('Block IPv6 to prevent leaks'),
            value: _status.ipv6BlockingEnabled,
            onChanged: _isLoading ? null : (value) => _toggleIpv6Blocking(value),
          ),
          SwitchListTile(
            title: Text('WebRTC Blocking'),
            subtitle: Text('Prevent WebRTC IP leaks'),
            value: _status.webRtcBlockingEnabled,
            onChanged: _isLoading ? null : (value) => _toggleWebRtcBlocking(value),
          ),
          
          SizedBox(height: 16),
          
          Text('Security Score: ${(_status.securityScore * 100).toInt()}%'),
          LinearProgressIndicator(value: _status.securityScore),
          
          SizedBox(height: 8),
          
          Text('Level: ${_status.securityLevel}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _runSecurityTest(),
          child: Text('Run Security Test'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
  
  Future<void> _toggleKillSwitch(bool value) async {
    setState(() => _isLoading = true);
    
    if (value) {
      await widget.securityManager.enableKillSwitch();
    } else {
      await widget.securityManager.disableKillSwitch();
    }
    
    setState(() {
      _status = widget.securityManager.getSecurityStatus();
      _isLoading = false;
    });
  }
  
  Future<void> _toggleDnsProtection(bool value) async {
    setState(() => _isLoading = true);
    
    if (value) {
      await widget.securityManager.enableDnsLeakProtection();
    }
    
    setState(() {
      _status = widget.securityManager.getSecurityStatus();
      _isLoading = false;
    });
  }
  
  Future<void> _toggleIpv6Blocking(bool value) async {
    setState(() => _isLoading = true);
    
    if (value) {
      await widget.securityManager.enableIpv6Blocking();
    }
    
    setState(() {
      _status = widget.securityManager.getSecurityStatus();
      _isLoading = false;
    });
  }
  
  Future<void> _toggleWebRtcBlocking(bool value) async {
    setState(() => _isLoading = true);
    
    if (value) {
      await widget.securityManager.enableWebRtcBlocking();
    }
    
    setState(() {
      _status = widget.securityManager.getSecurityStatus();
      _isLoading = false;
    });
  }
  
  Future<void> _runSecurityTest() async {
    setState(() => _isLoading = true);
    
    final result = await widget.securityManager.runSecurityTest();
    
    setState(() => _isLoading = false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Security Test Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overall: ${result.overallPassed ? "PASSED" : "FAILED"}'),
            Text('Tests: ${result.passedTests}/${result.tests.length} passed'),
            Text('Success Rate: ${(result.successRate * 100).toInt()}%'),
            
            SizedBox(height: 16),
            
            Text('Test Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...result.tests.map((test) => Padding(
              padding: EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  Icon(
                    test.passed ? Icons.check_circle : Icons.error,
                    color: test.passed ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text(test.name)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Quick action button widget
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

// World map painter (same as before)
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