import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_logic/providers/anonymous_providers.dart';
import '../../data/models/anonymous_chain.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          'Connection Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _refreshStatus(),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshStatus,
          backgroundColor: Color(0xFF1D1E33),
          color: Colors.white,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Status Card
                _buildMainStatusCard(activeChain),
                SizedBox(height: 20),

                // Security Status
                _buildSecurityStatus(activeChain),
                SizedBox(height: 20),

                // Network Info
                _buildNetworkInfo(activeChain),
                SizedBox(height: 20),

                // Connection Timeline
                if (activeChain?.status == ChainStatus.connected)
                  _buildConnectionTimeline(activeChain!),

                // Diagnostics
                _buildDiagnostics(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
            ? [Color(0xFF1B5E20), Color(0xFF2E7D32)]
            : isConnecting
            ? [Color(0xFF1565C0), Color(0xFF1976D2)]
            : [Color(0xFF424242), Color(0xFF616161)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? Colors.green : isConnecting ? Colors.blue : Colors.grey)
                .withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isConnected 
              ? Icons.shield 
              : isConnecting 
              ? Icons.sync 
              : Icons.shield_outlined,
            size: 60,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            isConnected 
              ? 'SECURED' 
              : isConnecting 
              ? 'CONNECTING...' 
              : 'NOT CONNECTED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isConnected
              ? 'Your connection is fully protected'
              : isConnecting
              ? 'Establishing secure tunnel'
              : 'Tap connect to secure your connection',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (activeChain?.currentMode != null && isConnected)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${activeChain!.currentMode.toString().split('.').last.toUpperCase()} MODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatus(AnonymousChain? activeChain) {
    final isConnected = activeChain?.status == ChainStatus.connected;

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
          Row(
            children: [
              Icon(Icons.security, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Security Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSecurityItem('IP Protection', isConnected, 'Your real IP is hidden'),
          _buildSecurityItem('DNS Security', isConnected, 'DNS queries are encrypted'),
          _buildSecurityItem('Traffic Encryption', isConnected, 'All data is encrypted'),
          _buildSecurityItem('Kill Switch', true, 'Prevents IP leaks'),
          _buildSecurityItem('No Logging', true, 'Zero-log policy active'),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String title, bool isActive, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
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
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo(AnonymousChain? activeChain) {
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
          Row(
            children: [
              Icon(Icons.network_check, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Network Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildNetworkDetail('Public IP', activeChain?.status == ChainStatus.connected ? 'Hidden' : 'Exposed'),
          _buildNetworkDetail('Location', activeChain?.status == ChainStatus.connected ? 'Anonymous' : 'Real Location'),
          _buildNetworkDetail('ISP', activeChain?.status == ChainStatus.connected ? 'VPN Provider' : 'Your ISP'),
          _buildNetworkDetail('Protocol', 'WireGuard'),
          _buildNetworkDetail('Servers', '${activeChain?.servers.length ?? 0} hops'),
        ],
      ),
    );
  }

  Widget _buildNetworkDetail(String label, String value) {
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

  Widget _buildConnectionTimeline(AnonymousChain activeChain) {
    return Container(
      padding: EdgeInsets.all(20),
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
              Icon(Icons.timeline, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Connection Route',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...activeChain.servers.asMap().entries.map((entry) {
            int index = entry.key;
            var server = entry.value;
            bool isLast = index == activeChain.servers.length - 1;
            
            return _buildTimelineItem(
              'Server ${index + 1}',
              server.country,
              index == 0 ? 'Entry Point' : isLast ? 'Exit Point' : 'Relay',
              !isLast,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String location, String type, bool hasNext) {
    return Column(
      children: [
        Row(
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (hasNext)
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.green.withOpacity(0.5),
                  ),
              ],
            ),
            SizedBox(width: 16),
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
                    '$location • $type',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasNext) SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDiagnostics() {
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
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDiagnosticCard('Latency', '--ms', Icons.speed),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDiagnosticCard('Upload', '--Mbps', Icons.upload),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDiagnosticCard('Download', '--Mbps', Icons.download),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshStatus() async {
    // Simulate refresh
    await Future.delayed(Duration(seconds: 1));
    if (mounted) {
      setState(() {
        // Trigger rebuild
      });
    }
  }
}