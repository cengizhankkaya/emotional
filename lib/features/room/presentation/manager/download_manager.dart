import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:emotional/core/services/drive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadManager {
  final ReceivePort _port = ReceivePort();

  double? _downloadProgress;
  String? _downloadStatus;
  bool _isVideoDownloaded = false;
  File? _localVideoFile;
  String? _currentDownloadingFileName;
  List<drive.File> _downloadedVideos = [];

  VoidCallback? _onStateChanged;

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

        if (_currentDownloadingFileName != null) {
          checkFileExists(_currentDownloadingFileName!);
        }
      } else if (status == 4) {
        // Failed
        _downloadStatus = 'İndirme başarısız.';
        _downloadProgress = null;
        _currentDownloadingFileName = null;
        _notifyStateChanged();
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
      final files = await driveService.listVideoFiles();
      final appDir = await getApplicationDocumentsDirectory();

      final downloaded = <drive.File>[];
      for (var file in files) {
        if (file.name != null) {
          final localFile = File('${appDir.path}/${file.name}');
          if (await localFile.exists()) {
            downloaded.add(file);
          }
        }
      }

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
      _notifyStateChanged();

      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bildirim izni gerekli.')),
            );
          }
        }
      }

      await driveService.downloadVideoInBackground(fileId, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme arka planda başlatıldı...')),
        );
      }
    } catch (e) {
      _downloadProgress = null;
      _downloadStatus = 'Hata oluştu';
      _notifyStateChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
