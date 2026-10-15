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
  static bool _isSwitching = false;
  static CameraLensDirection _currentLens = CameraLensDirection.back;

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
      debugPrint("DCIM folder access error: $e");
      return await getApplicationDocumentsDirectory();
    }
  }

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
                final String fileName =
                    entity.path.split(Platform.pathSeparator).last;
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

  static Future<String?> exportToPublicDownloads(File videoFile) async {
    try {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      final String fileName = videoFile.path.split(Platform.pathSeparator).last;
      String? savedPath;

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

  // Helper to save a recorded XFile clip to internal storage & DCIM
  static Future<File?> _saveRecordedClip(
      XFile videoFile, String lensTag) async {
    try {
      final String fileName =
          'SafeShake_${lensTag}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final Directory internalDir = await getApplicationDocumentsDirectory();
      final File internalCopy = await File(
        videoFile.path,
      ).copy('${internalDir.path}/$fileName');

      final String? dcimPath = await exportToPublicDownloads(internalCopy);
      if (dcimPath != null && await File(dcimPath).exists()) {
        return File(dcimPath);
      }
      return internalCopy;
    } catch (e) {
      debugPrint("Save clip error: $e");
      return null;
    }
  }

  // Starts stealth recording (ALWAYS defaults to Back Camera first)
  static Future<void> startStealthRecording() async {
    if (isRecording || _isSwitching) return;

    _currentLens = CameraLensDirection.back;
    await _initAndRecord(_currentLens);
  }

  static Future<void> _initAndRecord(CameraLensDirection direction) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      CameraDescription selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();

      // Only set flash mode on the back camera (front camera throws hardware errors)
      if (direction == CameraLensDirection.back) {
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
      isTorchOn = false;

      await _controller!.startVideoRecording();
      isRecording = true;
    } catch (e) {
      debugPrint("Init and record error: $e");
      isRecording = false;
    }
  }

  // Safely saves current clip, flips camera lens, and continues recording immediately
  static Future<void> switchCamera() async {
    if (_isSwitching) return;
    _isSwitching = true;

    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      final String previousLensTag =
          _currentLens == CameraLensDirection.back ? 'BACK' : 'FRONT';

      // 1. Stop current recording and save the clip so no evidence is lost
      if (_controller != null) {
        try {
          if (isTorchOn && _currentLens == CameraLensDirection.back) {
            await _controller!.setFlashMode(FlashMode.off);
            isTorchOn = false;
          }
          if (isRecording && _controller!.value.isRecordingVideo) {
            XFile clip = await _controller!.stopVideoRecording();
            isRecording = false;
            // Save the recorded segment in the background
            _saveRecordedClip(clip, previousLensTag);
          }
        } catch (e) {
          debugPrint("Error stopping previous camera during switch: $e");
        } finally {
          await _controller!.dispose();
          _controller = null;
        }
      }

      // 2. Give Android CameraX 250ms to fully release hardware encoders
      await Future.delayed(const Duration(milliseconds: 250));

      // 3. Toggle lens direction and start recording the new stream
      _currentLens = _currentLens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      await _initAndRecord(_currentLens);
    } catch (e) {
      debugPrint("Switch camera error: $e");
    } finally {
      _isSwitching = false;
    }
  }

  static Future<bool> setTorch(bool enable) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isSwitching) {
      return false;
    }
    try {
      if (_currentLens == CameraLensDirection.front) return false;
      await _controller!.setFlashMode(enable ? FlashMode.torch : FlashMode.off);
      isTorchOn = enable;
      return isTorchOn;
    } catch (e) {
      return isTorchOn;
    }
  }

  static Future<File?> stopRecording() async {
    // Wait briefly if user disarms while a camera switch is in progress
    while (_isSwitching) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (_controller == null) return null;

    File? savedVideo;
    try {
      if (isTorchOn && _currentLens == CameraLensDirection.back) {
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
        isTorchOn = false;
      }

      if (isRecording && _controller!.value.isRecordingVideo) {
        XFile videoFile = await _controller!.stopVideoRecording();
        isRecording = false;

        final String lensTag =
            _currentLens == CameraLensDirection.back ? 'BACK' : 'FRONT';
        savedVideo = await _saveRecordedClip(videoFile, lensTag);
      }
    } catch (e) {
      debugPrint("Stop recording error: $e");
      isRecording = false;
    } finally {
      await _controller?.dispose();
      _controller = null;
      isRecording = false;
      isTorchOn = false;
      _currentLens = CameraLensDirection.back; // Reset to back for next time
    }
    return savedVideo;
  }
}
