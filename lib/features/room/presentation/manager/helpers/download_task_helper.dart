import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadTaskHelper {
  Future<List<DownloadTask>?> loadTasks() async {
    return await FlutterDownloader.loadTasks();
  }

  Future<void> removeTask(String taskId) async {
    try {
      await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
      debugPrint('DownloadManager: Cleaned up task content for $taskId');
    } catch (e) {
      debugPrint('DownloadManager: Cleanup failed for task $taskId: $e');
    }
  }

  Future<DownloadTask?> getTaskById(String id) async {
    final tasks = await loadTasks();
    return tasks?.where((t) => t.taskId == id).firstOrNull;
  }
}
