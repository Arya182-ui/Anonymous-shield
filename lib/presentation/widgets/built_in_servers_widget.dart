import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/built_in_server.dart';
import '../../business_logic/providers/built_in_server_providers.dart';

/// Built-in servers selection widget
class BuiltInServersWidget extends ConsumerStatefulWidget {
  final Function(BuiltInServer)? onServerSelected;
  final bool showSearchBar;
  final bool showRecommendedOnly;

  const BuiltInServersWidget({
    super.key,
    this.onServerSelected,
    this.showSearchBar = true,
    this.showRecommendedOnly = false,
  });

  @override
  ConsumerState<BuiltInServersWidget> createState() => _BuiltInServersWidgetState();
}

class _BuiltInServersWidgetState extends ConsumerState<BuiltInServersWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(builtInServersProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final serversAsync = widget.showRecommendedOnly
        ? ref.watch(recommendedServersProvider)
        : ref.watch(filteredServersProvider);
    final selectedServer = ref.watch(selectedServerProvider);
    final connectionState = ref.watch(serverConnectionStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSearchBar) _buildSearchBar(),
        const SizedBox(height: 16),
        _buildQuickActions(),
        const SizedBox(height: 16),
        Expanded(
          child: serversAsync.when(
            data: (servers) => _buildServersList(servers, selectedServer, connectionState),
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading free VPN servers...'),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to load servers'),
                  SizedBox(height: 8),
                  Text(error.toString(), style: TextStyle(fontSize: 12)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(builtInServersProvider),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search servers by name or country...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      onChanged: (value) {
        ref.read(serverSearchProvider.notifier).state = value;
      },
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(
          avatar: Icon(Icons.flash_on, size: 18),
          label: Text('Auto Select Best'),
          onPressed: _onAutoSelectBest,
        ),
        ActionChip(
          avatar: Icon(Icons.cloud, size: 18),
          label: Text('Cloudflare WARP'),
          onPressed: _onGenerateWarp,
        ),
        ActionChip(
          avatar: Icon(Icons.shuffle, size: 18),
          label: Text('Random Server'),
          onPressed: _onSelectRandom,
        ),
      ],
    );
  }

  Widget _buildServersList(List<BuiltInServer> servers, BuiltInServer? selectedServer, ServerConnectionState connectionState) {
    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No servers found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
            Text('Try different search terms'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isSelected = selectedServer?.id == server.id;
        final isConnected = isSelected && connectionState == ServerConnectionState.connected;

        return Card(
          elevation: isSelected ? 4 : 1,
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            leading: _buildServerFlag(server),
            title: Text(
              server.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${server.city}, ${server.country}'),
                Row(
                  children: [
                    _buildLoadIndicator(server.loadPercentage),
                    SizedBox(width: 8),
                    Text('${server.maxSpeedMbps} Mbps'),
                    if (server.isRecommended) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: isConnected
                ? Icon(Icons.check_circle, color: Colors.green)
                : connectionState == ServerConnectionState.connecting && isSelected
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.chevron_right),
            selected: isSelected,
            onTap: () => _onServerTap(server),
          ),
        );
      },
    );
  }

  Widget _buildServerFlag(BuiltInServer server) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: Text(
          server.flagEmoji,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildLoadIndicator(int loadPercentage) {
    Color loadColor;
    if (loadPercentage < 30) {
      loadColor = Colors.green;
    } else if (loadPercentage < 70) {
      loadColor = Colors.orange;
    } else {
      loadColor = Colors.red;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, color: loadColor, size: 16),
        SizedBox(width: 2),
        Text(
          '$loadPercentage%',
          style: TextStyle(color: loadColor, fontSize: 12),
        ),
      ],
    );
  }

  void _onServerTap(BuiltInServer server) {
    ref.read(selectedServerProvider.notifier).state = server;
    widget.onServerSelected?.call(server);
    _showServerDetails(server);
  }

  void _onAutoSelectBest() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final autoSelectedConfig = await ref.read(autoSelectedServerProvider.future);

      if (autoSelectedConfig != null) {
        ref.read(activeVpnConfigProvider.notifier).state = autoSelectedConfig;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-selected: ${autoSelectedConfig.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to auto-select server'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
    }
  }

  void _onGenerateWarp() async {
    try {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final warpConfig = await ref.read(warpConfigProvider.future);

      if (warpConfig != null) {
        ref.read(activeVpnConfigProvider.notifier).state = warpConfig;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated Cloudflare WARP config'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate WARP config'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.disconnected;
    }
  }

  void _onSelectRandom() {
    final serversAsync = ref.read(builtInServersProvider);
    serversAsync.whenData((servers) {
      if (servers.isNotEmpty) {
        final randomServer = servers[DateTime.now().millisecond % servers.length];
        _onServerTap(randomServer);
      }
    });
  }

  void _showServerDetails(BuiltInServer server) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ServerDetailsBottomSheet(server: server),
    );
  }
}

/// Server details bottom sheet
class ServerDetailsBottomSheet extends ConsumerWidget {
  final BuiltInServer server;

  const ServerDetailsBottomSheet({super.key, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                server.flagEmoji,
                style: TextStyle(fontSize: 32),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${server.city}, ${server.country}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildDetailRow('Server Address', server.serverAddress),
          _buildDetailRow('Port', server.port.toString()),
          _buildDetailRow('Max Speed', '${server.maxSpeedMbps} Mbps'),
          _buildDetailRow('Current Load', '${server.loadPercentage}%'),
          _buildDetailRow('Free Tier', server.isFree ? 'Yes' : 'No'),
          if (server.isRecommended)
            _buildDetailRow('Status', 'Recommended'),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _connectToServer(context, ref),
                  icon: Icon(Icons.play_arrow),
                  label: Text('Connect'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                  label: Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _connectToServer(BuildContext context, WidgetRef ref) async {
    try {
      Navigator.pop(context);

      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connecting;

      final service = ref.read(builtInServerServiceProvider);
      final config = await service.generateConfigForServer(server);

      if (config != null) {
        ref.read(activeVpnConfigProvider.notifier).state = config;
        ref.read(selectedServerProvider.notifier).state = server;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${server.name}'),
            backgroundColor: Colors.green,
          ),
        );

        ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.connected;
      } else {
        throw Exception('Failed to generate configuration');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      ref.read(serverConnectionStateProvider.notifier).state = ServerConnectionState.error;
    }
  }
}
