import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../business_logic/providers/built_in_server_providers.dart';
import '../../data/models/vpn_config.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  // User-imported configs stored locally in this screen
  final List<VpnConfig> _importedConfigs = [];
  bool _autoConnect = false;
  bool _killSwitch = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme.customColors;
    final activeConfig = ref.watch(activeVpnConfigProvider);
    final warpConfigAsync = ref.watch(warpConfigProvider);

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
          'VPN Configurations',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded),
            onPressed: () => _showAddConfigDialog(theme),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, kToolbarHeight + MediaQuery.of(context).padding.top + 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(theme, customColors),
            SizedBox(height: 24),

            // Active Config
            if (activeConfig != null) ...[
              _buildSectionHeader(theme, 'Active Configuration', Icons.vpn_key_rounded),
              SizedBox(height: 12),
              _buildActiveConfigCard(theme, customColors, activeConfig),
              SizedBox(height: 24),
            ],

            // Built-in WARP Config
            _buildSectionHeader(theme, 'Cloudflare WARP', Icons.cloud_rounded),
            SizedBox(height: 12),
            _buildWarpCard(theme, customColors, warpConfigAsync, activeConfig),
            SizedBox(height: 24),

            // Imported Configs
            _buildSectionHeader(theme, 'Imported Configurations', Icons.folder_rounded),
            SizedBox(height: 12),
            if (_importedConfigs.isEmpty)
              _buildEmptyState(theme)
            else
              ..._importedConfigs.map((config) =>
                  _buildConfigCard(theme, customColors, config, activeConfig)),
            SizedBox(height: 16),
            _buildAddConfigCard(theme),
            SizedBox(height: 24),

            // Settings
            _buildSettingsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, AppCustomColors customColors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.12),
                theme.colorScheme.primary.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VPN Configurations',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Import WireGuard configs or use built-in Cloudflare WARP',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActiveConfigCard(ThemeData theme, AppCustomColors customColors, VpnConfig config) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: customColors.vpnConnected.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: customColors.vpnConnected.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
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
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(config.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: customColors.vpnConnected.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: customColors.vpnConnected, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _buildConfigDetail(theme, 'Protocol', config.protocol),
                  SizedBox(width: 24),
                  _buildConfigDetail(theme, 'Port', '${config.port}'),
                  SizedBox(width: 24),
                  _buildConfigDetail(
                      theme, 'DNS', config.dnsServers.isNotEmpty ? config.dnsServers.first : 'N/A'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarpCard(ThemeData theme, AppCustomColors customColors,
      AsyncValue<VpnConfig?> warpAsync, VpnConfig? activeConfig) {
    final isWarpActive = activeConfig?.name.contains('WARP') == true ||
        activeConfig?.name.contains('Cloudflare') == true;

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
              color: isWarpActive
                  ? customColors.vpnConnected.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cloud_rounded, color: Colors.orange, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloudflare WARP',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      warpAsync.when(
                        data: (config) =>
                            config != null ? 'Auto-generated • Unlimited' : 'Generation failed',
                        loading: () => 'Generating config...',
                        error: (_, __) => 'Error generating config',
                      ),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isWarpActive)
                Icon(Icons.check_circle_rounded, color: customColors.vpnConnected, size: 24)
              else
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard(
      ThemeData theme, AppCustomColors customColors, VpnConfig config, VpnConfig? activeConfig) {
    final isActive = activeConfig?.id == config.id;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? customColors.vpnConnected.withValues(alpha: 0.3)
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? customColors.vpnConnected : customColors.vpnDisconnected,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: customColors.vpnConnected.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1),
                              ]
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(config.name,
                          style:
                              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: theme.colorScheme.error, size: 20),
                      onPressed: () => _showDeleteConfirmation(theme, config),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildConfigDetail(theme, 'Protocol', config.protocol),
                    SizedBox(width: 20),
                    _buildConfigDetail(theme, 'Port', '${config.port}'),
                    SizedBox(width: 20),
                    _buildConfigDetail(theme, 'Server', config.serverAddress),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigDetail(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(height: 12),
          Text('No imported configurations',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          SizedBox(height: 4),
          Text('Import a WireGuard .conf file to get started',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildAddConfigCard(ThemeData theme) {
    return InkWell(
      onTap: () => _showAddConfigDialog(theme),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Configuration',
                          style:
                              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Import a WireGuard .conf file',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _buildSettingItem(
                theme,
                'Auto-Connect',
                'Automatically connect on app start',
                _autoConnect,
                (value) => setState(() => _autoConnect = value),
              ),
              _buildSettingItem(
                theme,
                'Kill Switch',
                'Block internet when VPN disconnects',
                _killSwitch,
                (value) => setState(() => _killSwitch = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(
      ThemeData theme, String title, String description, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ─── Dialogs & Actions ──────────────────────────────────────────

  void _showAddConfigDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Import Configuration', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.file_upload_rounded, color: theme.colorScheme.primary),
              title: Text('Import .conf File', style: theme.textTheme.bodyLarge),
              subtitle: Text('WireGuard configuration file',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                _importConfigFile();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _importConfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['conf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      try {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Parse WireGuard config
        final config = VpnConfig.fromWireGuardConfig(content);

        setState(() {
          _importedConfigs.add(config);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported: ${config.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to parse config: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDeleteConfirmation(ThemeData theme, VpnConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Configuration', style: theme.textTheme.titleLarge),
        content: Text(
          'Delete "${config.name}"? This cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _importedConfigs.removeWhere((c) => c.id == config.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Configuration deleted'), backgroundColor: Colors.orange),
              );
            },
            child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }
}