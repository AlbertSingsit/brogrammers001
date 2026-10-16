import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Safe Evidence',
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
  static const MethodChannel _tileChannel = MethodChannel('safeshake/tile');
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

    // 1. Trigger when app is already running in memory/background
    _tileChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerFromTile') {
        _handleEmergencyTrigger();
      }
    });

    // 2. Trigger when app is cold-launched from the Quick Settings Tile
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final bool? shouldTrigger = await _tileChannel.invokeMethod<bool>(
          'checkPendingTrigger',
        );
        if (shouldTrigger == true) {
          _handleEmergencyTrigger();
        }
      } catch (_) {}
    });
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

    // 1. Dispatch SMS immediately using non-blocking Future
    LocationService.getBestPosition().then((pos) {
      String locationUrl = pos != null
          ? "${LocationService.formatMapUrl(pos)} (±${pos.accuracy.toInt()}m)"
          : "GPS location unavailable";
      SmsService.sendEmergencyAlert(locationUrl);
    });

    // 2. Start stealth recording immediately
    await CameraRecordService.startStealthRecording();
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
