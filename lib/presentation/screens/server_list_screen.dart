import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business_logic/providers/server_selection_provider.dart';
import '../../business_logic/providers/location_provider.dart';
import '../../data/models/built_in_server.dart';

class ServerListScreen extends ConsumerStatefulWidget {
  const ServerListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends ConsumerState<ServerListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(availableServersProvider);
    final recommendedServers = ref.watch(recommendedServersProvider);
    final serversByCountry = ref.watch(serversByCountryProvider);
    final selectedServer = ref.watch(selectedServerProvider);
    final userLocation = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Color(0xFF1D1E33),
        title: Text(
          'Choose Server',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF0A0E21),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search servers...',
                    hintStyle: TextStyle(color: Colors.white60),
                    prefixIcon: Icon(Icons.search, color: Colors.white60),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query.toLowerCase();
                    });
                  },
                ),
              ),
              
              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.blue,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: 'Recommended'),
                  Tab(text: 'All Servers'),
                  Tab(text: 'By Country'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recommended Tab
          _buildServerList(
            _filterServers(recommendedServers, _searchQuery),
            selectedServer,
            userLocation,
            isRecommended: true,
          ),
          
          // All Servers Tab
          _buildServerList(
            _filterServers(servers, _searchQuery),
            selectedServer,
            userLocation,
          ),
          
          // By Country Tab
          _buildCountryList(serversByCountry, selectedServer, _searchQuery),
        ],
      ),
    );
  }

  Widget _buildServerList(
    List<BuiltInServer> servers,
    BuiltInServer? selectedServer,
    userLocation, {
    bool isRecommended = false,
  }) {
    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white60,
            ),
            SizedBox(height: 16),
            Text(
              'No servers found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isSelected = selectedServer?.id == server.id;
        final distance = userLocation != null
            ? server.distanceFrom(userLocation.latitude, userLocation.longitude)
            : null;

        return _ServerCard(
          server: server,
          isSelected: isSelected,
          distance: distance,
          onTap: () => _selectServer(server),
        );
      },
    );
  }

  Widget _buildCountryList(
    Map<String, List<BuiltInServer>> serversByCountry,
    BuiltInServer? selectedServer,
    String searchQuery,
  ) {
    final filteredCountries = serversByCountry.entries
        .where((entry) => 
            entry.key.toLowerCase().contains(searchQuery) ||
            entry.value.any((server) => 
                server.name.toLowerCase().contains(searchQuery) ||
                server.city.toLowerCase().contains(searchQuery)
            )
        )
        .toList();

    if (filteredCountries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white60,
            ),
            SizedBox(height: 16),
            Text(
              'No countries found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredCountries.length,
      itemBuilder: (context, index) {
        final entry = filteredCountries[index];
        final country = entry.key;
        final countryServers = entry.value;
        
        return _CountryCard(
          country: country,
          servers: countryServers,
          selectedServer: selectedServer,
          onServerSelect: _selectServer,
        );
      },
    );
  }

  List<BuiltInServer> _filterServers(List<BuiltInServer> servers, String query) {
    if (query.isEmpty) return servers;
    
    return servers.where((server) {
      return server.name.toLowerCase().contains(query) ||
          server.country.toLowerCase().contains(query) ||
          server.city.toLowerCase().contains(query);
    }).toList();
  }

  void _selectServer(BuiltInServer server) {
    ref.read(selectedServerProvider.notifier).selectServer(server);
    Navigator.pop(context);
  }
}

class _ServerCard extends StatelessWidget {
  final BuiltInServer server;
  final bool isSelected;
  final double? distance;
  final VoidCallback onTap;

  const _ServerCard({
    required this.server,
    required this.isSelected,
    this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Flag
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    server.flagEmoji,
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              
              SizedBox(width: 16),
              
              // Server Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            server.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (server.isRecommended)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BEST',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Up to ${server.maxSpeedMbps} Mbps',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (distance != null) ...[
                          Text(
                            ' • ${distance!.round()} km away',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
                    // Load Bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 
                                    0.5 * (server.loadPercentage / 100),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _getLoadColor(server.loadPercentage),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${server.loadPercentage}%',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLoadColor(int loadPercentage) {
    if (loadPercentage < 30) return Colors.green;
    if (loadPercentage < 70) return Colors.orange;
    return Colors.red;
  }
}

class _CountryCard extends StatelessWidget {
  final String country;
  final List<BuiltInServer> servers;
  final BuiltInServer? selectedServer;
  final Function(BuiltInServer) onServerSelect;

  const _CountryCard({
    required this.country,
    required this.servers,
    required this.selectedServer,
    required this.onServerSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  servers.first.flagEmoji,
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    country,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${servers.length} server${servers.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...servers.map((server) => _ServerCard(
                server: server,
                isSelected: selectedServer?.id == server.id,
                onTap: () => onServerSelect(server),
              )),
        ],
      ),
    );
  }
}