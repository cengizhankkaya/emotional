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
      if (Platform.isAndroid) ...[
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/DCIM/Camera', // Common for camera videos
      ],
    ];
  }

  Future<List<File>> getLocalFiles(Set<String> incompleteTaskPaths) async {
    // Scan directories as fallback/secondary
    final paths = await _getPossibleSecondaryPaths(''); // Base dirs
    debugPrint('DownloadManager: Scanning base directories: $paths');

    // Move file I/O to background isolate
    final localFilePaths = await compute(_scanLocalFilesSync, {
      'paths': paths,
      'incompleteTasks': incompleteTaskPaths.toList(),
    });

    return localFilePaths.map((p) => File(p)).toList();
  }

  // Top-level function for Isolate
  static List<String> _scanLocalFilesSync(Map<String, dynamic> params) {
    final paths = params['paths'] as List<String>;
    final incompletePaths = Set<String>.from(
      params['incompleteTasks'] as List<String>,
    );
    final uniqueFiles = <String, File>{};

    for (var dirPath in paths) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        try {
          final list = dir.listSync().whereType<File>();
          for (var f in list) {
            if (!incompletePaths.contains(f.path)) {
              try {
                if (f.existsSync() && f.lengthSync() > 0) {
                  uniqueFiles[f.path] = f;
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          // Ignore
        }
      }
    }
    return uniqueFiles.keys.toList();
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

  Future<List<File>> listGalleryVideos() async {
    final appDir = await getApplicationDocumentsDirectory();
    final extDir = await getExternalStorageDirectory();

    final dirsToScan = <String>[];
    dirsToScan.add(appDir.path);
    if (Platform.isAndroid) {
      dirsToScan.add('/storage/emulated/0/Download');
    }
    if (extDir != null) {
      dirsToScan.add(extDir.path);
    }

    // Run the heavy scanning process in a separate isolate to avoid UI freezing
    final filePaths = await compute(_scanDirectoriesForVideos, dirsToScan);
    return filePaths.map((path) => File(path)).toList();
  }

  // Top-level function for Isolate (must not use capturing closures)
  static Future<List<String>> _scanDirectoriesForVideos(
    List<String> dirPaths,
  ) async {
    final videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.webm'};
    final videoFiles = <File>[];
    final processedPaths = <String>{};

    for (var dirPath in dirPaths) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        try {
          _scanDirectoryRecursiveSync(
            dir,
            videoFiles,
            processedPaths,
            videoExtensions,
          );
        } catch (e) {
          // Ignore
        }
      }
    }

    // Sort by modification time (newest first)
    videoFiles.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (e) {
        return 0;
      }
    });

    return videoFiles.map((f) => f.path).toList();
  }

  static void _scanDirectoryRecursiveSync(
    Directory dir,
    List<File> videoFiles,
    Set<String> processedPaths,
    Set<String> videoExtensions, {
    int depth = 0,
  }) {
    // Limit recursion depth to avoid infinite loops and performance issues
    if (depth > 3) return;

    try {
      final entities = dir.listSync(recursive: false, followLinks: false);

      for (var entity in entities) {
        if (entity is File) {
          if (processedPaths.contains(entity.path)) continue;

          final ext = entity.path.contains('.')
              ? entity.path
                    .substring(entity.path.lastIndexOf('.'))
                    .toLowerCase()
              : '';

          if (videoExtensions.contains(ext)) {
            // Check size to avoid empty/corrupt files
            try {
              if (entity.lengthSync() > 10 * 1024) {
                // > 10KB
                videoFiles.add(entity);
                processedPaths.add(entity.path);
              }
            } catch (e) {
              // Ignore file access errors
            }
          }
        } else if (entity is Directory) {
          // Skip hidden folders
          if (entity.path.split('/').last.startsWith('.')) continue;

          _scanDirectoryRecursiveSync(
            entity,
            videoFiles,
            processedPaths,
            videoExtensions,
            depth: depth + 1,
          );
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
