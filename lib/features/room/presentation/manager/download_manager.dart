import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/core/services/download/download_service.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_drive_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_error_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_file_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_permission_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_recovery_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_task_helper.dart';
import 'package:emotional/core/services/download/download_model.dart';
import 'package:flutter/material.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // Low-level Helpers
  final DownloadPermissionHelper _permissionHelper = DownloadPermissionHelper();
  final DownloadFileHelper _fileHelper = DownloadFileHelper();
  final DownloadTaskHelper _taskHelper = DownloadTaskHelper();

  final DownloadErrorHelper _errorHelper = DownloadErrorHelper();

  // High-level Helpers (Dependencies on low-level)
  late final DownloadRecoveryHelper _recoveryHelper;
  final DownloadDriveHelper _driveHelper = DownloadDriveHelper();

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

    _recoveryHelper = DownloadRecoveryHelper(
      taskHelper: _taskHelper,
      fileHelper: _fileHelper,
    );

    await _permissionHelper.requestInitialPermissions();

    await _permissionHelper.requestInitialPermissions();

    // Migrated to DownloadService for professional background handling
    // _isolateHelper.bindBackgroundIsolate(_onDownloadProgress);

    // Listen to DownloadService instead
    DownloadService().taskStream.listen((task) {
      _onDownloadProgress(task);
    });

    _isInitialized = true;

    // Task Recovery
    final tasks = await _taskHelper.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      final task = tasks.last;
      debugPrint(
        'DownloadManager: Found existing task: ${task.taskId} - Status: ${task.status}',
      );

      if (task.status == TaskStatus.running ||
          task.status == TaskStatus.enqueued) {
        _currentDownloadingFileId = null;
        _currentDownloadingFileName = task.filename;
        _downloadProgress = task.progress;
        _downloadStatus = 'İndiriliyor...';
        notifyListeners();
      } else if (task.status == TaskStatus.complete) {
        if (task.filename != null) {
          await checkFileExists(task.filename!);
        }
      }
    }
  }

  void _onDownloadProgress(DownloadTaskOption task) {
    debugPrint(
      'DownloadManager: Task ${task.taskId} - Status: ${task.status}, Progress: ${task.progress}',
    );

    if (task.status == TaskStatus.complete) {
      _handleSuccess();
    } else if (task.status == TaskStatus.failed ||
        task.status == TaskStatus.canceled ||
        task.status == TaskStatus.notFound) {
      _handleTaskEnd(task);
    } else if (task.status == TaskStatus.paused) {
      _downloadStatus = 'Durduruldu (${(task.progress * 100).toInt()}%)';
      debugPrint('DownloadManager: Download PAUSED');
      _notifyStateChanged();
    } else {
      _downloadProgress = task.progress; // progress is 0.0 to 1.0
      _downloadStatus = 'İndiriliyor: ${(task.progress * 100).toInt()}%';
      _notifyStateChanged();
    }
  }

  void _handleSuccess() {
    _downloadProgress = 1.0;
    _downloadStatus = 'İndirme tamamlandı.';
    debugPrint('DownloadManager: Download COMPLETED successfully.');
    _notifyStateChanged();

    Future.delayed(const Duration(seconds: 2), () {
      _downloadProgress = null;
      _downloadStatus = null;
      _currentDownloadingFileName = null;
      _notifyStateChanged();
    });

    if (_currentDownloadingFileName != null &&
        _currentDownloadingFileId != null) {
      final newFile = drive.File()
        ..id = _currentDownloadingFileId
        ..name = _currentDownloadingFileName;

      if (!_downloadedVideos.any((f) => f.id == newFile.id)) {
        _downloadedVideos.add(newFile);
      }
      checkFileExists(_currentDownloadingFileName!);
    }
  }

  Future<void> _handleTaskEnd(DownloadTaskOption task) async {
    final id = task.taskId;
    final status = task.status;
    final progress = task.progress;
    final statusName = status == TaskStatus.failed ? 'Failed' : 'Canceled';
    debugPrint(
      'DownloadManager: Status $statusName received. Attempting recovery...',
    );

    _downloadStatus = 'Dosya doğrulanıyor...';
    _notifyStateChanged();

    // Delegate complex recovery logic to helper
    final recoveredFile = await _recoveryHelper.attemptRecovery(
      taskId: id,
      currentFileName: _currentDownloadingFileName,
      progress: progress,
    );

    if (recoveredFile != null) {
      debugPrint('DownloadManager: Recovery SUCCESS.');
      _localVideoFile = recoveredFile;
      _isVideoDownloaded = true;
      _handleSuccess();
      return;
    }

    // --- RECOVERY FAILED ---
    debugPrint('DownloadManager: Recovery FAILED. Reporting error.');
    if (task.error != null) {
      debugPrint('DownloadManager: Task Exception: ${task.error}');
    }
    if (task.responseBody != null) {
      debugPrint('DownloadManager: Response Body: ${task.responseBody}');
    }

    // Get diagnostic info for error message
    final currentTask = await _taskHelper.getTaskById(id);
    final diagnosticInfo = currentTask != null
        ? 'URL: ${currentTask.url}, Dir: ${currentTask.savedDir}'
        : 'Task details not found';

    final errorMessage = _errorHelper.getStatusErrorMessage(
      statusName,
      diagnosticInfo,
    );

    // CLEANUP
    await _taskHelper.removeTask(id);

    _downloadStatus = errorMessage;
    _downloadProgress = null;
    _currentDownloadingFileName = null;
    _notifyStateChanged();
    _onError?.call(errorMessage);
  }

  Future<void> refreshTasks() async {
    final tasks = await _taskHelper.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      for (var task in tasks) {
        if (task.status == TaskStatus.complete && task.filename != null) {
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
    final tasks = await _taskHelper.loadTasks();
    final incompleteTaskPaths = <String>{};

    if (tasks != null) {
      for (var task in tasks) {
        if (task.savedDir != null && task.filename != null) {
          if (task.status != TaskStatus.complete) {
            final filePath = '${task.savedDir}/${task.filename}';
            incompleteTaskPaths.add(filePath);
          }
        }
      }
    }

    return await _fileHelper.getLocalFiles(incompleteTaskPaths);
  }

  Future<void> loadDownloadedVideos(DriveService driveService) async {
    final localFiles = await _getLocalFiles();
    _downloadedVideos = await _driveHelper.loadDownloadedVideos(
      driveService: driveService,
      localFiles: localFiles,
    );
    _notifyStateChanged();
  }

  Future<void> checkFileExists(String fileName) async {
    final foundFile = await _fileHelper.checkFileExists(fileName);
    debugPrint(
      'DownloadManager: checkFileExists($fileName) -> found: ${foundFile?.path}',
    );

    if (foundFile != null) {
      _isVideoDownloaded = true;
      _localVideoFile = foundFile;
    } else {
      _isVideoDownloaded = false;
      _localVideoFile = null;
    }
    _notifyStateChanged();
  }

  Future<void> downloadVideo(
    DriveService driveService,
    String fileId,
    String fileName, {
    bool requestNotificationPermission = true,
  }) async {
    if (_downloadStatus != null && _downloadStatus!.contains('İndiriliyor')) {
      debugPrint(
        'DownloadManager: Download already in progress. Ignoring request.',
      );
      return;
    }

    try {
      _downloadProgress = 0;
      _downloadStatus = 'İndirme başlatılıyor...';
      _currentDownloadingFileName = fileName;
      _currentDownloadingFileId = fileId;
      _notifyStateChanged();

      await deleteDownloadedVideo(fileName);

      bool showNotification = true;
      if (Platform.isAndroid && requestNotificationPermission) {
        final isGranted = await _permissionHelper
            .requestNotificationPermission();
        if (!isGranted) {
          showNotification = false;
          debugPrint('DownloadManager: Notification permission denied.');
        }
      }

      await driveService.downloadVideoInBackground(
        fileId,
        fileName,
        showNotification: showNotification,
      );
    } catch (e, stackTrace) {
      debugPrint('DownloadManager: Error starting download: $e');
      debugPrint('Stacktrace: $stackTrace');

      _downloadProgress = null;
      _downloadStatus = 'Hata oluştu';
      _notifyStateChanged();

      final userMessage = _errorHelper.getErrorMessage(e);
      _onError?.call(userMessage);

      throw Exception(userMessage);
    }
  }

  Future<void> deleteDownloadedVideo(String fileName) async {
    await _fileHelper.deleteDownloadedVideo(fileName);

    _downloadedVideos.removeWhere((f) => f.name == fileName);
    _isVideoDownloaded = false;
    _localVideoFile = null;
    _notifyStateChanged();
  }
}
