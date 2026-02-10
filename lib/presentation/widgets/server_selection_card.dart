import 'package:flutter/material.dart';
import '../../data/models/built_in_server.dart';

class ServerSelectionCard extends StatelessWidget {
  final BuiltInServer? selectedServer;
  final VoidCallback onTap;

  const ServerSelectionCard({
    Key? key,
    required this.selectedServer,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Flag or Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: selectedServer != null
                    ? Text(
                        selectedServer!.flagEmoji,
                        style: TextStyle(fontSize: 24),
                      )
                    : Icon(
                        Icons.language,
                        color: Colors.blue,
                        size: 28,
                      ),
              ),
            ),
            
            SizedBox(width: 16),
            
            // Server Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedServer?.name ?? 'Choose Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    selectedServer != null
                        ? '${selectedServer!.city} • ${selectedServer!.maxSpeedMbps} Mbps'
                        : 'Select a server location',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (selectedServer != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        // Load Indicator
                        Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 60 * (selectedServer!.loadPercentage / 100),
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getLoadColor(selectedServer!.loadPercentage),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${selectedServer!.loadPercentage}% load',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.white70,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Color _getLoadColor(int loadPercentage) {
    if (loadPercentage < 30) {
      return Colors.green;
    } else if (loadPercentage < 70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}