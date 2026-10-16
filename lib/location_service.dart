import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static StreamSubscription<Position>? _backgroundStream;
  static Position? _latestPinpointPosition;

  // Keeps the app, Shake Detector, and GPS awake in the background globally
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
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Safe Evidence Active",
          notificationText:
              "Emergency shake and location protection is running",
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      _backgroundStream = Geolocator.getPositionStream(
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
      if (_latestPinpointPosition != null) {
        final age = DateTime.now().difference(
          _latestPinpointPosition!.timestamp,
        );
        if (age.inMinutes < 2) {
          return _latestPinpointPosition;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      _latestPinpointPosition = pos;
      return pos;
    } catch (_) {
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
