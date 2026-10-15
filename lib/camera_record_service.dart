import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

class CameraRecordService {
  static CameraController? _controller;
  static bool isRecording = false;
  static bool isTorchOn = false;

  // Primary public DCIM folder: /storage/emulated/0/DCIM/SafeShake
  static final Directory dcimDir = Directory(
    '/storage/emulated/0/DCIM/SafeShake',
  );

  static Future<Directory> getEvidenceDirectory() async {
    try {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }
      return dcimDir;
    } catch (e) {
      debugPrint("DCIM folder access error, using app docs: $e");
      return await getApplicationDocumentsDirectory();
    }
  }

  // Returns all recorded .mp4 files from DCIM/SafeShake (plus any older app recordings)
  static Future<List<File>> getSavedVideos() async {
    try {
      final List<File> videos = [];
      final Directory docDir = await getApplicationDocumentsDirectory();
      final Directory? extDir = await getExternalStorageDirectory();

      final List<Directory> dirsToCheck = [
        dcimDir,
        docDir,
        if (extDir != null) extDir,
      ];

      final Set<String> seenNames = {};
      for (final dir in dirsToCheck) {
        try {
          if (await dir.exists()) {
            final entities = dir.listSync();
            for (final entity in entities) {
              if (entity is File && entity.path.endsWith('.mp4')) {
                final String fileName = entity.path
                    .split(Platform.pathSeparator)
                    .last;
                if (!seenNames.contains(fileName)) {
                  seenNames.add(fileName);
                  videos.add(entity);
                }
              }
            }
          }
        } catch (_) {}
      }

      videos.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      return videos;
    } catch (e) {
      return [];
    }
  }

  // Saves directly into /storage/emulated/0/DCIM/SafeShake AND indexes it in Gallery
  static Future<String?> exportToPublicDownloads(File videoFile) async {
    try {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      final String fileName = videoFile.path.split(Platform.pathSeparator).last;
      String? savedPath;

      // 1. Copy directly into /storage/emulated/0/DCIM/SafeShake/
      try {
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        final String targetDcimPath = '${dcimDir.path}/$fileName';
        if (videoFile.path != targetDcimPath) {
          await videoFile.copy(targetDcimPath);
        }
        savedPath = targetDcimPath;
      } catch (e) {
        debugPrint("Direct DCIM copy error: $e");
      }

      // 2. Also register with Android MediaStore so Gallery/Google Photos displays it immediately
      try {
        await Gal.putVideo(videoFile.path, album: 'SafeShake');
        savedPath ??= '/storage/emulated/0/DCIM/SafeShake/$fileName';
      } catch (e) {
        debugPrint("Gal MediaStore error: $e");
      }

      return savedPath;
    } catch (e) {
      debugPrint("Export error: $e");
      return null;
    }
  }

  static Future<void> startStealthRecording() async {
    if (isRecording) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      CameraDescription selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);
      isTorchOn = false;

      await _controller!.startVideoRecording();
      isRecording = true;
    } catch (e) {
      isRecording = false;
    }
  }

  static Future<bool> setTorch(bool enable) async {
    if (_controller == null || !_controller!.value.isInitialized) return false;
    try {
      await _controller!.setFlashMode(enable ? FlashMode.torch : FlashMode.off);
      isTorchOn = enable;
      return isTorchOn;
    } catch (e) {
      return isTorchOn;
    }
  }

  static Future<File?> stopRecording() async {
    if (_controller == null) return null;

    File? savedVideo;
    try {
      if (isTorchOn) {
        await _controller!.setFlashMode(FlashMode.off);
        isTorchOn = false;
      }

      if (isRecording && _controller!.value.isRecordingVideo) {
        XFile videoFile = await _controller!.stopVideoRecording();
        isRecording = false;

        final String fileName =
            'SafeShake_${DateTime.now().millisecondsSinceEpoch}.mp4';

        // 1. Save internal copy first so the app UI always has instant access
        final Directory internalDir = await getApplicationDocumentsDirectory();
        final File internalCopy = await File(
          videoFile.path,
        ).copy('${internalDir.path}/$fileName');
        savedVideo = internalCopy;

        // 2. Immediately export to /storage/emulated/0/DCIM/SafeShake and Gallery
        final String? dcimPath = await exportToPublicDownloads(internalCopy);
        if (dcimPath != null && await File(dcimPath).exists()) {
          savedVideo = File(dcimPath);
        }
      }
    } catch (e) {
      debugPrint("Stop recording error: $e");
      isRecording = false;
    } finally {
      await _controller?.dispose();
      _controller = null;
      isRecording = false;
      isTorchOn = false;
    }
    return savedVideo;
  }
}
