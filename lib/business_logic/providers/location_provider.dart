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
      if (!serviceEnabled) {
        // Try last known as fallback
        await _tryLastKnown();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _tryLastKnown();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await _tryLastKnown();
        return;
      }

      // Try last known first (instant, no network needed)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          state = lastKnown;
        }
      } catch (_) {}

      // Then get fresh position with generous timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      );
      
      state = position;
    } catch (e) {
      // Location failed, try last known as fallback
      await _tryLastKnown();
    }
  }

  Future<void> _tryLastKnown() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        state = lastKnown;
      }
    } catch (_) {
      // Complete failure - state stays null
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