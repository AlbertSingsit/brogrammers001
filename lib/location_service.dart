import 'package:geolocator/geolocator.dart';

class LocationService {
  // Pre-warms the GPS hardware when the app opens so satellite lock is ready
  static Future<void> warmUpGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {}
  }

  static Future<String?> getCoordinatesUrl() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      Position? position;

      // Tier 1: Try pinpoint satellite GPS first (5-10m accuracy)
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        // Tier 2: Fallback to high accuracy if indoor roof blocks navigation lock
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 6),
          );
        } catch (_) {
          // Tier 3: Last known system coordinates so SMS never fails
          position = await Geolocator.getLastKnownPosition();
        }
      }

      if (position == null) return null;

      return "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    } catch (e) {
      return null;
    }
  }
}
