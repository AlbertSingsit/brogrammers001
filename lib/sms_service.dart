import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  static final Telephony telephony = Telephony.instance;
  static const MethodChannel _nativeSmsChannel = MethodChannel('safeshake/sms');

  static Future<bool> sendEmergencyAlert(String mapUrl) async {
    try {
      // 1. Request SMS and Phone permissions
      var smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        smsStatus = await Permission.sms.request();
      }
      if (!await Permission.phone.isGranted) {
        await Permission.phone.request();
      }

      // 2. Read saved emergency contact
      final prefs = await SharedPreferences.getInstance();
      String? contact = prefs.getString('emergency_contact');

      if (contact == null || contact.trim().isEmpty || contact == "None") {
        debugPrint("SMS Error: No emergency contact saved.");
        return false;
      }

      String cleanPhone = contact.trim().replaceAll(RegExp(r'\s+'), '');

      String message =
          "EMERGENCY ALERT: I AM IN DANGER! Please send help immediately. My live GPS location: $mapUrl";

      // 3. Primary Method: Direct Native Android SmsManager (Android 12-15 safe)
      try {
        final bool? sentNative = await _nativeSmsChannel.invokeMethod<bool>(
          'sendDirectSms',
          {'phone': cleanPhone, 'message': message},
        );
        if (sentNative == true) {
          debugPrint(
            "SMS sent successfully via Native SmsManager to $cleanPhone",
          );
          return true;
        }
      } catch (nativeErr) {
        debugPrint(
          "Native SMS channel error, falling back to telephony: $nativeErr",
        );
      }

      // 4. Fallback Method: telephony plugin WITHOUT statusListener (avoids PendingIntent crash)
      await telephony.sendSms(
        to: cleanPhone,
        message: message,
        isMultipart: true,
      );
      debugPrint("SMS sent via Telephony fallback to $cleanPhone");
      return true;
    } catch (e) {
      debugPrint("SMS Failed completely: $e");
      return false;
    }
  }
}
