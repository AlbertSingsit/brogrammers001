import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'emergency_state.dart';
import 'shake_detector.dart';
import 'location_service.dart';
import 'sms_service.dart';
import 'camera_record_service.dart';
import 'contacts_screen.dart';
import 'decoy_torch_screen.dart';

void main() async {
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

class MainControllerWrapper extends StatefulWidget {
  const MainControllerWrapper({super.key});

  @override
  State<MainControllerWrapper> createState() => _MainControllerWrapperState();
}

class _MainControllerWrapperState extends State<MainControllerWrapper> {
  late ShakeDetectorService _uiShakeDetector;
  final EmergencyState _state = EmergencyState.instance;

  @override
  void initState() {
    super.initState();

    _uiShakeDetector = ShakeDetectorService(
      onDoubleShake: _handleEmergencyTrigger,
    );
    _uiShakeDetector.startListening();

    _state.addListener(_onEmergencyStateChanged);
  }

  void _onEmergencyStateChanged() {
    if (_state.isEmergencyActive && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DecoyTorchScreen()),
      );
    }
  }

  Future<void> _handleEmergencyTrigger() async {
    if (_state.isEmergencyActive) return;

    _state.triggerEmergency();

    await CameraRecordService.startStealthRecording();

    Position? pos = await LocationService.getBestPosition();
    String locationUrl = pos != null
        ? "${LocationService.formatMapUrl(pos)} (±${pos.accuracy.toInt()}m)"
        : "GPS location unavailable";

    await SmsService.sendEmergencyAlert(locationUrl);
  }

  @override
  void dispose() {
    _uiShakeDetector.stopListening();
    _state.removeListener(_onEmergencyStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ContactsScreen();
  }
}
