import 'package:geolocator/geolocator.dart';

// Reads raw satellite coordinates directly from the phone GPS chip.
class LocationService {
  static Future<String?> getCoordinatesUrl() async {
    try {
      // Check if location hardware is turned on
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      // Query GPS hardware. Keep timeout short so the SMS is not delayed if indoors.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      // Return a ready-to-click Google Maps link
      return "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    } catch (e) {
      return null;
    }
  }
}