import 'package:flutter/material.dart';
import 'emergency_state.dart';
import 'camera_record_service.dart';

class DecoyTorchScreen extends StatefulWidget {
  const DecoyTorchScreen({super.key});

  @override
  State<DecoyTorchScreen> createState() => _DecoyTorchScreenState();
}

class _DecoyTorchScreenState extends State<DecoyTorchScreen> {
  // Flash is off by default; user decides when to turn it on
  bool _isTorchOn = false;
  bool _isDisarming = false;

  // Single tap on main button toggles the flashlight on/off
  Future<void> _toggleTorch() async {
    if (_isDisarming) return;
    bool nextState = !_isTorchOn;
    setState(() => _isTorchOn = nextState);
    await CameraRecordService.setTorch(nextState);
  }

  // Double tap on the top lightning icon stops recording and exits emergency mode
  Future<void> _stopAndDisarm() async {
    if (_isDisarming) return;
    setState(() => _isDisarming = true);

    // Stop video recording and release camera/flash hardware
    await CameraRecordService.stopRecording();

    // Reset emergency state so 2-shake can trigger it again
    EmergencyState.instance.disarm();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Battery calibration complete."),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Secret Disarm: Double-tap the lightning icon to exit stealth mode
                GestureDetector(
                  onDoubleTap: _stopAndDisarm,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Icon(
                      Icons.flash_on,
                      size: 70,
                      color: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                // Main flashlight toggle button
                IconButton(
                  iconSize: 110,
                  icon: Icon(
                    _isTorchOn
                        ? Icons.power_settings_new
                        : Icons.power_settings_new_outlined,
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
      ),
    );
  }
}
