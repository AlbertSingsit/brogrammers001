import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

// Listens to accelerometer stream and detects a 2-shake gesture.
class ShakeDetectorService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  final Function() onDoubleShake;

  ShakeDetectorService({required this.onDoubleShake});

  void startListening() {
    // Lowered from 17.5 to 14.5 so you don't have to throw your arm out to trigger it
    const double threshold = 14.5;
    // Both shakes must happen within 2 seconds
    const Duration resetWindow = Duration(seconds: 2);
    // Minimum 250ms gap between shakes so 1 back-and-forth motion counts cleanly
    const Duration minGapBetweenShakes = Duration(milliseconds: 250);

    _subscription = userAccelerometerEventStream().listen((event) {
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > threshold) {
        DateTime now = DateTime.now();

        // Ignore micro-spikes from the exact same shake movement
        if (_lastShakeTime != null &&
            now.difference(_lastShakeTime!) < minGapBetweenShakes) {
          return;
        }

        // Reset count to 1 if too much time passed since the first shake
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!) > resetWindow) {
          _shakeCount = 1;
        } else {
          _shakeCount++;
        }

        _lastShakeTime = now;

        // Trigger emergency on 2 shakes
        if (_shakeCount >= 2) {
          _shakeCount = 0;
          onDoubleShake();
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }
}
