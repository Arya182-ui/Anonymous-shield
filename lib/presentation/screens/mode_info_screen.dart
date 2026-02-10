import 'package:flutter/material.dart';
import '../../data/models/anonymous_chain.dart';

class ModeInfoScreen extends StatelessWidget {
  const ModeInfoScreen({Key? key}) : super(key: key);

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
          'VPN Modes Guide',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.only(bottom: 24),
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
                  color: Colors.white.withOpacity(0.1),
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
                      Icons.info_outline,
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
                          'Choose Your Protection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select the right mode based on your needs',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Mode Cards
            _buildModeCard(
              context,
              mode: AnonymousMode.ghost,
              icon: '🥷',
              title: 'Ghost Mode',
              subtitle: 'Maximum Anonymity',
              description: 'Undetectable browsing with military-grade protection. Routes your traffic through 5+ secure servers worldwide.',
              features: [
                '5+ Server Hops',
                'Maximum Encryption',
                'No Digital Footprint',
                'Tor-Level Anonymity',
                'Government-Proof',
              ],
              pros: [
                'Highest privacy protection',
                'Bypasses all restrictions',
                'Untrackable connection',
              ],
              cons: [
                'Slower connection speed',
                'Higher battery usage',
              ],
              useCase: 'Perfect for: Sensitive research, journalism, high-privacy activities',
              color: Colors.purple,
            ),

            _buildModeCard(
              context,
              mode: AnonymousMode.stealth,
              icon: '🎭',
              title: 'Stealth Mode',
              subtitle: 'Bypass Deep Packet Inspection',
              description: 'Specialized mode to defeat government firewalls and advanced censorship systems.',
              features: [
                'DPI Evasion',
                'Traffic Obfuscation',
                'Firewall Bypass',
                'Protocol Mimicking',
                'Anti-Censorship',
              ],
              pros: [
                'Bypasses censorship',
                'Works in restricted countries',
                'Disguises VPN traffic',
              ],
              cons: [
                'Medium speed impact',
                'Complex routing',
              ],
              useCase: 'Perfect for: Censored countries, corporate networks, restricted regions',
              color: Colors.green,
            ),

            _buildModeCard(
              context,
              mode: AnonymousMode.turbo,
              icon: '⚡',
              title: 'Turbo Mode',
              subtitle: 'Optimized Performance',
              description: 'Balanced approach offering good privacy protection with optimized speed for daily use.',
              features: [
                'Speed Optimized',
                'Smart Routing',
                'Battery Efficient',
                'Quick Connect',
                'Low Latency',
              ],
              pros: [
                'Fastest connection',
                'Good privacy protection',
                'Low battery drain',
              ],
              cons: [
                'Fewer server hops',
                'Standard encryption',
              ],
              useCase: 'Perfect for: Daily browsing, streaming, social media, general privacy',
              color: Colors.blue,
            ),

            // Comparison Table
            SizedBox(height: 32),
            _buildComparisonTable(),

            // Tips Section
            SizedBox(height: 32),
            _buildTipsSection(),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required AnonymousMode mode,
    required String icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> features,
    required List<String> pros,
    required List<String> cons,
    required String useCase,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                icon,
                style: TextStyle(fontSize: 32),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),

          SizedBox(height: 16),

          // Features
          Text(
            'Features:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features.map((feature) => Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                feature,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),

          SizedBox(height: 16),

          // Pros & Cons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Pros',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    ...pros.map((pro) => Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 2),
                      child: Text(
                        '• $pro',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Considerations',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    ...cons.map((con) => Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 2),
                      child: Text(
                        '• $con',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Use Case
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: color, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    useCase,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: EdgeInsets.all(16),
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
            'Quick Comparison',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Table(
            columnWidths: {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header
              TableRow(
                children: [
                  _buildTableCell('', isHeader: true),
                  _buildTableCell('🥷\nGhost', isHeader: true, color: Colors.purple),
                  _buildTableCell('🎭\nStealth', isHeader: true, color: Colors.green),
                  _buildTableCell('⚡\nTurbo', isHeader: true, color: Colors.blue),
                ],
              ),
              // Privacy
              TableRow(
                children: [
                  _buildTableCell('Privacy Level'),
                  _buildTableCell('★★★★★', color: Colors.purple),
                  _buildTableCell('★★★★☆', color: Colors.green),
                  _buildTableCell('★★★☆☆', color: Colors.blue),
                ],
              ),
              // Speed
              TableRow(
                children: [
                  _buildTableCell('Speed'),
                  _buildTableCell('★★☆☆☆', color: Colors.purple),
                  _buildTableCell('★★★☆☆', color: Colors.green),
                  _buildTableCell('★★★★★', color: Colors.blue),
                ],
              ),
              // Battery
              TableRow(
                children: [
                  _buildTableCell('Battery Usage'),
                  _buildTableCell('High', color: Colors.purple),
                  _buildTableCell('Medium', color: Colors.green),
                  _buildTableCell('Low', color: Colors.blue),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? (isHeader ? Colors.white : Colors.white70),
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.yellow.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.yellow, size: 20),
              SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildTip('Switch modes based on your activity - Ghost for sensitive work, Turbo for daily use'),
          _buildTip('Use Stealth mode in countries with internet restrictions'),
          _buildTip('Connect to servers closer to you for better speed'),
          _buildTip('Ghost mode works best on WiFi connections'),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.yellow,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}