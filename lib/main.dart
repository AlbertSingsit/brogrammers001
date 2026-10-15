import 'package:flutter/material.dart';
import 'emergency_state.dart';
import 'shake_detector.dart';
import 'location_service.dart';
import 'sms_service.dart';
import 'camera_record_service.dart';
import 'contacts_screen.dart';
import 'decoy_torch_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeShakeApp());
}

class SafeShakeApp extends StatelessWidget {
  const SafeShakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeShake',
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blueGrey),
      home: const MainControllerWrapper(),
    );
  }
}

// Wrapper that listens to hardware shake events across the app lifecycle
class MainControllerWrapper extends StatefulWidget {
  const MainControllerWrapper({super.key});

  @override
  State<MainControllerWrapper> createState() => _MainControllerWrapperState();
}

class _MainControllerWrapperState extends State<MainControllerWrapper> {
  late ShakeDetectorService _shakeDetector;
  final EmergencyState _state = EmergencyState.instance;

  @override
  void initState() {
    super.initState();

    // Start listening for triple shake immediately
    _shakeDetector = ShakeDetectorService(
      onTripleShake: _handleEmergencyTrigger,
    );
    _shakeDetector.startListening();

    // Watch emergency state to switch to decoy UI when triggered
    _state.addListener(_onEmergencyStateChanged);
  }

  // Push the decoy screen as soon as emergency state turns true
  void _onEmergencyStateChanged() {
    if (_state.isEmergencyActive && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DecoyTorchScreen()),
      );
    }
  }

  // Main emergency execution sequence
  Future<void> _handleEmergencyTrigger() async {
    // Avoid double triggers if already in emergency mode
    if (_state.isEmergencyActive) return;

    _state.triggerEmergency();

    // 1. Fire up silent video recording
    CameraRecordService.startStealthRecording();

    // 2. Fetch satellite coordinates
    String? coordinates = await LocationService.getCoordinatesUrl();
    String locationUrl = coordinates ?? "GPS location unavailable (Timed out)";

    // 3. Dispatch offline SMS with danger notice and map link
    await SmsService.sendEmergencyAlert(locationUrl);
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    _state.removeListener(_onEmergencyStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ContactsScreen();
  }
}
