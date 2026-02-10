import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import '../providers/connection_provider.dart';
import '../providers/server_selection_provider.dart';
import '../../data/repositories/built_in_servers_repository.dart';
import '../../data/models/built_in_server.dart';
import '../../data/models/connection_status.dart';

class AutoConnectService {
  static final AutoConnectService _instance = AutoConnectService._internal();
  factory AutoConnectService() => _instance;
  AutoConnectService._internal();

  final _serversRepo = BuiltInServersRepository();
  final _logger = Logger();
  bool _isAutoConnectEnabled = false;
  Timer? _reconnectTimer;

  // Quick connect - one tap to connect to best server
  Future<bool> quickConnect(WidgetRef ref) async {
    try {
      // Get user location for smart server selection
      final position = await _getUserLocation();
      
      BuiltInServer bestServer;
      if (position != null) {
        bestServer = _serversRepo.getBestServer(
          userLat: position.latitude,
          userLon: position.longitude,
        );
      } else {
        // Fallback to server with lowest load
        bestServer = _serversRepo.getBestServer();
      }

      // Update selected server
      ref.read(selectedServerProvider.notifier).selectServer(bestServer);
      
      // Connect to VPN
      final connectionNotifier = ref.read(connectionProvider.notifier);
      await connectionNotifier.connect(bestServer);
      
      return true;
    } catch (e) {
      _logger.e('Quick connect failed: $e');
      return false;
    }
  }

  // Smart connect to specific country
  Future<bool> connectToCountry(String countryCode, WidgetRef ref) async {
    try {
      final servers = _serversRepo.getServersByCountry(countryCode);
      if (servers.isEmpty) return false;

      // Pick server with lowest load in that country
      servers.sort((a, b) => a.loadPercentage.compareTo(b.loadPercentage));
      final bestServer = servers.first;

      ref.read(selectedServerProvider.notifier).selectServer(bestServer);
      
      final connectionNotifier = ref.read(connectionProvider.notifier);
      await connectionNotifier.connect(bestServer);
      
      return true;
    } catch (e) {
      _logger.e('Connect to country failed: $e');
      return false;
    }
  }

  // Auto-reconnect on connection drop
  void enableAutoReconnect(WidgetRef ref) {
    _isAutoConnectEnabled = true;
    
    // Monitor connection status
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_isAutoConnectEnabled) {
        timer.cancel();
        return;
      }

      final connectionState = ref.read(connectionProvider);
      if (connectionState.status == SimpleConnectionStatus.disconnected && 
          connectionState.selectedServer != null) {
        // Attempt reconnect
        try {
          await ref.read(connectionProvider.notifier)
              .connect(connectionState.selectedServer!);
        } catch (e) {
          _logger.e('Auto-reconnect failed: $e');
        }
      }
    });
  }

  void disableAutoReconnect() {
    _isAutoConnectEnabled = false;
    _reconnectTimer?.cancel();
  }

  Future<Position?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      );
    } catch (e) {
      return null;
    }
  }

  // Get connection recommendations based on user location and usage
  List<BuiltInServer> getRecommendedServers({Position? userPosition}) {
    if (userPosition != null) {
      return _serversRepo.getNearestServers(
        userPosition.latitude, 
        userPosition.longitude,
        limit: 3,
      );
    }
    return _serversRepo.getRecommendedServers();
  }
}