import 'package:flutter/material.dart';

class EmergencyState extends ChangeNotifier {
  static final EmergencyState instance = EmergencyState._internal();
  EmergencyState._internal();

  bool isEmergencyActive = false;

  void triggerEmergency() {
    if (!isEmergencyActive) {
      isEmergencyActive = true;
      notifyListeners();
    }
  }

  void disarm() {
    if (isEmergencyActive) {
      isEmergencyActive = false;
      notifyListeners();
    }
  }
}