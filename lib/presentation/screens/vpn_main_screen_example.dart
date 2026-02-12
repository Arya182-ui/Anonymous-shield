import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_logic/managers/auto_vpn_config_manager.dart';
import '../../business_logic/providers/built_in_server_providers.dart';
import '../../presentation/widgets/built_in_servers_widget.dart';
import '../../data/models/vpn_config.dart';
/// Example VPN main screen with built-in servers integration
/// यह example है कि कैसे आप अपने main VPN screen में built-in servers को integrate करें
class VpnMainScreen extends ConsumerStatefulWidget {
  const VpnMainScreen({super.key});
  @override
  ConsumerState<VpnMainScreen> createState() => _VpnMainScreenState();
}
class _VpnMainScreenState extends ConsumerState<VpnMainScreen> {
  final AutoVpnConfigManager _autoManager = AutoVpnConfigManager();
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  Future<void> _initializeServices() async {
    try {
      await _autoManager.initialize();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final activeConfig = ref.watch(activeVpnConfigProvider);
    final connectionState = ref.watch(serverConnectionStateProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Free VPN Servers'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.flash_on), text: 'Quick Connect'),
              Tab(icon: Icon(Icons.list), text: 'All Servers'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildQuickConnectTab(activeConfig, connectionState),
            _buildServersListTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }
  Widget _buildQuickConnectTab(VpnConfig? activeConfig, ServerConnectionState connectionState) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildConnectionStatus(activeConfig, connectionState),
                  SizedBox(height: 20),
                  _buildMainConnectButton(connectionState),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Auto Connect',
                  'Best server automatically',
                  Icons.auto_awesome,
                  Colors.blue,
                  () => _handleAutoConnect(),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Cloudflare WARP',
                  'Unlimited & fast',
                  Icons.cloud,
                  Colors.orange,
                  () => _handleWarpConnect(),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Streaming',
                  'Optimized for videos',
                  Icons.play_circle_filled,
                  Colors.red,
                  () => _handleStreamingConnect(),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Random Server',
                  'Try different location',
                  Icons.shuffle,
                  Colors.green,
                  () => _handleRandomConnect(),
                ),
              ),
            ],
          ),

          Spacer(),

          // Statistics
          _buildStatistics(),
        ],
      ),
    );
  }
  Widget _buildServersListTab() {
    return BuiltInServersWidget(
      onServerSelected: (server) async {
        await _connectToSpecificServer(server);
      },
      showSearchBar: true,
      showRecommendedOnly: false,
    );
  }
  Widget _buildSettingsTab() {
    final autoConnect = ref.watch(autoConnectEnabledProvider);
    final rotationSettings = ref.watch(serverRotationProvider);

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Auto Configuration Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),

        SwitchListTile(
          title: Text('Auto Connect on App Start'),
          subtitle: Text('Automatically connect to best server'),
          value: autoConnect,
          onChanged: (value) {
            ref.read(autoConnectEnabledProvider.notifier).state = value;
          },
        ),

        SwitchListTile(
          title: Text('Server Rotation'),
          subtitle: Text('Automatically rotate servers'),
          value: rotationSettings.enabled,
          onChanged: (value) {
            ref.read(serverRotationProvider.notifier).state =
                rotationSettings.copyWith(enabled: value);
          },
        ),

        if (rotationSettings.enabled)
          ListTile(
            title: Text('Rotation Interval'),
            subtitle: Slider(
              value: rotationSettings.intervalMinutes.toDouble(),
              min: 10,
              max: 120,
              divisions: 11,
              label: '${rotationSettings.intervalMinutes} minutes',
              onChanged: (value) {
                ref.read(serverRotationProvider.notifier).state =
                    rotationSettings.copyWith(intervalMinutes: value.toInt());
              },
            ),
          ),

        Divider(),

        Text(
          'Free Provider Preferences',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),

        ...FreeVpnProviderType.values.where((type) => type != FreeVpnProviderType.all).map(
          (providerType) => RadioListTile<FreeVpnProviderType>(
            title: Text(providerType.displayName),
            subtitle: Text(providerType.description),
            value: providerType,
            groupValue: ref.watch(selectedFreeProviderProvider),
            onChanged: (value) {
              if (value != null) {
                ref.read(selectedFreeProviderProvider.notifier).state = value;
              }
            },
          ),
        ),

        Divider(),

        ListTile(
          title: Text('Refresh Configurations'),
          subtitle: Text('Update server list and generate new configs'),
          leading: Icon(Icons.refresh),
          onTap: () => _refreshConfigurations(),
        ),
      ],
    );
  }
  Widget _buildConnectionStatus(VpnConfig? activeConfig, ServerConnectionState connectionState) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (connectionState) {
      case ServerConnectionState.connected:
        statusText = 'Connected to ${activeConfig?.name ?? "Server"}';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ServerConnectionState.connecting:
        statusText = 'Connecting...';
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case ServerConnectionState.disconnecting:
        statusText = 'Disconnecting...';
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case ServerConnectionState.error:
        statusText = 'Connection Error';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusText = 'Not Connected';
        statusColor = Colors.grey;
        statusIcon = Icons.vpn_lock;
    }
    return Column(
      children: [
        Icon(statusIcon, size: 48, color: statusColor),
        SizedBox(height: 12),
        Text(
          statusText,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (activeConfig != null && connectionState == ServerConnectionState.connected)
          Text(
            activeConfig.serverAddress,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }
  Widget _buildMainConnectButton(ServerConnectionState connectionState) {
    final isConnected = connectionState == ServerConnectionState.connected;
    final isConnecting = connectionState == ServerConnectionState.connecting ||
                        connectionState == ServerConnectionState.disconnecting;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: isConnecting ? null : () {
          if (isConnected) {
            _handleDisconnect();
          } else {
            _handleAutoConnect();
          }
        },
        child: isConnecting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Text(
                isConnected ? 'DISCONNECT' : 'CONNECT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildStatistics() {
    final stats = _autoManager.getServerStats();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Servers:'),
                Text('${stats['total_servers'] ?? 0}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Countries:'),
                Text('${stats['countries'] ?? 0}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Config:'),
                Text('${stats['current_config'] ?? "None"}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // Action handlers
  Future<void> _handleAutoConnect() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final success = await _autoManager.oneClickConnect();

      if (success && _autoManager.currentConfig != null) {
        ref.read(activeVpnConfigProvider.notifier).state = _autoManager.currentConfig;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${_autoManager.currentConfig!.name}'),
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
    }
  }
  Future<void> _handleWarpConnect() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final warpConfig = await ref.read(warpConfigProvider.future);

      if (warpConfig != null) {
        ref.read(activeVpnConfigProvider.notifier).state = warpConfig;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to Cloudflare WARP'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WARP connection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _handleStreamingConnect() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final config = await _autoManager.getStreamingOptimizedConfig();

      if (config != null) {
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to streaming server'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
    }
  }
  Future<void> _handleRandomConnect() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final config = await _autoManager.rotateToNextServer();

      if (config != null) {
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${config.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
    }
  }
  void _handleDisconnect() {
    ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
    ref.read(activeVpnConfigProvider.notifier).state = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Disconnected'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  Future<void> _connectToSpecificServer(server) async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final serverService = ref.read(builtInServerServiceProvider);
      final config = await serverService.generateConfigForServer(server);

      if (config != null) {
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(selectedServerProvider.notifier).state = server;
        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${server.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _refreshConfigurations() async {
    try {
      await _autoManager.refreshConfigurations();
      ref.invalidate(builtInServersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configurations refreshed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}