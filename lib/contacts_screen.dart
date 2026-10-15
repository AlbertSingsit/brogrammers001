import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'camera_record_service.dart';
import 'location_service.dart';
import 'emergency_state.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _controller = TextEditingController();
  String _savedNumber = "None";
  List<File> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadSavedNumber();
    _initPermissionsAndWarmUp();
    _loadRecordings();

    EmergencyState.instance.addListener(_onEmergencyStateChanged);
  }

  void _onEmergencyStateChanged() {
    if (!EmergencyState.instance.isEmergencyActive && mounted) {
      Future.delayed(const Duration(milliseconds: 600), _loadRecordings);
    }
  }

  Future<void> _initPermissionsAndWarmUp() async {
    await [
      Permission.sms,
      Permission.phone,
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.storage,
      Permission.videos,
      Permission.contacts,
    ].request();

    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    await Permission.locationAlways.request();
    await Permission.ignoreBatteryOptimizations.request();

    await LocationService.startAlwaysOnProtection();
    await _loadRecordings();
  }

  Future<void> _loadSavedNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNumber = prefs.getString('emergency_contact') ?? "None";
      _controller.text = _savedNumber == "None" ? "" : _savedNumber;
    });
  }

  Future<void> _loadRecordings() async {
    final videos = await CameraRecordService.getSavedVideos();
    if (mounted) {
      setState(() => _recordings = videos);
    }
  }

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

  Future<void> _removeContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emergency_contact');
    setState(() {
      _savedNumber = "None";
      _controller.text = "";
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Emergency Contact Removed")),
      );
    }
  }

  Future<void> _pickContactFromPhone() async {
    try {
      // Explicitly check and request contact permission via permission_handler
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final Contact? contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null && fullContact.phones.isNotEmpty) {
            String phoneNumber = fullContact.phones.first.number;
            setState(() {
              _controller.text = phoneNumber;
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Contacts permission denied in settings")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not pick contact: $e")),
        );
      }
    }
  }

  void _playVideo(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPreviewScreen(videoFile: file)),
    );
  }

  Future<void> _exportVideo(File file) async {
    final path = await CameraRecordService.exportToPublicDownloads(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null
              ? "Saved to DCIM & Gallery:\n$path"
              : "Failed to save to DCIM. Check storage permissions.",
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _deleteVideo(File file) async {
    try {
      await file.delete();
      await _loadRecordings();
    } catch (_) {}
  }

  String _formatFileDetails(File file) {
    final DateTime modified = file.lastModifiedSync();
    final double sizeMb = file.lengthSync() / (1024 * 1024);
    final String timeStr =
        "${modified.day}/${modified.month}/${modified.year} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}:${modified.second.toString().padLeft(2, '0')}";
    return "$timeStr  •  ${sizeMb.toStringAsFixed(2)} MB";
  }

  @override
  void dispose() {
    EmergencyState.instance.removeListener(_onEmergencyStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafeShake Settings"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Recordings",
            onPressed: _loadRecordings,
          ),
        ],
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
              decoration: InputDecoration(
                hintText: "+1234567890",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.contacts, color: Colors.blueGrey),
                  tooltip: "Pick from Contacts",
                  onPressed: _pickContactFromPhone,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[900],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveContact,
                    child: const Text("Save Number"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _removeContact,
                    child: const Text("Remove"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recorded Evidence (${_recordings.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadRecordings,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text("Refresh"),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _recordings.isEmpty
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "No recordings yet.\nTrigger a double-shake to capture evidence.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _recordings.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final File file = _recordings[index];
                        final String name =
                            file.path.split(Platform.pathSeparator).last;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _playVideo(file),
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade50,
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _formatFileDetails(file),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.download_for_offline_outlined,
                                  color: Colors.blueGrey,
                                ),
                                tooltip: "Save to DCIM/SafeShake",
                                onPressed: () => _exportVideo(file),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: "Delete",
                                onPressed: () => _deleteVideo(file),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Double shake anywhere triggers stealth mode.\n2 quick taps on the lightning icon exits.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final File videoFile;

  const VideoPreviewScreen({super.key, required this.videoFile});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _videoController;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _videoController.play();
        }
      }).catchError((e) {
        if (mounted) {
          setState(() => _errorMessage = "Could not play video: $e");
        }
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fileName =
        widget.videoFile.path.split(Platform.pathSeparator).last;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            : _initialized
                ? AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _videoController.value.isPlaying
                      ? _videoController.pause()
                      : _videoController.play();
                });
              },
              child: Icon(
                _videoController.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
