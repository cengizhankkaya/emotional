import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:equatable/equatable.dart';
import 'package:googleapis/drive/v3.dart' as drive;

// --- STATE ---
class DownloadState extends Equatable {
  final List<drive.File> downloadedVideos;
  final double? downloadProgress; // 0.0 to 1.0
  final String? statusMessage;
  final bool isVideoDownloaded;
  final File? localVideoFile;
  final String? error; // For one-time errors (Snackbars)

  const DownloadState({
    this.downloadedVideos = const [],
    this.downloadProgress,
    this.statusMessage,
    this.isVideoDownloaded = false,
    this.localVideoFile,
    this.error,
  });

  DownloadState copyWith({
    List<drive.File>? downloadedVideos,
    double? downloadProgress,
    String? statusMessage,
    bool? isVideoDownloaded,
    File? localVideoFile,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return DownloadState(
      downloadedVideos: downloadedVideos ?? this.downloadedVideos,
      downloadProgress: clearProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      statusMessage: clearProgress
          ? null
          : (statusMessage ?? this.statusMessage),
      isVideoDownloaded: isVideoDownloaded ?? this.isVideoDownloaded,
      localVideoFile: localVideoFile ?? this.localVideoFile,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    downloadedVideos,
    downloadProgress,
    statusMessage,
    isVideoDownloaded,
    localVideoFile,
    error,
  ];
}

// --- CUBIT ---
class DownloadCubit extends Cubit<DownloadState> {
  final DownloadManager _downloadManager;
  final DriveService _driveService;

  DownloadCubit({
    required DownloadManager downloadManager,
    required DriveService driveService,
  }) : _downloadManager = downloadManager,
       _driveService = driveService,
       super(const DownloadState()) {
    _init();
  }

  void _init() {
    _downloadManager.addListener(_onDownloadManagerChanged);
    _downloadManager.setOnError(_onError);

    // Initial load
    _downloadManager.initialize().then((_) {
      loadDownloadedVideos();
    });
  }

  @override
  Future<void> close() {
    _downloadManager.removeListener(_onDownloadManagerChanged);
    return super.close();
  }

  void _onDownloadManagerChanged() {
    emit(
      state.copyWith(
        downloadProgress: _downloadManager.downloadProgress,
        statusMessage: _downloadManager.downloadStatus,
        isVideoDownloaded: _downloadManager.isVideoDownloaded,
        localVideoFile: _downloadManager.localVideoFile,
        downloadedVideos: _downloadManager.downloadedVideos,
      ),
    );
  }

  void _onError(String message) {
    emit(state.copyWith(error: message));
    // Clear error immediately after emission so it doesn't persist
    emit(state.copyWith(clearError: true));
  }

  Future<void> loadDownloadedVideos() async {
    await _downloadManager.loadDownloadedVideos(_driveService);
  }

  Future<void> checkFileExists(String fileName) async {
    await _downloadManager.checkFileExists(fileName);
  }

  Future<void> downloadVideo(String fileId, String fileName) async {
    try {
      await _downloadManager.downloadVideo(
        _driveService,
        fileId,
        fileName,
        requestNotificationPermission: true,
      );
      // Success is indicated by state changes from listener
    } catch (e) {
      if (state.error != e.toString()) {
        _onError(e.toString());
      }
    }
  }
}
