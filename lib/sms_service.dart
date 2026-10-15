import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sends emergency SMS through the native cellular network without needing internet.
class SmsService {
  static final Telephony telephony = Telephony.instance;

  static Future<bool> sendEmergencyAlert(String mapUrl) async {
    try {
      // Pull saved phone number from local device storage
      final prefs = await SharedPreferences.getInstance();
      final contact = prefs.getString('emergency_contact');

      // Do nothing if no number has been configured yet
      if (contact == null || contact.trim().isEmpty) return false;

      // Format danger alert message with location payload
      String message =
          "EMERGENCY ALERT: I AM IN DANGER! Please send help immediately or alert the authorities. My live GPS location: $mapUrl";

      // Direct native SMS dispatch
      await telephony.sendSms(
        to: contact.trim(),
        message: message,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}