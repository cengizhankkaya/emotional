import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_model.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();

  factory DownloadService() => _instance;

  DownloadService._internal();

  final _taskController = StreamController<DownloadTaskOption>.broadcast();

  Stream<DownloadTaskOption> get taskStream => _taskController.stream;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure notifications for a professional experience
    await FileDownloader().configureNotificationForGroup(
      FileDownloader.defaultGroup,
      // For running tasks:
      running: const TaskNotification(
        '{displayName}',
        '⬇️ {networkSpeed}   ⏱️ {timeRemaining}   💾 {progress}',
      ),
      // For complete tasks:
      complete: const TaskNotification(
        'İndirme Tamamlandı',
        '{displayName} başarıyla indirildi.',
      ),
      // For failed tasks:
      error: const TaskNotification(
        'İndirme Başarısız',
        '{displayName} indirilemedi.',
      ),
      // For paused tasks:
      paused: const TaskNotification(
        'İndirme Duraklatıldı',
        '{displayName} bekliyor.',
      ),
      progressBar: true,
      tapOpensFile: true,
    );

    // Listen to updates
    FileDownloader().updates.listen((update) {
      if (update is TaskStatusUpdate) {
        _taskController.add(DownloadTaskOption.fromUpdate(update));
      } else if (update is TaskProgressUpdate) {
        _taskController.add(DownloadTaskOption.fromProgress(update));
      }
    });

    // Request necessary permissions immediately
    await requestPermissions();

    _isInitialized = true;
  }

  /// Requests necessary permissions for a "professional" background download experience.
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // 1. Notifications (required for background_downloader foreground service)
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        await Permission.notification.request();
      }

      // 2. Storage (optional for internal storage, but good to have)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }

      // 3. Battery Optimization
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  void dispose() {
    _taskController.close();
  }

  Future<String?> download({
    required String url,
    required String filename,
    Map<String, String>? headers,
    String?
    savedDir, // Kept for API compatibility, but usually handled by BaseDirectory
    bool showNotification = true,
    bool openFileFromNotification = true,
  }) async {
    // Create the task
    // Using BaseDirectory.applicationDocuments as the default safe storage
    // Note: savedDir argument is largely ignored to strictly follow BaseDirectory best practices,
    // but we can map it if it matches known paths. For now, defaulting to applicationDocuments.
    // Note: Google Drive does not support Range requests with some auth methods, causing "Server does not accept ranges" error.
    // Switching to standard DownloadTask (single stream) to ensure compatibility.
    final task = DownloadTask(
      url: url,
      filename: filename,
      headers: headers ?? {},
      baseDirectory: BaseDirectory.applicationDocuments,
      directory: '', // Save at root of BaseDirectory
      updates: Updates.statusAndProgress, // Crucial for progress stream
      retries: 5, // Increased retries for reliability
      allowPause:
          false, // Disabled to prevent "Server does not accept ranges" error on Drive
      metaData: 'video_download', // Optional metadata
      priority: 0, // 0 = Priority/UIDT for Android 14+
      displayName: filename, // For notification
    );

    final submitted = await FileDownloader().enqueue(task);

    if (submitted) {
      return task.taskId;
    } else {
      debugPrint('DownloadService: Failed to enqueue task');
      return null;
    }
  }

  // Basic wrappers needed for compatibility
  Future<void> pause(String taskId) async {
    // background_downloader requires the task object to pause.
    // We can try to reconstruct a minimal task or fetch it if we stored it.
    // For now, simpler implementation: cancel. Pause/Resume needs state tracking.
    // A better approach is to use FileDownloader().taskForId(taskId) but that's async and optional.
    final task = await FileDownloader().taskForId(taskId);
    if (task != null && task is DownloadTask) {
      await FileDownloader().pause(task);
    }
  }

  Future<void> resume(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    if (task != null && task is DownloadTask) {
      await FileDownloader().resume(task);
    }
  }

  Future<void> cancel(String taskId) async {
    await FileDownloader().cancelTaskWithId(taskId);
  }

  Future<void> retry(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    if (task != null && task is DownloadTask) {
      // FileDownloader doesn't have a direct 'retry' on the task object same as flutter_downloader
      // We essentially re-enqueue.
      FileDownloader().enqueue(task);
    }
  }

  Future<void> open(String taskId) async {
    final task = await FileDownloader().taskForId(taskId);
    if (task != null) {
      await FileDownloader().openFile(task: task);
    }
  }
}
