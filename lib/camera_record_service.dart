import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

// Handles silent video recording in the background without showing any camera preview.
class CameraRecordService {
  static CameraController? _controller;
  static bool isRecording = false;

  // Grabs the back camera and starts recording directly to local storage
  static Future<void> startStealthRecording() async {
    if (isRecording) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer rear camera so it captures surroundings if the screen is faced down or held
      CameraDescription selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Use medium resolution to avoid heavy battery and memory usage
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      await _controller!.startVideoRecording();
      isRecording = true;
    } catch (e) {
      isRecording = false;
    }
  }

  // Stops recording and moves the raw video file into the app's persistent storage
  static Future<File?> stopRecording() async {
    if (!isRecording || _controller == null) return null;

    try {
      XFile videoFile = await _controller!.stopVideoRecording();
      isRecording = false;

      // Save to application documents folder
      final appDir = await getApplicationDocumentsDirectory();
      final String targetPath =
          '${appDir.path}/evidence_${DateTime.now().millisecondsSinceEpoch}.mp4';

      File savedVideo = await File(videoFile.path).copy(targetPath);

      // Clean up controller resources
      await _controller?.dispose();
      _controller = null;

      return savedVideo;
    } catch (e) {
      isRecording = false;
      await _controller?.dispose();
      _controller = null;
      return null;
    }
  }
}