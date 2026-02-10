import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// User location state
final userLocationProvider = StateNotifierProvider<UserLocationNotifier, Position?>((ref) {
  return UserLocationNotifier();
});

// Location permission state
final locationPermissionProvider = StateNotifierProvider<LocationPermissionNotifier, LocationPermission>((ref) {
  return LocationPermissionNotifier();
});

class UserLocationNotifier extends StateNotifier<Position?> {
  UserLocationNotifier() : super(null) {
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      );
      
      state = position;
    } catch (e) {
      // Location failed, use fallback
      state = null;
    }
  }

  Future<void> refreshLocation() async {
    await _getCurrentLocation();
  }
}

class LocationPermissionNotifier extends StateNotifier<LocationPermission> {
  LocationPermissionNotifier() : super(LocationPermission.denied) {
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final permission = await Geolocator.checkPermission();
    state = permission;
  }

  Future<void> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    state = permission;
  }
}