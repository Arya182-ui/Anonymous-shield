import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:privacy_vpn_controller/data/models/anonymous_chain.dart';
import 'package:privacy_vpn_controller/business_logic/providers/anonymous_providers.dart';
import 'package:privacy_vpn_controller/business_logic/providers/connection_provider.dart';
import 'package:privacy_vpn_controller/presentation/widgets/connection_button.dart';
import 'package:privacy_vpn_controller/presentation/screens/mode_info_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/status_screen.dart';
import 'package:privacy_vpn_controller/presentation/screens/config_screen.dart';
import 'package:privacy_vpn_controller/data/models/built_in_server.dart';
import 'package:privacy_vpn_controller/data/models/proxy_config.dart';

class ControlScreen extends ConsumerStatefulWidget {
  @override
  _ControlScreenState createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChain = ref.watch(activeAnonymousChainProvider);
    
    return Scaffold(
      backgroundColor: Color(0xFF0D0D1F),
      appBar: AppBar(
        backgroundColor: Color(0xFF0D0D1F),
        elevation: 0,
        title: Text(
          'Privacy VPN Controller', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            color: Color(0xFF1D1E33),
            icon: Icon(Icons.more_vert, color: Colors.white),
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
              PopupMenuItem(
                value: 'modes',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('VPN Modes', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'config',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Configuration', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Connection Status', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Privacy Info', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(activeChain),
              SizedBox(height: 24),
              _buildConnectSection(activeChain),
              SizedBox(height: 32),
              _buildQuickActions(),
              if (activeChain?.status == ChainStatus.connected) ...[
                SizedBox(height: 24),
                _buildConnectionInfo(activeChain),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(AnonymousChain? activeChain) {
    final isConnected = activeChain?.status == ChainStatus.connected;
    final isConnecting = activeChain?.status == ChainStatus.connecting;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected 
            ? [Color(0xFF1B5E20), Color(0xFF2E7D32)]
            : isConnecting
            ? [Color(0xFF1565C0), Color(0xFF1976D2)]
            : [Color(0xFF1D1E33), Color(0xFF2C2D54)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected 
            ? Colors.green.withOpacity(0.3)
            : isConnecting
            ? Colors.blue.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected 
                ? Icons.shield 
                : isConnecting 
                ? Icons.sync 
                : Icons.shield_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected 
                    ? 'Protected' 
                    : isConnecting 
                    ? 'Connecting...' 
                    : 'Not Connected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isConnected
                    ? 'Your traffic is secured and anonymous'
                    : isConnecting
                    ? 'Establishing secure connection'
                    : 'Choose a mode and connect to get protected',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                if (activeChain?.mode != null && isConnected)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${activeChain!.mode.toString().split('.').last.toUpperCase()} MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isConnecting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectSection(AnonymousChain? activeChain) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: activeChain?.status == ChainStatus.connecting 
                ? _pulseAnimation.value : 1.0,
            child: ConnectionButton(
              isConnected: activeChain?.status == ChainStatus.connected,
              isConnecting: activeChain?.status == ChainStatus.connecting,
              onTap: () => _handleConnectionToggle(),
            ),
          );
        },
      ),
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Connection Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildConnectionDetail('Mode', activeChain?.mode.toString().split('.').last.toUpperCase() ?? 'Unknown'),
          _buildConnectionDetail('Proxies', '${activeChain?.proxyChain.length ?? 0} hops'),
          _buildConnectionDetail('Encryption', 'WireGuard + ChaCha20'),
          _buildConnectionDetail('Status', 'Fully Protected'),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Latency', '--ms'),
              _buildStatCard('Data', '--GB'),
              _buildStatCard('Time', '--min'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
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
    
    if (activeChain?.status == ChainStatus.connected) {
      try {
        await ref.read(connectionProvider.notifier).disconnect();
        print('Disconnected from VPN');
      } catch (e) {
        print('Failed to disconnect: $e');
      }
    } else {
      try {
        final proxyChain = _getProxyChainForMode(_selectedMode);
        
        final chain = AnonymousChain(
          id: 'chain_${DateTime.now().millisecondsSinceEpoch}',
          name: '${_selectedMode.toString().split('.').last} Chain',
          mode: _selectedMode,
          proxyChain: proxyChain,
        );
        
        ref.read(activeAnonymousChainProvider.notifier).setChain(chain);
        print('Connected to VPN with $_selectedMode mode');
      } catch (e) {
        print('Failed to connect: $e');
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isSelected ? (color ?? Colors.white).withOpacity(0.15) : Color(0xFF1D1E33).withOpacity(0.6)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? (color ?? Colors.white).withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? (color ?? Colors.white) : (color ?? Colors.white70),
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? (color ?? Colors.white) : (color ?? Colors.white70),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}