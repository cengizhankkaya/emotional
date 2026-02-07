import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:emotional/core/services/download/download_model.dart';

class DownloadTaskHelper {
  Future<List<DownloadTaskOption>?> loadTasks() async {
    final records = await FileDownloader().database.allRecords();
    return records
        .map((record) => DownloadTaskOption.fromRecord(record))
        .toList();
  }

  Future<void> removeTask(String taskId) async {
    try {
      // cancel and delete content
      // check if task exists first to get the object, or just use cancelTaskWithId if running
      // background_downloader requires task object to delete content
      // but we can try generic cancel.
      // To strictly "delete content" like flutter_downloader, we might need to find the file manually
      // or use FileDownloader().reset(group) but that's too broad.
      // For now, cancel is safest. File deletion is handled by DownloadFileHelper usually.
      await FileDownloader().cancelTaskWithId(taskId);
      debugPrint('DownloadManager: Task $taskId canceled/removed');
    } catch (e) {
      debugPrint('DownloadManager: Cleanup failed for task $taskId: $e');
    }
  }

  Future<DownloadTaskOption?> getTaskById(String id) async {
    final record = await FileDownloader().database.recordForId(id);
    if (record != null) {
      return DownloadTaskOption.fromRecord(record);
    }
    return null;
  }
}
