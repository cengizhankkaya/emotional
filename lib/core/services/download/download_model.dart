import 'package:background_downloader/background_downloader.dart';
import 'package:equatable/equatable.dart';

class DownloadTaskOption extends Equatable {
  final String taskId;
  final TaskStatus status;
  final double progress;
  final String? filename;
  final String? savedDir;
  final String? url;
  final int timeCreated;
  final String? error;
  final String? responseBody;

  const DownloadTaskOption({
    required this.taskId,
    required this.status,
    required this.progress,
    this.filename,
    this.savedDir,
    this.url,
    required this.timeCreated,
    this.error,
    this.responseBody,
  });

  factory DownloadTaskOption.fromRecord(TaskRecord record) {
    return DownloadTaskOption(
      taskId: record.taskId,
      status: record.status,
      progress: record.progress,
      filename: record.task.filename,
      savedDir: record.task.directory,
      url: record.task.url,
      timeCreated: record.task.creationTime.millisecondsSinceEpoch,
      error: record.exception?.description,
      responseBody: null,
    );
  }

  factory DownloadTaskOption.fromUpdate(TaskStatusUpdate update) {
    return DownloadTaskOption(
      taskId: update.task.taskId,
      status: update.status,
      // Status updates don't have progress, default to -1 or 0
      progress: -1,
      filename: update.task.filename,
      savedDir: update.task.directory,
      url: update.task.url,
      timeCreated: update.task.creationTime.millisecondsSinceEpoch,
      error: update.exception?.description,
      responseBody: update.responseBody,
    );
  }

  factory DownloadTaskOption.fromProgress(TaskProgressUpdate update) {
    return DownloadTaskOption(
      taskId: update.task.taskId,
      status: TaskStatus.running,
      progress: update.progress,
      filename: update.task.filename,
      savedDir: update.task.directory,
      url: update.task.url,
      timeCreated: update.task.creationTime.millisecondsSinceEpoch,
    );
  }

  @override
  List<Object?> get props => [
    taskId,
    status,
    progress,
    filename,
    savedDir,
    url,
    timeCreated,
  ];

  @override
  String toString() {
    return 'DownloadTaskOption(taskId: $taskId, status: $status, progress: $progress, filename: $filename, url: $url, error: $error, responseBody: $responseBody)';
  }
}
