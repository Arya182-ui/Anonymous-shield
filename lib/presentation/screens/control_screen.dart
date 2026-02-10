import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../business_logic/providers/anonymous_providers.dart';
import '../../business_logic/services/auto_connect_service.dart';
import '../../business_logic/services/anonymous_chain_service.dart';
import '../../data/models/anonymous_chain.dart';
import '../widgets/connection_button.dart';
import '../widgets/anonymous_mode_selector.dart';
import 'mode_info_screen.dart';
import 'server_list_screen.dart';
import 'status_screen.dart';
import 'config_screen.dart';

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen>
    with SingleTickerProviderStateMixin {
  final _autoConnectService = AutoConnectService();
  final _anonymousChainService = AnonymousChainService();
  final _logger = Logger();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Track selected mode when not connected
  AnonymousMode? _selectedMode;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
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
    
    // Start pulse animation when connecting
    if (activeChain?.status == ChainStatus.connecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Color(0xFF1D1E33),
        elevation: 0,
        title: Text(
          'Privacy VPN Controller',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ModeInfoScreen()),
            ),
            tooltip: 'Mode Guide',
          ),
          IconButton(
            icon: Icon(Icons.dns, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ServerListScreen()),
            ),
            tooltip: 'Servers',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white70),
            color: Color(0xFF1D1E33),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'config',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Configurations', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Privacy Info', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.signal_cellular_alt, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Connection Status', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'config') {
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
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Status Card
              _buildStatusCard(activeChain),
              
              SizedBox(height: 20),
              
              // Mode Selector - only show when not connected/connecting
              if (activeChain?.status != ChainStatus.connected && activeChain?.status != ChainStatus.connecting) ...[
                Row(
                  children: [
                    Icon(Icons.tune, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Select Protection Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ModeInfoScreen()),
                      ),
                      icon: Icon(Icons.help_outline, size: 16, color: Colors.blue),
                      label: Text(
                        'Learn More',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                AnonymousModeSelector(
                  selectedMode: _selectedMode,
                  onModeSelected: (mode) {
                    setState(() {
                      _selectedMode = mode;
                    });
                  },
                ),
                SizedBox(height: 20),
              ],
              
              // Main Connect Button
              _buildConnectSection(activeChain),
              
              SizedBox(height: 30),
              
              // Anonymous Quick Actions - only show when not connected
              if (activeChain?.status != ChainStatus.connected && activeChain?.status != ChainStatus.connecting)
                _buildQuickActions(),

              // Connection Info when connected
              if (activeChain?.status == ChainStatus.connected)
                _buildConnectionInfo(activeChain),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnonymousActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          icon: Icons.flash_on,
          label: 'Ghost Mode',
          color: Colors.purple,
          isSelected: _selectedMode == AnonymousMode.ghost,
          onTap: () {
            setState(() {
              _selectedMode = AnonymousMode.ghost;
            });
          },
        ),
        _QuickActionButton(
          icon: Icons.speed,
          label: 'Turbo Mode', 
          color: Colors.blue,
          isSelected: _selectedMode == AnonymousMode.turbo,
          onTap: () {
            setState(() {
              _selectedMode = AnonymousMode.turbo;
            });
          },
        ),
        _QuickActionButton(
          icon: Icons.shield,
          label: 'Stealth Mode',
          color: Colors.green,
          isSelected: _selectedMode == AnonymousMode.stealth,
          onTap: () {
            setState(() {
              _selectedMode = AnonymousMode.stealth;
            });
          },
        ),
      ],
    );
  }

  Future<void> _handleConnectionToggle() async {
    final activeChain = ref.read(activeAnonymousChainProvider);
    
    if (activeChain?.status == ChainStatus.connected) {
      // Disconnect from anonymous chain
      await _anonymousChainService.disconnect(ref);
      ref.read(activeAnonymousChainProvider.notifier).clearChain();
      _autoConnectService.disableAutoReconnect();
    } else {
      // Connect using selected mode or default to Ghost Mode
      final modeToConnect = _selectedMode ?? AnonymousMode.ghost;
      await _connectAnonymous(modeToConnect);
    }
  }

  Future<void> _connectAnonymous(AnonymousMode mode) async {
    try {
      // Prevent multiple connections
      final activeChain = ref.read(activeAnonymousChainProvider);
      if (activeChain?.status == ChainStatus.connecting) {
        _logger.w('Connection already in progress');
        return;
      }
      
      // Update UI to show connecting state  
      ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.connecting);
      
      // Connect to anonymous chain
      final success = await _anonymousChainService.quickConnectAnonymous(mode, ref);
      
      if (success) {
        // Update active chain
        final chainService = ref.read(anonymousChainServiceProvider);
        if (chainService.currentChain != null) {
          ref.read(activeAnonymousChainProvider.notifier).setChain(chainService.currentChain!);
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${mode.name.toUpperCase()} mode'),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _showAnonymousConnectError(mode);
      }
    } catch (e) {
      _showAnonymousConnectError(mode);
    }
  }

  void _showAnonymousConnectError(AnonymousMode mode) {
    ref.read(activeAnonymousChainProvider.notifier).updateChainStatus(ChainStatus.error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to connect to ${mode.name.toUpperCase()} mode'),
        backgroundColor: Colors.red[700],
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _connectAnonymous(mode),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.autorenew, color: Colors.blue),
              title: Text('Auto-reconnect', style: TextStyle(color: Colors.white)),
              subtitle: Text('Automatically reconnect if connection drops', 
                  style: TextStyle(color: Colors.white70)),
              trailing: Switch(
                value: true, // TODO: Implement settings state
                onChanged: (value) {},
              ),
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.green),
              title: Text('Location Services', style: TextStyle(color: Colors.white)),
              subtitle: Text('Allow location access for better server selection',
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                // TODO: Implement location permission request
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.info, color: Colors.orange),
              title: Text('About', style: TextStyle(color: Colors.white)),
              onTap: () => _showAboutDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    Navigator.pop(context);
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
                if (activeChain?.currentMode != null && isConnected)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${activeChain!.currentMode.toString().split('.').last.toUpperCase()} MODE',
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
              isConnected: activeChain?.isConnected ?? false,
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
          _buildConnectionDetail('Mode', activeChain?.currentMode.toString().split('.').last.toUpperCase() ?? 'Unknown'),
          _buildConnectionDetail('Servers', '${activeChain?.servers.length ?? 0} hops'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(isSelected ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (color ?? Colors.white).withOpacity(isSelected ? 0.8 : 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                if (activeChain?.currentMode != null && isConnected)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${activeChain!.currentMode.toString().split('.').last.toUpperCase()} MODE',
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
              isConnected: activeChain?.isConnected ?? false,
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
          _buildConnectionDetail('Mode', activeChain?.currentMode.toString().split('.').last.toUpperCase() ?? 'Unknown'),
          _buildConnectionDetail('Servers', '${activeChain?.servers.length ?? 0} hops'),
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

