import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

// Listens to accelerometer stream and detects a 2-shake gesture globally.
class ShakeDetectorService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  final Function() onDoubleShake;

  ShakeDetectorService({required this.onDoubleShake});

  void startListening() {
    // Optimal threshold for pocket or hand shaking without false triggers
    const double threshold = 13.5;
    // Window to complete the double shake
    const Duration resetWindow = Duration(milliseconds: 2200);
    // Debounce gap between individual shakes
    const Duration minGapBetweenShakes = Duration(milliseconds: 200);

    _subscription = userAccelerometerEventStream().listen((event) {
      // Use userAccelerometer (gravity stripped out) for pure motion tracking
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > threshold) {
        DateTime now = DateTime.now();

        if (_lastShakeTime != null &&
            now.difference(_lastShakeTime!) < minGapBetweenShakes) {
          return;
        }

        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!) > resetWindow) {
          _shakeCount = 1;
        } else {
          _shakeCount++;
        }

        _lastShakeTime = now;

        if (_shakeCount >= 2) {
          _shakeCount = 0;
          _lastShakeTime = null;
          onDoubleShake();
        }
      }
    }, onError: (e) {
      // Handle sensor stream drops silently
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
