import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final List<Map<String, dynamic>> _configs = [
    {
      'name': 'Personal VPN Config',
      'type': 'WireGuard',
      'status': 'Active',
      'servers': 3,
      'created': 'Jan 15, 2026',
    },
    {
      'name': 'Work Network',
      'type': 'WireGuard',
      'status': 'Inactive',
      'servers': 1,
      'created': 'Jan 10, 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Color(0xFF1D1E33),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VPN Configurations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddConfigDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            _buildInfoCard(),
            SizedBox(height: 20),

            // Config List
            Text(
              'Your Configurations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            ..._configs.map((config) => _buildConfigCard(config)).toList(),
            
            SizedBox(height: 20),
            
            // Add Config Button
            _buildAddConfigCard(),
            
            SizedBox(height: 20),
            
            // Settings Section
            _buildSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D1E33).withOpacity(0.8),
            Color(0xFF2C2D54).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.vpn_key,
              color: Colors.blue,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Configurations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Import your own WireGuard configs or use our built-in servers',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(Map<String, dynamic> config) {
    final isActive = config['status'] == 'Active';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.1),
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
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  config['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white70, size: 20),
                color: Color(0xFF2C2D54),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleConfigAction(config, value),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildConfigDetail('Type', config['type']),
              SizedBox(width: 24),
              _buildConfigDetail('Servers', '${config['servers']}'),
              SizedBox(width: 24),
              _buildConfigDetail('Created', config['created']),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? Colors.green : Colors.grey).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  config['status'],
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _toggleConfig(config),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.orange : Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isActive ? 'Disconnect' : 'Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAddConfigCard() {
    return InkWell(
      onTap: () => _showAddConfigDialog(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add,
                color: Colors.blue,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Import WireGuard config file or create manually',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuration Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildSettingItem(
            'Auto-Connect',
            'Automatically connect to last used config',
            true,
            (value) => {},
          ),
          _buildSettingItem(
            'Kill Switch',
            'Block internet when VPN disconnects',
            true,
            (value) => {},
          ),
          _buildSettingItem(
            'DNS over HTTPS',
            'Use secure DNS resolution',
            false,
            (value) => {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String description, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
            activeTrackColor: Colors.blue.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _showAddConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1D1E33),
        title: Text(
          'Add Configuration',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.file_upload, color: Colors.blue),
              title: Text(
                'Import Config File',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Import WireGuard .conf file',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => _importConfigFile(),
            ),
            Divider(color: Colors.white24),
            ListTile(
              leading: Icon(Icons.add_circle, color: Colors.green),
              title: Text(
                'Create Manually',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Enter configuration details',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () => _createManualConfig(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _importConfigFile() async {
    Navigator.pop(context);
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['conf'],
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      // Process the config file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Config file imported successfully'),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  void _createManualConfig() {
    Navigator.pop(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1D1E33),
        title: Text(
          'Manual Configuration',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Manual config creation will be implemented in the next update.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConfigAction(Map<String, dynamic> config, String action) {
    switch (action) {
      case 'edit':
        // Implement edit functionality
        break;
      case 'delete':
        _showDeleteConfirmation(config);
        break;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1D1E33),
        title: Text(
          'Delete Configuration',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${config['name']}"? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _configs.remove(config);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Configuration deleted'),
                  backgroundColor: Colors.red[700],
                ),
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleConfig(Map<String, dynamic> config) {
    setState(() {
      // Deactivate all configs first
      for (var cfg in _configs) {
        cfg['status'] = 'Inactive';
      }
      
      // Activate selected config if it was inactive
      if (config['status'] == 'Inactive') {
        config['status'] = 'Active';
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          config['status'] == 'Active' 
            ? 'Connected to ${config['name']}'
            : 'Disconnected from ${config['name']}'
        ),
        backgroundColor: config['status'] == 'Active' 
          ? Colors.green[700] 
          : Colors.orange[700],
      ),
    );
  }
}