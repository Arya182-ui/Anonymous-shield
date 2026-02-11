import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'package:privacy_vpn_controller/data/models/anonymous_chain.dart';
import 'package:privacy_vpn_controller/business_logic/providers/anonymous_providers.dart';
import 'package:privacy_vpn_controller/business_logic/providers/connection_provider.dart';
import 'package:privacy_vpn_controller/presentation/widgets/connection_button.dart';
import 'package:privacy_vpn_controller/presentation/screens/mode_info_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/status_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/config_screen.dart';
import 'package:privacy_vpn_controller/data/models/built_in_server.dart';
import 'package:privacy_vpn_controller/data/models/proxy_config.dart';
import 'package:privacy_vpn_controller/data/models/connection_status.dart';
import 'package:privacy_vpn_controller/business_logic/services/anonymous_chain_service.dart';

class ControlScreen extends ConsumerStatefulWidget {
  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _mapController; // Added for map animation
  late Animation<double> _pulseAnimation;
  AnonymousMode _selectedMode = AnonymousMode.turbo;

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
    final vpnStatusAsync = ref.watch(vpnStatusProvider);
    final proxyStatusAsync = ref.watch(proxyStatusProvider);
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
                  if (activeChain?.status == ChainStatus.connected) ...[
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
    final isConnected = activeChain?.status == ChainStatus.connected;
    final isConnecting = activeChain?.status == ChainStatus.connecting;
    
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
        _buildAnonymousActions(),
      ],
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
              _buildConnectionDetail('Mode', activeChain?.mode.toString().split('.').last.toUpperCase() ?? 'Unknown'),
              _buildConnectionDetail('Routing', '${activeChain?.proxyChain.length ?? 0} Relay Hops'),
              _buildConnectionDetail('Protocol', 'WireGuard + ChaCha20'),
              _buildConnectionDetail('Encryption', '256-bit AES'),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Latency', '42ms', Icons.speed),
                  _buildStatCard('Data', '1.2GB', Icons.download),
                  _buildStatCard('Time', '12:45', Icons.timer),
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

  void _handleConnectionToggle() async {
    final activeChain = ref.read(activeAnonymousChainProvider);
    final chainService = ref.read(anonymousChainServiceProvider);
    
    if (activeChain?.status == ChainStatus.connected) {
      try {
        // Update UI to show disconnecting
        ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.disconnecting);
        
        // Disconnect through the service
        await chainService.disconnect(ref);
        
        // Clear the active chain
        ref.read(activeAnonymousChainProvider.notifier).clearChain();
        
        print('Disconnected from VPN');
      } catch (e) {
        print('Failed to disconnect: $e');
        // Revert status on error
        ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.connected);
      }
    } else {
      try {
        // Use predefined chain if available, otherwise create custom
        final predefinedChains = ref.read(predefinedChainsProvider);
        AnonymousChain chain;
        
        if (predefinedChains.containsKey(_selectedMode)) {
          chain = predefinedChains[_selectedMode]!;
        } else {
          final proxyChain = _getProxyChainForMode(_selectedMode);
          chain = AnonymousChain(
            id: 'chain_${DateTime.now().millisecondsSinceEpoch}',
            name: '${_selectedMode.toString().split('.').last} Chain',
            mode: _selectedMode,
            proxyChain: proxyChain,
          );
        }
        
        // Set connecting status in UI
        ref.read(activeAnonymousChainProvider.notifier).setChain(
          chain.copyWith(status: ChainStatus.connecting)
        );
        
        // Actually connect through the service
        final success = await chainService.connectToChain(chain, ref);
        
        if (success) {
          print('Connected to VPN with $_selectedMode mode');
          // Update provider with connected chain
          ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.connected);
        } else {
          print('Failed to establish connection');
          // Update status to error
          ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.error);
        }
      } catch (e) {
        print('Failed to connect: $e');
        ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.error);
      }
    }
  }

  List<ProxyConfig> _getProxyChainForMode(AnonymousMode mode) {
    switch (mode) {
      case AnonymousMode.turbo:
        return [
          ProxyConfig(
            id: 'turbo_proxy',
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
          '• Free servers included',
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