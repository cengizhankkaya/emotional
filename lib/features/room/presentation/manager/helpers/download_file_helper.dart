import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

class DownloadFileHelper {
  Future<File?> checkFileExists(String fileName) async {
    try {
      final cleanName = fileName.trim();
      final pathsToCheck = await _getPossiblePaths(cleanName);

      // 1. Exact path check
      for (final path in pathsToCheck) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          debugPrint('DownloadManager: File FOUND at ${file.path}');
          return file;
        }
      }

      // 2. Fallback: Check directory content for name mismatch (e.g. escaping, case sensitivity)
      // This is more expensive but robust.
      final directoryPaths = await _getPossibleSecondaryPaths(cleanName);
      for (final dirPath in directoryPaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          try {
            final entities = await dir.list().toList();
            for (final entity in entities) {
              if (entity is File) {
                final name = entity.uri.pathSegments.last;
                // Check if name contains the video name (fuzzy match) or matches sanitized version
                // ignoring case
                if (name.toLowerCase() == cleanName.toLowerCase() ||
                    name.toLowerCase() == _sanitize(cleanName).toLowerCase()) {
                  if (await entity.length() > 0) {
                    debugPrint(
                      'DownloadManager: File FOUND via fuzzy match at ${entity.path}',
                    );
                    return entity;
                  }
                }
              }
            }
          } catch (e) {
            // Ignore list errors
          }
        }
      }

      debugPrint('DownloadManager: File NOT found: $fileName');
      return null;
    } catch (e) {
      debugPrint('DownloadManager: Error in checkFileExists: $e');
      return null;
    }
  }

  String _sanitize(String fileName) {
    return fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
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

  Future<List<File>> getLocalFiles(Set<String> incompleteTaskPaths) async {
    final Map<String, File> uniqueFiles = {};

    // Scan directories as fallback/secondary
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

  Future<void> deleteDownloadedVideo(String fileName) async {
    try {
      final paths = await _getPossiblePaths(fileName);

      for (var path in paths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('DownloadManager: Deleted $path');
        }
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
    }
  }
}
