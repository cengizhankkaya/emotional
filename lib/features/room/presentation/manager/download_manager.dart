import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:emotional/core/services/drive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:emotional/core/services/permission_service.dart';

class DownloadManager {
  final ReceivePort _port = ReceivePort();

  double? _downloadProgress;
  String? _downloadStatus;
  bool _isVideoDownloaded = false;
  File? _localVideoFile;
  String? _currentDownloadingFileName;
  String? _currentDownloadingFileId;
  List<drive.File> _downloadedVideos = [];

  VoidCallback? _onStateChanged;
  Function(String)? _onError;

  // Getters
  double? get downloadProgress => _downloadProgress;
  String? get downloadStatus => _downloadStatus;
  bool get isVideoDownloaded => _isVideoDownloaded;
  File? get localVideoFile => _localVideoFile;
  String? get currentDownloadingFileName => _currentDownloadingFileName;
  List<drive.File> get downloadedVideos => _downloadedVideos;

  void setOnStateChanged(VoidCallback callback) {
    _onStateChanged = callback;
  }

  void setOnError(Function(String) callback) {
    _onError = callback;
  }

  void initialize() {
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  void dispose() {
    _unbindBackgroundIsolate();
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

    _port.listen((dynamic data) {
      final int status = data[1];
      final int progress = data[2];

      debugPrint('Download Update: status=$status, progress=$progress');

      if (status == 3) {
        // Complete
        _downloadProgress = 1.0;
        _downloadStatus = 'İndirme tamamlandı.';
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
      } else if (status == 4) {
        // Failed
        const errorMessage =
            'İndirme başarısız. Lütfen internet bağlantınızı ve izinleri kontrol edin.';
        _downloadStatus = errorMessage;
        _downloadProgress = null;
        _currentDownloadingFileName = null;
        _notifyStateChanged();
        _onError?.call(errorMessage);
      } else {
        // Running or Pending
        _downloadProgress = progress / 100.0;
        _downloadStatus = 'İndiriliyor: $progress%';
        _notifyStateChanged();
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  Future<void> loadDownloadedVideos(DriveService driveService) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(appDir.path);

      // 1. Scan local directory for all files
      final List<FileSystemEntity> entities = await dir.list().toList();
      final localFiles = entities.whereType<File>().toList();

      // 2. Try to get metadata from Drive if possible
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
        final extension = fileName
            .substring(fileName.lastIndexOf('.'))
            .toLowerCase();
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

  Future<void> checkFileExists(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$fileName');
    if (await file.exists()) {
      _isVideoDownloaded = true;
      _localVideoFile = file;
    } else {
      _isVideoDownloaded = false;
      _localVideoFile = null;
    }
    _notifyStateChanged();
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
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();

        // Update internal state
        _downloadedVideos.removeWhere((f) => f.name == fileName);
        if (_localVideoFile?.path == file.path) {
          _isVideoDownloaded = false;
          _localVideoFile = null;
        }

        _notifyStateChanged();
      }
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
