import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:logger/logger.dart';
import '../../data/services/free_vpn_provider.dart';
import '../../data/repositories/built_in_servers_repository.dart';
import '../../data/models/vpn_config.dart';

class FreeVpnConfigScreen extends ConsumerStatefulWidget {
  const FreeVpnConfigScreen({super.key});

  @override
  ConsumerState<FreeVpnConfigScreen> createState() => _FreeVpnConfigScreenState();
}

class _FreeVpnConfigScreenState extends ConsumerState<FreeVpnConfigScreen> {
  final Logger _logger = Logger();
  final FreeVpnProvider _freeVpnProvider = FreeVpnProvider();
  final BuiltInServersRepository _serversRepo = BuiltInServersRepository();
  
  bool _isLoading = false;
  List<VpnConfig> _availableConfigs = [];

  @override
  void initState() {
    super.initState();
    _loadFreeConfigs();
  }

  Future<void> _loadFreeConfigs() async {
    setState(() => _isLoading = true);
    
    try {
      final configs = await _serversRepo.getRealVpnConfigurations();
      setState(() {
        _availableConfigs = configs;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Failed to load free configs', error: e);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configurations: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Free VPN Configurations'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeaderCard(theme),
                  SizedBox(height: 20),
                  
                  // Quick Setup Options  
                  _buildQuickSetupSection(theme),
                  SizedBox(height: 20),
                  
                  // Manual Import Options
                  _buildManualImportSection(theme),
                  SizedBox(height: 20),
                  
                  // Available Configurations
                  _buildAvailableConfigsSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key, color: theme.colorScheme.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Free VPN Setup',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Get free VPN configurations from trusted providers. All options are privacy-focused with no logging.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSetupSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Setup (Recommended)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        
        // Cloudflare WARP
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.cloud, color: theme.colorScheme.primary),
            ),
            title: Text('Cloudflare WARP'),
            subtitle: Text('Free • Unlimited • Fast • No registration'),
            trailing: ElevatedButton(
              onPressed: _generateCloudflareWarp,
              child: Text('Get Config'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualImportSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manual Import',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _importConfigFile,
                icon: Icon(Icons.file_upload),
                label: Text('Import .conf File'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _scanQrCode,
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Scan QR Code'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        ElevatedButton.icon(
          onPressed: _showManualInputDialog,
          icon: Icon(Icons.edit),
          label: Text('Enter Config Manually'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableConfigsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Configurations (${_availableConfigs.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _loadFreeConfigs,
              child: Text('Refresh'),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        if (_availableConfigs.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
                  SizedBox(height: 12),
                  Text(
                    'No configurations available',
                    style: theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try generating a Cloudflare WARP config or import your own.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _availableConfigs.length,
            itemBuilder: (context, index) {
              final config = _availableConfigs[index];
              return _buildConfigCard(config, theme);
            },
          ),
      ],
    );
  }

  Widget _buildConfigCard(VpnConfig config, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          child: Icon(Icons.vpn_lock, color: theme.colorScheme.secondary),
        ),
        title: Text(config.name),
        subtitle: Text('${config.serverAddress}:${config.port}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _testConfiguration(config),
              icon: Icon(Icons.speed),
              tooltip: 'Test Connection',
            ),
            IconButton(
              onPressed: () => _showConfigDetails(config),
              icon: Icon(Icons.info_outline),
              tooltip: 'View Details',
            ),
          ],
        ),
        onTap: () => _useConfiguration(config),
      ),
    );
  }

  Future<void> _generateCloudflareWarp() async {
    setState(() => _isLoading = true);
    
    try {
      _logger.i('Generating Cloudflare WARP configuration...');
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating WARP configuration...'),
            ],
          ),
        ),
      );
      
      final config = await _freeVpnProvider.getFreeVpnConfigs();
      Navigator.pop(context); // Close progress dialog
      
      if (config.isNotEmpty) {
        setState(() {
          _availableConfigs.addAll(config);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ WARP configuration generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('No configurations generated');
      }
      
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      _logger.e('WARP generation failed', error: e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate WARP config: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importConfigFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'wg'],
      );
      
      if (result != null && result.files.single.bytes != null) {
        final configText = String.fromCharCodes(result.files.single.bytes!);
        final config = VpnConfig.fromWireGuardConfig(
          configText,
          customName: result.files.single.name,
        );
        
        await _serversRepo.addCustomVpnConfig(config);
        await _loadFreeConfigs();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Configuration imported successfully!')),
        );
      }
    } catch (e) {
      _logger.e('Config import failed', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import config: $e')),
      );
    }
  }

  Future<void> _scanQrCode() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Scan QR Code')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context);
                  _processQrCodeData(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _processQrCodeData(String data) {
    try {
      final config = VpnConfig.fromWireGuardConfig(data, customName: 'QR Imported Config');
      _serversRepo.addCustomVpnConfig(config);
      _loadFreeConfigs();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ QR code configuration imported!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid QR code format: $e')),
      );
    }
  }

  void _showManualInputDialog() {
    // Implementation for manual config input dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manual Configuration'),
        content: Text('Manual input dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConfiguration(VpnConfig config) async {
    // TODO: Implement connection test
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Testing ${config.name}...')),
    );
  }

  void _showConfigDetails(VpnConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(config.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: ${config.serverAddress}'),
            Text('Port: ${config.port}'),
            Text('DNS: ${config.dnsServers.join(', ')}'),
            Text('Created: ${config.createdAt.toString().split(' ')[0]}'),
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

  void _useConfiguration(VpnConfig config) {
    // Navigate back with selected configuration
    Navigator.pop(context, config);
  }
}