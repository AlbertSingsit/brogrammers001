import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Setup screen to configure emergency contact number and request permissions.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _controller = TextEditingController();
  String _savedNumber = "None";

  @override
  void initState() {
    super.initState();
    _loadSavedNumber();
    _requestRequiredPermissions();
  }

  // Ask for all runtime permissions upfront on first open
  Future<void> _requestRequiredPermissions() async {
    await [
      Permission.sms,
      Permission.location,
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  // Load previously saved contact from disk
  Future<void> _loadSavedNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNumber = prefs.getString('emergency_contact') ?? "None";
      _controller.text = _savedNumber == "None" ? "" : _savedNumber;
    });
  }

  // Persist contact number into local disk storage
  Future<void> _saveContact() async {
    if (_controller.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contact', _controller.text.trim());
    setState(() => _savedNumber = _controller.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Emergency Contact Saved Successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafeShake Settings"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Trusted Emergency Number",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "+1234567890",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saveContact,
              child: const Text("Save Number"),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Active Contact: $_savedNumber",
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            const Text(
              "Triple shake anywhere triggers stealth mode.\n3 quick taps on the decoy torch button exits.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}