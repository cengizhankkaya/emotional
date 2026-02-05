import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:emotional/core/services/drive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final ReceivePort _port = ReceivePort();
  bool _isInitialized = false;

  double? _downloadProgress;
  String? _downloadStatus;
  bool _isVideoDownloaded = false;
  File? _localVideoFile;
  String? _currentDownloadingFileName;
  String? _currentDownloadingFileId;
  List<drive.File> _downloadedVideos = [];

  Function(String)? _onError;

  // Getters
  double? get downloadProgress => _downloadProgress;
  String? get downloadStatus => _downloadStatus;
  bool get isVideoDownloaded => _isVideoDownloaded;
  File? get localVideoFile => _localVideoFile;
  String? get currentDownloadingFileName => _currentDownloadingFileName;
  List<drive.File> get downloadedVideos => _downloadedVideos;

  void setOnError(Function(String) callback) {
    _onError = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      await refreshTasks();
      return;
    }

    // Request permissions for background stability (Android)
    if (Platform.isAndroid) {
      final permissionService = PermissionService();
      await permissionService.requestNotificationPermission();
      await permissionService.requestStoragePermission();

      // Critical for Android 14+: Battery optimizations must be disabled for long background tasks
      bool isOptimizing =
          await ph.Permission.ignoreBatteryOptimizations.isDenied;
      debugPrint(
        'DownloadManager: Battery optimization is ${isOptimizing ? "ENABLED (Bad for background)" : "DISABLED (Good)"}',
      );

      if (isOptimizing) {
        await permissionService.requestIgnoreBatteryOptimizations();
      }
    }

    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    _isInitialized = true;

    // Task Recovery: Check for existing tasks
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      final lastTask = tasks.last;
      debugPrint(
        'DownloadManager: Found existing task: ${lastTask.taskId} - Status: ${lastTask.status}',
      );

      if (lastTask.status == DownloadTaskStatus.running ||
          lastTask.status == DownloadTaskStatus.enqueued) {
        _currentDownloadingFileId = null; // We might not know the ID from task
        _currentDownloadingFileName = lastTask.filename;
        _downloadProgress = lastTask.progress / 100.0;
        _downloadStatus = 'İndiriliyor...';
        notifyListeners();
      } else if (lastTask.status == DownloadTaskStatus.complete) {
        if (lastTask.filename != null) {
          await checkFileExists(lastTask.filename!);
        }
      }
    }
  }

  void _bindBackgroundIsolate() {
    final boolean = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!boolean) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'downloader_send_port',
      );
    }

    _port.listen((dynamic data) async {
      final String id = data[0];
      final DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1]);
      final int progress = data[2];

      debugPrint(
        'DownloadManager: Task $id - Status: $status, Progress: $progress',
      );

      if (status == DownloadTaskStatus.complete) {
        // Complete
        _downloadProgress = 1.0;
        _downloadStatus = 'İndirme tamamlandı.';
        debugPrint('DownloadManager: Download COMPLETED successfully.');
        _notifyStateChanged();

        // Delay clearing to let user see "Completed"
        Future.delayed(const Duration(seconds: 2), () {
          _downloadProgress = null;
          _downloadStatus = null;
          _currentDownloadingFileName = null;
          _notifyStateChanged();
        });

        // Optimistically update the list
        if (_currentDownloadingFileName != null &&
            _currentDownloadingFileId != null) {
          final newFile = drive.File()
            ..id = _currentDownloadingFileId
            ..name = _currentDownloadingFileName;

          // Check if already in list to avoid duplicates
          if (!_downloadedVideos.any((f) => f.id == newFile.id)) {
            _downloadedVideos.add(newFile);
          }
          checkFileExists(_currentDownloadingFileName!);
        }
      } else if (status == DownloadTaskStatus.failed ||
          status == DownloadTaskStatus.canceled) {
        _handleTaskEnd(id, status, progress);
      } else if (status == DownloadTaskStatus.paused) {
      } else if (status == DownloadTaskStatus.paused) {
        // Paused
        _downloadStatus = 'Durduruldu ($progress%)';
        debugPrint('DownloadManager: Download PAUSED (Status 6)');
        _notifyStateChanged();
      } else {
        // Running or Pending (status 1 or 2)
        _downloadProgress = progress / 100.0;
        _downloadStatus = 'İndiriliyor: $progress%';
        _notifyStateChanged();
      }
    });
  }

  Future<void> _handleTaskEnd(
    String id,
    DownloadTaskStatus status,
    int progress,
  ) async {
    final statusName = status == DownloadTaskStatus.failed
        ? 'Failed'
        : 'Canceled';
    debugPrint(
      'DownloadManager: Status $statusName received. Checking for file existence before reporting error...',
    );

    _downloadStatus = 'Dosya doğrulanıyor...';
    _notifyStateChanged();

    // 1. Immediate task-specific check
    final tasks = await FlutterDownloader.loadTasks();
    final currentTask = tasks?.where((t) => t.taskId == id).firstOrNull;

    if (currentTask != null && currentTask.filename != null) {
      final taskFile = File('${currentTask.savedDir}/${currentTask.filename}');
      if (await taskFile.exists()) {
        final len = await taskFile.length();
        if (len > 0) {
          _localVideoFile = taskFile;
          _isVideoDownloaded = true;
        }
      }
    }

    // 2. Secondary name-based check
    if (!_isVideoDownloaded && _currentDownloadingFileName != null) {
      await checkFileExists(_currentDownloadingFileName!);
    }

    // 3. Exhaustive search if high progress (Android job timeout / connection loss at the end)
    if (!_isVideoDownloaded && progress >= 95) {
      debugPrint(
        'DownloadManager: High progress ($progress%) but file not found. Starting exhaustive retries...',
      );
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (_currentDownloadingFileName != null) {
          await checkFileExists(_currentDownloadingFileName!);
          if (_isVideoDownloaded) break;
        }
      }
    }

    if (_isVideoDownloaded) {
      debugPrint('DownloadManager: Status recovery SUCCESSful.');
      _downloadProgress = 1.0;
      _downloadStatus = 'İndirme tamamlandı.';
      _notifyStateChanged();

      if (_currentDownloadingFileId != null &&
          _currentDownloadingFileName != null) {
        final newFile = drive.File()
          ..id = _currentDownloadingFileId
          ..name = _currentDownloadingFileName;
        if (!_downloadedVideos.any((f) => f.id == newFile.id)) {
          _downloadedVideos.add(newFile);
        }
      }

      Future.delayed(const Duration(seconds: 2), () {
        _downloadProgress = null;
        _downloadStatus = null;
        _currentDownloadingFileName = null;
        _notifyStateChanged();
      });
      return;
    }

    // --- RECOVERY FAILED ---
    final diagnosticInfo = currentTask != null
        ? 'URL: ${currentTask.url}, Dir: ${currentTask.savedDir}'
        : 'Task details not found';

    String errorMessage;
    if (status == DownloadTaskStatus.canceled) {
      errorMessage = 'İndirme durduruldu veya iptal edildi.';
    } else {
      if (diagnosticInfo.contains('403')) {
        errorMessage = 'Erişim engellendi (403). Oturumunuzu kontrol edin.';
      } else if (diagnosticInfo.contains('404')) {
        errorMessage = 'Dosya bulunamadı (404).';
      } else {
        errorMessage =
            'İndirme başarısız. Bağlantınızı kontrol edip tekrar deneyin.';
      }
    }

    debugPrint(
      'DownloadManager: $statusName confirmed as true failure. $diagnosticInfo',
    );

    // CLEANUP: If it truly failed/canceled and file doesn't exist, delete any partial content
    try {
      await FlutterDownloader.remove(taskId: id, shouldDeleteContent: true);
      debugPrint(
        'DownloadManager: Cleaned up $statusName task content for $id',
      );
    } catch (e) {
      debugPrint('DownloadManager: Cleanup failed for task $id: $e');
    }

    _downloadStatus = errorMessage;
    _downloadProgress = null;
    _currentDownloadingFileName = null;
    _notifyStateChanged();
    _onError?.call(errorMessage);
  }

  Future<void> refreshTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      for (var task in tasks) {
        if (task.status == DownloadTaskStatus.complete &&
            task.filename != null) {
          if (!_isVideoDownloaded || _localVideoFile == null) {
            await checkFileExists(task.filename!);
          }
        }
      }
    }
    notifyListeners();
  }

  void _notifyStateChanged() {
    notifyListeners();
  }

  Future<List<File>> _getLocalFiles() async {
    final Map<String, File> uniqueFiles = {};

    // 1. Check FlutterDownloader database - Most reliable source
    final tasks = await FlutterDownloader.loadTasks();
    final incompleteTaskPaths = <String>{};

    if (tasks != null && tasks.isNotEmpty) {
      debugPrint('DownloadManager: Found ${tasks.length} tasks in DB.');
      for (var task in tasks) {
        if (task.savedDir != null && task.filename != null) {
          final filePath = '${task.savedDir}/${task.filename}';

          if (task.status == DownloadTaskStatus.complete) {
            final file = File(filePath);
            if (await file.exists() && await file.length() > 0) {
              uniqueFiles[file.path] = file;
              debugPrint(
                'DownloadManager: Found valid completed file: ${file.path}',
              );
            }
          } else {
            // Mark as incomplete to ignore during directory scan
            incompleteTaskPaths.add(filePath);
          }
        }
      }
    }

    // 2. Scan directories as fallback/secondary
    final paths = await _getPossibleSecondaryPaths(''); // Base dirs
    debugPrint('DownloadManager: Scanning base directories: $paths');

    for (var dirPath in paths) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final list = (await dir.list().toList()).whereType<File>();
          debugPrint(
            'DownloadManager: Listing $dirPath found ${list.length} files.',
          );
          for (var f in list) {
            // VALIDATION:
            // 1. Not in incomplete tasks
            // 2. Size > 0
            if (!incompleteTaskPaths.contains(f.path)) {
              if (await f.exists() && await f.length() > 0) {
                uniqueFiles[f.path] = f;
              }
            } else {
              debugPrint(
                'DownloadManager: Ignoring incomplete/failed task file: ${f.path}',
              );
            }
          }
        } catch (e) {
          debugPrint(
            'DownloadManager: Listing $dirPath failed (Normal for Scoped Storage): $e',
          );
        }
      }
    }
    return uniqueFiles.values.toList();
  }

  Future<void> loadDownloadedVideos(DriveService driveService) async {
    try {
      final localFiles = await _getLocalFiles();
      debugPrint(
        'DownloadManager: Total local files collected: ${localFiles.length}',
      );

      // 3. Try to get metadata from Drive if possible
      List<drive.File> driveMetadata = [];
      try {
        driveMetadata = await driveService.listVideoFiles();
      } catch (e) {
        debugPrint(
          'DownloadManager: Could not fetch Drive metadata, using local-only info: $e',
        );
      }

      final downloaded = <drive.File>[];

      final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];

      for (var localFile in localFiles) {
        final fileName = localFile.path.split('/').last;

        // Skip hidden files
        if (fileName.startsWith('.')) continue;

        // Filter for video extensions
        final dotIndex = fileName.lastIndexOf('.');
        if (dotIndex == -1) continue;
        final extension = fileName.substring(dotIndex).toLowerCase();
        if (!videoExtensions.contains(extension)) continue;

        // Try to find matching metadata from Drive
        final match = driveMetadata
            .where((df) => df.name == fileName)
            .firstOrNull;

        if (match != null) {
          downloaded.add(match);
        } else {
          // If no match in Drive (maybe deleted from Drive, or Drive offline),
          // create a stub entry so it's still clickable/playable
          final stat = await localFile.stat();
          downloaded.add(
            drive.File()
              ..name = fileName
              ..id =
                  'local_$fileName' // Pseudo-ID for local files
              ..size = stat.size.toString(),
          );
        }
      }

      // Sort by name for consistent UI
      downloaded.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      _downloadedVideos = downloaded;
      _notifyStateChanged();
    } catch (e) {
      debugPrint('Error loading downloaded videos: $e');
    }
  }

  Future<List<String>> _getPossiblePaths(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final extDir = await getExternalStorageDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    return [
      if (fileName.isNotEmpty) ...[
        '${appDir.path}/$safeName',
        '${appDir.path}/$fileName',
        if (extDir != null) ...[
          '${extDir.path}/$safeName',
          '${extDir.path}/$fileName',
        ],
        '${appDir.parent.path}/app_flutter/$fileName',
        if (Platform.isAndroid) ...[
          '/storage/emulated/0/Download/$safeName',
          '/storage/emulated/0/Download/$fileName',
        ],
      ],
    ];
  }

  Future<List<String>> _getPossibleSecondaryPaths(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final extDir = await getExternalStorageDirectory();
    return [
      appDir.path,
      if (extDir != null) extDir.path,
      '${appDir.parent.path}/app_flutter',
      if (Platform.isAndroid) '/storage/emulated/0/Download',
    ];
  }

  Future<void> checkFileExists(String fileName) async {
    try {
      final pathsToCheck = await _getPossiblePaths(fileName);

      File? foundFile;
      for (final path in pathsToCheck) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          foundFile = file;
          break;
        }
      }

      if (foundFile != null) {
        _isVideoDownloaded = true;
        _localVideoFile = foundFile;
        debugPrint('DownloadManager: File FOUND at ${foundFile.path}');
      } else {
        _isVideoDownloaded = false;
        _localVideoFile = null;
        debugPrint('DownloadManager: File NOT found: $fileName');
      }
      _notifyStateChanged();
    } catch (e) {
      debugPrint('DownloadManager: Error in checkFileExists: $e');
    }
  }

  Future<void> downloadVideo(
    DriveService driveService,
    String fileId,
    String fileName,
    BuildContext context,
  ) async {
    try {
      _downloadProgress = 0;
      _downloadStatus = 'İndirme başlatılıyor...';
      _currentDownloadingFileName = fileName;
      _currentDownloadingFileId = fileId;
      _notifyStateChanged();

      // Clean Start: Delete existing local file if it exists to avoid conflicts
      await deleteDownloadedVideo(fileName, driveService);

      bool showNotification = true;
      if (Platform.isAndroid) {
        final permissionService = PermissionService();
        final isGranted = await permissionService
            .requestNotificationPermission();

        // If notification permission is NOT granted, we can still try to download,
        // but we MUST set showNotification to false, otherwise it might crash on some devices.
        if (!isGranted) {
          showNotification = false;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bildirim izni verilmedi, indirme bildirimi gösterilmeyecek.',
                ),
              ),
            );
          }
        }
      }

      await driveService.downloadVideoInBackground(
        fileId,
        fileName,
        showNotification: showNotification,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme arka planda başlatıldı...')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DownloadManager: Error starting download: $e');
      debugPrint('Stacktrace: $stackTrace');

      _downloadProgress = null;
      _downloadStatus = 'Hata oluştu';
      _notifyStateChanged();

      String userMessage = 'İndirme başlatılamadı.';
      final errorString = e.toString();

      if (errorString.contains('User not signed in')) {
        userMessage = 'Oturum açılmamış. Lütfen giriş yapın.';
      } else if (errorString.contains('SocketException') ||
          errorString.contains('Network is unreachable') ||
          errorString.contains('HandshakeException')) {
        userMessage = 'İnternet bağlantısı kurulamadı veya ağ kısıtlı.';
      } else {
        userMessage = 'İndirme hatası: $errorString';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> deleteDownloadedVideo(
    String fileName,
    DriveService driveService,
  ) async {
    try {
      final paths = await _getPossiblePaths(fileName);

      for (var path in paths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('DownloadManager: Deleted $path');
        }
      }

      // Update internal state
      _downloadedVideos.removeWhere((f) => f.name == fileName);
      _isVideoDownloaded = false;
      _localVideoFile = null;
      _notifyStateChanged();
    } catch (e) {
      debugPrint('Error deleting video: $e');
    }
  }
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'downloader_send_port',
  );
  send?.send([id, status, progress]);
}
