import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static final Telephony telephony = Telephony.instance;

  static Future<bool> sendEmergencyAlert(String mapUrl) async {
    try {
      // Ensure SMS permission is granted
      if (!await Permission.sms.isGranted) {
        await Permission.sms.request();
      }

      // Also request telephony's native permission check
      final bool? permissionsGranted =
          await telephony.requestPhoneAndSmsPermissions;
      if (permissionsGranted == false) {
        debugPrint("SMS Error: Phone/SMS permissions denied");
      }

      // Pull saved phone number from local device storage
      final prefs = await SharedPreferences.getInstance();
      final contact = prefs.getString('emergency_contact');

      if (contact == null || contact.trim().isEmpty || contact == "None") {
        debugPrint("SMS Error: No emergency contact saved");
        return false;
      }

      String message =
          "EMERGENCY ALERT: I AM IN DANGER! Please send help immediately or alert the authorities. My live GPS location: $mapUrl";

      await telephony.sendSms(
        to: contact.trim(),
        message: message,
        statusListener: (SendStatus status) {
          debugPrint("SMS Status: $status");
        },
      );
      debugPrint("SMS Dispatched to ${contact.trim()}");
      return true;
    } catch (e) {
      debugPrint("SMS Failed with error: $e");
      return false;
    }
  }
}
