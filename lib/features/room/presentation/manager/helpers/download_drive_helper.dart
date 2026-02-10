import 'dart:io';
import 'package:emotional/core/services/drive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DownloadDriveHelper {
  Future<List<drive.File>> loadDownloadedVideos({
    required DriveService driveService,
    required List<File> localFiles,
  }) async {
    try {
      debugPrint(
        'DownloadManager: Total local files collected: ${localFiles.length}',
      );

      List<drive.File> driveMetadata = [];
      try {
        // Only try silent sign-in for background checks
        driveMetadata = await driveService.listVideoFiles(silentOnly: true);
      } catch (e) {
        debugPrint(
          'DownloadManager: Could not fetch Drive metadata (silent), using local-only info: $e',
        );
      }

      final downloaded = <drive.File>[];
      final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.webm'];

      for (var localFile in localFiles) {
        final fileName = localFile.path.split('/').last;

        if (fileName.startsWith('.')) continue;

        final dotIndex = fileName.lastIndexOf('.');
        if (dotIndex == -1) continue;
        final extension = fileName.substring(dotIndex).toLowerCase();
        if (!videoExtensions.contains(extension)) continue;

        final match = driveMetadata
            .where((df) => df.name == fileName)
            .firstOrNull;

        if (match != null) {
          downloaded.add(match);
        } else {
          try {
            final stat = await localFile.stat();
            downloaded.add(
              drive.File()
                ..name = fileName
                ..id = 'local_$fileName'
                ..size = stat.size.toString(),
            );
          } catch (e) {
            debugPrint('Error getting stats for file $fileName: $e');
          }
        }
      }

      downloaded.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      return downloaded;
    } catch (e) {
      debugPrint('Error loading downloaded videos: $e');
      return [];
    }
  }
}
