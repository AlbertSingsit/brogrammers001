import 'dart:async';
import 'package:flutter/foundation.dart';
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
            _latestPinpointPosition = pos;
          });
    } catch (e) {
      debugPrint("Location stream error: $e");
    }
  }

  static Future<Position?> getBestPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 1. Return recent cached stream position if available (< 2 mins old)
      if (_latestPinpointPosition != null) {
        final age = DateTime.now().difference(
          _latestPinpointPosition!.timestamp,
        );
        if (age.inMinutes < 2) {
          return _latestPinpointPosition;
        }
      }

      // 2. Try fast high-accuracy GPS lock (4-second timeout)
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      _latestPinpointPosition = pos;
      return pos;
    } catch (_) {
      // 3. Immediate fallback to last known device location
      try {
        return _latestPinpointPosition ??
            await Geolocator.getLastKnownPosition();
      } catch (_) {
        return _latestPinpointPosition;
      }
    }
  }

  static String formatMapUrl(Position pos) {
    return "https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
  }
}
