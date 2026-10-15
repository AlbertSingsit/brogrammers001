import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

// Listens to accelerometer stream and counts high-G force spikes to detect a triple shake.
class ShakeDetectorService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  final Function() onTripleShake;

  ShakeDetectorService({required this.onTripleShake});

  void startListening() {
    // Acceleration threshold - 17.5 m/s^2 filters out normal walking or minor bumps
    const double threshold = 17.5;
    // Shake window - user must shake 3 times within 2 seconds
    const Duration resetWindow = Duration(seconds: 2);

    _subscription = userAccelerometerEventStream().listen((event) {
      // Calculate total force vector magnitude: sqrt(x^2 + y^2 + z^2)
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (acceleration > threshold) {
        DateTime now = DateTime.now();

        // If too much time passed since the last shake, reset count to 1
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > resetWindow) {
          _shakeCount = 1;
        } else {
          _shakeCount++;
        }

        _lastShakeTime = now;

        // If threshold hit 3 times in time window, trigger the callback
        if (_shakeCount >= 3) {
          _shakeCount = 0;
          onTripleShake();
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }
}