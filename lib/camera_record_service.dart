import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class CameraRecordService {
  static CameraController? _controller;
  static bool isRecording = false;
  static bool isTorchOn = false;

  static Future<Directory> getEvidenceDirectory() async {
    final Directory? extDir = await getExternalStorageDirectory();
    return extDir ?? await getApplicationDocumentsDirectory();
  }

  // Returns all recorded .mp4 files sorted newest first
  static Future<List<File>> getSavedVideos() async {
    try {
      final dir = await getEvidenceDirectory();
      if (!await dir.exists()) return [];

      final List<FileSystemEntity> entities = dir.listSync();
      final List<File> videos = entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.mp4'))
          .toList();

      videos.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      return videos;
    } catch (e) {
      return [];
    }
  }

  // Copies a video file into the public Android Downloads folder so Gallery/Files can open it
  static Future<String?> exportToPublicDownloads(File videoFile) async {
    try {
      final Directory publicDownloads = Directory(
        '/storage/emulated/0/Download',
      );
      if (await publicDownloads.exists()) {
        final String fileName = videoFile.path
            .split(Platform.pathSeparator)
            .last;
        final String publicPath = '${publicDownloads.path}/SafeShake_$fileName';
        await videoFile.copy(publicPath);
        return publicPath;
      }
    } catch (_) {}
    return null;
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

        final Directory baseDir = await getEvidenceDirectory();
        final String fileName =
            'evidence_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final String targetPath = '${baseDir.path}/$fileName';

        savedVideo = await File(videoFile.path).copy(targetPath);

        // Also automatically copy to public Downloads folder if Android allows it
        await exportToPublicDownloads(savedVideo);
      }
    } catch (e) {
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
