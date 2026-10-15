import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'emergency_state.dart';
import 'camera_record_service.dart';

// Decoy interface that masks the app as an ordinary flashlight.
// Tapping the power button 3 times quickly serves as the secret disarm gesture.
class DecoyTorchScreen extends StatefulWidget {
  const DecoyTorchScreen({super.key});

  @override
  State<DecoyTorchScreen> createState() => _DecoyTorchScreenState();
}

class _DecoyTorchScreenState extends State<DecoyTorchScreen> {
  bool _isTorchOn = false;
  int _clickCount = 0;
  DateTime? _lastClickTime;

  @override
  void initState() {
    super.initState();
    // Turn on flashlight immediately when screen opens to maintain disguise
    _enableTorch();
  }

  Future<void> _enableTorch() async {
    try {
      await TorchLight.enableTorch();
      setState(() => _isTorchOn = true);
    } catch (_) {}
  }

  // Toggles the LED light and registers click timing for disarm
  Future<void> _toggleTorch() async {
    _handleSecretDisarm();

    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
        setState(() => _isTorchOn = false);
      } else {
        await TorchLight.enableTorch();
        setState(() => _isTorchOn = true);
      }
    } catch (_) {}
  }

  // Tracks rapid clicks. 3 clicks within 1.5 seconds disarms the emergency.
  Future<void> _handleSecretDisarm() async {
    DateTime now = DateTime.now();

    if (_lastClickTime == null ||
        now.difference(_lastClickTime!) > const Duration(milliseconds: 1500)) {
      _clickCount = 1;
    } else {
      _clickCount++;
    }

    _lastClickTime = now;

    if (_clickCount >= 3) {
      _clickCount = 0;
      await TorchLight.disableTorch();

      // Stop recording and save the video file
      await CameraRecordService.stopRecording();

      // Reset application emergency state
      EmergencyState.instance.disarm();

      // Return to main screen
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    TorchLight.disableTorch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents attacker or bystander from escaping screen using the back button
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on, size: 70, color: Colors.white24),
              const SizedBox(height: 50),
              // Main flashlight toggle button
              IconButton(
                iconSize: 110,
                icon: Icon(
                  _isTorchOn ? Icons.power_settings_new : Icons.power_settings_new_outlined,
                  color: _isTorchOn ? Colors.amberAccent : Colors.grey[700],
                ),
                onPressed: _toggleTorch,
              ),
              const SizedBox(height: 24),
              Text(
                _isTorchOn ? "TORCH ON" : "TORCH OFF",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}