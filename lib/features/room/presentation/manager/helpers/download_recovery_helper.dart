import 'dart:io';
import 'package:emotional/features/room/presentation/manager/helpers/download_file_helper.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_task_helper.dart';
import 'package:flutter/foundation.dart';

class DownloadRecoveryHelper {
  final DownloadTaskHelper _taskHelper;
  final DownloadFileHelper _fileHelper;

  DownloadRecoveryHelper({
    required DownloadTaskHelper taskHelper,
    required DownloadFileHelper fileHelper,
  }) : _taskHelper = taskHelper,
       _fileHelper = fileHelper;

  Future<File?> attemptRecovery({
    required String taskId,
    required String? currentFileName,
    required int progress,
  }) async {
    // 1. Immediate task-specific check
    final currentTask = await _taskHelper.getTaskById(taskId);
    File? foundFile;

    if (currentTask != null && currentTask.filename != null) {
      final taskFile = File('${currentTask.savedDir}/${currentTask.filename}');
      if (await taskFile.exists()) {
        final len = await taskFile.length();
        if (len > 0) {
          foundFile = taskFile;
          debugPrint(
            'DownloadManager: Recovery approach 1 (Task Path) SUCCESS',
          );
          return foundFile;
        }
      }
    }

    // 2. Secondary name-based check
    if (currentFileName != null) {
      foundFile = await _fileHelper.checkFileExists(currentFileName);
      if (foundFile != null) {
        debugPrint('DownloadManager: Recovery approach 2 (Name Check) SUCCESS');
        return foundFile;
      }
    }

    // 3. Exhaustive search if high progress (Android job timeout / connection loss at the end)
    if (progress >= 95) {
      debugPrint(
        'DownloadManager: High progress ($progress%) but file not found. Starting exhaustive retries...',
      );
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (currentFileName != null) {
          foundFile = await _fileHelper.checkFileExists(currentFileName);
          if (foundFile != null) {
            debugPrint(
              'DownloadManager: Recovery approach 3 (Retry $i) SUCCESS',
            );
            return foundFile;
          }
        }
      }
    }

    return null;
  }
}
