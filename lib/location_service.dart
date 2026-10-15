import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static StreamSubscription<Position>? _backgroundStream;
  static Position? _latestPinpointPosition;

  // Keeps the app, Shake Detector, and high-precision GPS awake in the background
  static Future<void> startAlwaysOnProtection() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      await _backgroundStream?.cancel();

      final AndroidSettings androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Battery Health Service",
          notificationText: "Monitoring power optimization in background",
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      _backgroundStream =
          Geolocator.getPositionStream(
            locationSettings: androidSettings,
          ).listen((Position pos) {
            if (_latestPinpointPosition == null ||
                pos.accuracy <= _latestPinpointPosition!.accuracy ||
                pos.accuracy <= 20.0) {
              _latestPinpointPosition = pos;
            }
          });
    } catch (_) {}
  }

  static Future<Position?> getBestPosition() async {
    try {
      if (_latestPinpointPosition != null &&
          _latestPinpointPosition!.accuracy <= 20.0) {
        final age = DateTime.now().difference(
          _latestPinpointPosition!.timestamp,
        );
        if (age.inMinutes < 2) {
          return _latestPinpointPosition;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 8),
      );
      _latestPinpointPosition = pos;
      return pos;
    } catch (_) {
      return _latestPinpointPosition ?? await Geolocator.getLastKnownPosition();
    }
  }

  static String formatMapUrl(Position pos) {
    return "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
  }
}
