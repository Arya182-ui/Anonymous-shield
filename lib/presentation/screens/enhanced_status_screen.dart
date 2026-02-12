import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../business_logic/providers/anonymous_providers.dart';
import '../../business_logic/managers/enhanced_vpn_manager.dart';
import '../../business_logic/services/security_manager.dart';
import '../../data/models/enhanced_vpn_models.dart';
import '../../data/models/anonymous_chain.dart';

class EnhancedStatusScreen extends ConsumerStatefulWidget {
  const EnhancedStatusScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EnhancedStatusScreen> createState() => _EnhancedStatusScreenState();
}

class _EnhancedStatusScreenState extends ConsumerState<EnhancedStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Enhanced managers
  final EnhancedVpnManager _vpnManager = EnhancedVpnManager();
  final SecurityManager _securityManager = SecurityManager();
  
  // Status subscriptions
  StreamSubscription? _vpnStatusSubscription;
  StreamSubscription? _securityAlertSubscription;
  StreamSubscription? _connectionInfoSubscription;
  
  // Current status
  VpnConnectionStatus? _vpnStatus;
  VpnConnectionInfo? _connectionInfo;
  SecurityStatus? _securityStatus;
  SecurityTestResult? _lastSecurityTest;
  List<SecurityAlert> _recentAlerts = [];
  
  bool _isInitialized = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    // Initialize enhanced status monitoring
    _initializeStatusMonitoring();
  }

  Future<void> _initializeStatusMonitoring() async {
    try {
      final vpnInitialized = await _vpnManager.initialize();
      final securityInitialized = await _securityManager.initialize();
      
      if (vpnInitialized) {
        _vpnStatusSubscription = _vpnManager.statusStream.listen((status) {
          if (mounted) {
            setState(() {
              _vpnStatus = status;
            });
          }
        });
        
        _connectionInfoSubscription = _vpnManager.connectionInfoStream.listen((info) {
          if (mounted) {
            setState(() {
              _connectionInfo = info;
            });
          }
        });
      }
      
      if (securityInitialized) {
        _securityAlertSubscription = _securityManager.alertStream.listen((alert) {
          if (mounted) {
            setState(() {
              _recentAlerts.insert(0, alert);
              if (_recentAlerts.length > 20) {
                _recentAlerts.removeLast();
              }
            });
          }
        });
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = vpnInitialized && securityInitialized;
        });
      }
      
      // Initial status refresh
      await _refreshStatus(showLoading: false);
      
    } catch (e) {
      print('Failed to initialize status monitoring: $e');
    }
  }

  @override
  void dispose() {
    _vpnStatusSubscription?.cancel();
    _securityAlertSubscription?.cancel();
    _connectionInfoSubscription?.cancel();
    _animationController.dispose();
    _vpnManager.dispose();
    _securityManager.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus({bool showLoading = true}) async {
    if (_isRefreshing) return;
    
    if (showLoading) {
      setState(() {
        _isRefreshing = true;
      });
    }
    
    try {
      if (_isInitialized) {
        // Get current security status
        _securityStatus = _securityManager.getSecurityStatus();
        
        // Run security test
        _lastSecurityTest = await _securityManager.runSecurityTest();
        
        // Update connection info
        final info = await _vpnManager.getConnectionInfo();
        _connectionInfo = info;
      }
    } catch (e) {
      print('Failed to refresh status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (showLoading && mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChain = ref.watch(activeAnonymousChainProvider);

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
          'Enhanced Connection Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => _refreshStatus(),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () => _refreshStatus(),
          backgroundColor: Color(0xFF1D1E33),
          color: Colors.white,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Initialization status
                if (!_isInitialized) _buildInitializationCard(),
                
                // Native VPN Status
                if (_isInitialized) _buildNativeVpnStatusCard(),
                SizedBox(height: 20),

                // Main Status Card (legacy compatibility)
                _buildMainStatusCard(activeChain),
                SizedBox(height: 20),

                // Enhanced Security Status
                if (_isInitialized) _buildEnhancedSecurityStatus(),
                SizedBox(height: 20),

                // Real Network Info
                if (_isInitialized) _buildRealNetworkInfo(),
                SizedBox(height: 20),

                // Connection Timeline
                if (activeChain?.status == ChainStatus.connected || _vpnStatus?.vpnStatus == VpnConnectionState.connected)
                  _buildConnectionTimeline(activeChain),
                SizedBox(height: 20),

                // Security Test Results
                if (_isInitialized && _lastSecurityTest != null) _buildSecurityTestResults(),
                SizedBox(height: 20),

                // Security Alerts
                if (_isInitialized && _recentAlerts.isNotEmpty) _buildSecurityAlerts(),
                SizedBox(height: 20),

                // Enhanced Diagnostics
                if (_isInitialized) _buildEnhancedDiagnostics(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitializationCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.orange, size: 48),
          SizedBox(height: 12),
          Text(
            'Initializing Enhanced Services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Setting up native VPN and security monitoring...',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeVpnStatusCard() {
    final isConnected = _vpnStatus?.vpnStatus == VpnConnectionState.connected;
    final isConnecting = _vpnStatus?.vpnStatus == VpnConnectionState.connecting;
    final hasError = _vpnStatus?.vpnStatus == VpnConnectionState.error;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtext;
    
    if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.vpn_lock;
      statusText = 'Native VPN Connected';
      statusSubtext = _connectionInfo?.publicIp ?? 'IP address protected';
    } else if (isConnecting) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = 'Connecting to VPN';
      statusSubtext = 'Establishing secure tunnel...';
    } else if (hasError) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = 'VPN Connection Error';
      statusSubtext = _vpnStatus?.error ?? 'Unknown error occurred';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.vpn_key_off;
      statusText = 'VPN Disconnected';
      statusSubtext = 'No active VPN connection';
    }
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusSubtext,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (_connectionInfo != null && isConnected) ...[
            SizedBox(height: 16),
            Divider(color: Colors.white12),
            SizedBox(height: 16),
            
            _buildInfoRow('Public IP', _connectionInfo!.publicIp),
            _buildInfoRow('Country', _connectionInfo!.country),
            _buildInfoRow('ISP', _connectionInfo!.isp),
            _buildInfoRow('City', _connectionInfo!.city),
            if (_connectionInfo!.latency != null)
              _buildInfoRow('Latency', _connectionInfo!.latency!),
            if (_connectionInfo!.dataUsage != null)
              _buildInfoRow('Data Usage', _connectionInfo!.dataUsage!),
          ],
        ],
      ),
    );
  }

  Widget _buildMainStatusCard(AnonymousChain? activeChain) {
    final isConnected = activeChain?.status == ChainStatus.connected;
    final isConnecting = activeChain?.status == ChainStatus.connecting;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [Color(0xFF00C896), Color(0xFF00A074)]
              : isConnecting
                  ? [Color(0xFFFF6B35), Color(0xFFE55A2B)]
                  : [Color(0xFF6C5CE7), Color(0xFF5B4BD3)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isConnected
                    ? Colors.green
                    : isConnecting
                        ? Colors.orange
                        : Colors.purple)
                .withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isConnected
                ? Icons.shield_rounded
                : isConnecting
                    ? Icons.sync_rounded
                    : Icons.shield_outlined,
            size: 64,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            isConnected
                ? 'ANONYMOUSLY CONNECTED'
                : isConnecting
                    ? 'ESTABLISHING CONNECTION'
                    : 'NOT CONNECTED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          if (activeChain != null)
            Text(
              'Mode: ${activeChain.mode.toString().split('.').last.toUpperCase()}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSecurityStatus() {
    if (_securityStatus == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }
    
    final status = _securityStatus!;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getSecurityLevelColor(status.securityLevel).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Security Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Security score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Security Level: ${status.securityLevel}',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                '${(status.securityScore * 100).toInt()}%',
                style: TextStyle(
                  color: _getSecurityLevelColor(status.securityLevel),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: status.securityScore,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getSecurityLevelColor(status.securityLevel),
            ),
          ),
          
          SizedBox(height: 20),
          
          // Security features
          _buildSecurityFeature('Kill Switch', status.killSwitchEnabled),
          _buildSecurityFeature('DNS Leak Protection', status.dnsLeakProtectionEnabled),
          _buildSecurityFeature('IPv6 Blocking', status.ipv6BlockingEnabled),
          _buildSecurityFeature('WebRTC Blocking', status.webRtcBlockingEnabled),
          _buildSecurityFeature('Monitoring Active', status.monitoringActive),
        ],
      ),
    );
  }

  Widget _buildRealNetworkInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.network_wifi, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Network Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          if (_connectionInfo != null) ...[
            _buildInfoRow('Public IP', _connectionInfo!.publicIp),
            _buildInfoRow('Country', _connectionInfo!.country),
            _buildInfoRow('City', _connectionInfo!.city),
            _buildInfoRow('ISP', _connectionInfo!.isp),
            if (_connectionInfo!.latitude != null && _connectionInfo!.longitude != null)
              _buildInfoRow('Location', '${_connectionInfo!.latitude}, ${_connectionInfo!.longitude}'),
            if (_connectionInfo!.timezone != null)
              _buildInfoRow('Timezone', _connectionInfo!.timezone!),
          ] else ...[
            Text(
              'No network information available',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionTimeline(AnonymousChain? activeChain) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Connection Timeline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Connection start time
          if (_connectionInfo?.connectionStartTime != null) ...[
            _buildTimelineEvent(
              'Connection Started',
              _connectionInfo!.connectionStartTime!,
              Icons.play_circle_outline,
              Colors.green,
            ),
            
            // Connection duration
            _buildInfoRow(
              'Duration',
              _formatDuration(DateTime.now().difference(_connectionInfo!.connectionStartTime!)),
            ),
          ] else if (activeChain?.connectedAt != null) ...[
            _buildTimelineEvent(
              'Chain Created',
              activeChain!.connectedAt!,
              Icons.link,
              Colors.blue,
            ),
          ],
          
          // Last data transfer
          if (_connectionInfo?.lastDataTransfer != null) ...[
            SizedBox(height: 12),
            _buildTimelineEvent(
              'Last Data Transfer',
              _connectionInfo!.lastDataTransfer!,
              Icons.sync_alt,
              Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityTestResults() {
    final result = _lastSecurityTest!;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.overallPassed ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.overallPassed ? Icons.check_circle : Icons.error,
                color: result.overallPassed ? Colors.green : Colors.red,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Security Test Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          Text(
            'Overall: ${result.overallPassed ? "PASSED" : "FAILED"}',
            style: TextStyle(
              color: result.overallPassed ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          
          Text(
            'Tests: ${result.passedTests}/${result.tests.length} passed (${(result.successRate * 100).toInt()}%)',
            style: TextStyle(color: Colors.white70),
          ),
          
          SizedBox(height: 16),
          
          // Individual test results
          ...result.tests.map((test) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  test.passed ? Icons.check : Icons.close,
                  color: test.passed ? Colors.green : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    test.name,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSecurityAlerts() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text(
                'Recent Security Alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Show recent alerts
          ...(_recentAlerts.take(5).map((alert) => Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getAlertColor(alert.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getAlertColor(alert.type).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getAlertIcon(alert.type),
                        color: _getAlertColor(alert.type),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        alert.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ))),
        ],
      ),
    );
  }

  Widget _buildEnhancedDiagnostics() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Enhanced Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // VPN Manager Status
          _buildDiagnosticItem('VPN Manager', _isInitialized ? 'Initialized' : 'Not Ready'),
          _buildDiagnosticItem('Security Manager', _securityStatus != null ? 'Active' : 'Inactive'),
          
          // Connection details
          if (_vpnStatus != null) ...[
            _buildDiagnosticItem('Native VPN Status', _vpnStatus!.vpnStatus.toString().split('.').last),
            if (_vpnStatus!.error != null)
              _buildDiagnosticItem('Last Error', _vpnStatus!.error!),
          ],
          
          // Security monitoring
          if (_securityStatus != null) ...[
            _buildDiagnosticItem('Security Monitoring', _securityStatus!.monitoringActive ? 'Active' : 'Inactive'),
            _buildDiagnosticItem('Enabled Features', '${_securityStatus!.enabledFeatures}/4'),
          ],
          
          SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _runSecurityTest(),
                  icon: Icon(Icons.security),
                  label: Text('Run Security Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportLogs(),
                  icon: Icon(Icons.download),
                  label: Text('Export Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFeature(String name, bool enabled) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(color: Colors.white70)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: enabled ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(
                color: enabled ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(String title, DateTime time, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            Text(
              '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSecurityLevelColor(String level) {
    switch (level) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Fair':
        return Colors.orange;
      default:
        return Colors.red;
    }
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _runSecurityTest() async {
    setState(() => _isRefreshing = true);
    
    try {
      _lastSecurityTest = await _securityManager.runSecurityTest();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Security test completed: ${_lastSecurityTest!.overallPassed ? "PASSED" : "FAILED"}'),
          backgroundColor: _lastSecurityTest!.overallPassed ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Security test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _exportLogs() async {
    // Implementation would export logs to file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Log export feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}