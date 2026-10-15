import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static const MethodChannel _nativeSmsChannel = MethodChannel('safeshake/sms');

  static Future<bool> sendEmergencyAlert(String mapUrl) async {
    try {
      // 1. Ensure permissions are granted
      if (!await Permission.sms.isGranted) {
        await Permission.sms.request();
      }

      // 2. Get saved contact
      final prefs = await SharedPreferences.getInstance();
      String? contact = prefs.getString('emergency_contact');

      if (contact == null || contact.trim().isEmpty || contact == "None") {
        debugPrint("SMS Error: No emergency contact saved.");
        return false;
      }

      String cleanPhone = contact.trim().replaceAll(RegExp(r'\s+'), '');
      String message = "EMERGENCY ALERT: I am in danger! My location: $mapUrl";

      // 3. Directly invoke native Android SmsManager via MainActivity channel
      final bool? sent = await _nativeSmsChannel.invokeMethod<bool>(
        'sendDirectSms',
        {
          'phone': cleanPhone,
          'message': message,
        },
      );

      debugPrint("SMS sent status: $sent");
      return sent ?? false;
    } catch (e) {
      debugPrint("SMS failed: $e");
      return false;
    }
  }
}
