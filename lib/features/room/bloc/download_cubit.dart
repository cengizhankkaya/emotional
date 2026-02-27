import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

// --- STATE ---
class DownloadState extends Equatable {
  final List<drive.File> downloadedVideos;
  final double? downloadProgress; // 0.0 to 1.0
  final String? statusMessage;
  final bool isVideoDownloaded;
  final File? localVideoFile;
  final String? error; // For one-time errors (Snackbars)

  final List<drive.File> prefetchedDriveFiles;
  final String? prefetchedNextPageToken;
  final bool isPrefetching;

  const DownloadState({
    this.downloadedVideos = const [],
    this.downloadProgress,
    this.statusMessage,
    this.isVideoDownloaded = false,
    this.localVideoFile,
    this.error,
    this.prefetchedDriveFiles = const [],
    this.prefetchedNextPageToken,
    this.isPrefetching = false,
  });

  DownloadState copyWith({
    List<drive.File>? downloadedVideos,
    double? downloadProgress,
    String? statusMessage,
    bool? isVideoDownloaded,
    File? localVideoFile,
    String? error,
    List<drive.File>? prefetchedDriveFiles,
    String? prefetchedNextPageToken,
    bool? isPrefetching,
    bool clearError = false,
    bool clearProgress = false,
    bool clearPrefetchedToken = false,
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
      prefetchedDriveFiles: prefetchedDriveFiles ?? this.prefetchedDriveFiles,
      prefetchedNextPageToken: clearPrefetchedToken
          ? null
          : (prefetchedNextPageToken ?? this.prefetchedNextPageToken),
      isPrefetching: isPrefetching ?? this.isPrefetching,
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
    prefetchedDriveFiles,
    prefetchedNextPageToken,
    isPrefetching,
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
    if (isClosed) return;
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
    if (isClosed) return;
    emit(state.copyWith(error: message));
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

  Future<void> prefetchDriveFiles() async {
    // If already prefetching or we already have data, skip.
    if (state.isPrefetching || state.prefetchedDriveFiles.isNotEmpty) {
      debugPrint(
        'DownloadCubit: Skipping prefetch (isPrefetching: ${state.isPrefetching}, hasData: ${state.prefetchedDriveFiles.isNotEmpty})',
      );
      return;
    }

    debugPrint('DownloadCubit: Starting prefetchDriveFiles()');
    emit(state.copyWith(isPrefetching: true));

    try {
      _downloadManager.loadDownloadedVideos(_driveService);

      final startTime = DateTime.now();
      final fileList = await _driveService.listVideoFiles(
        pageSize: 10,
        silentOnly: true,
      );
      final elapsed = DateTime.now().difference(startTime);
      debugPrint(
        'DownloadCubit: prefetchDriveFiles() completed in ${elapsed.inMilliseconds}ms',
      );

      if (isClosed) return;

      if (fileList != null) {
        debugPrint(
          'DownloadCubit: Prefetched ${fileList.files?.length ?? 0} files',
        );
        emit(
          state.copyWith(
            prefetchedDriveFiles: fileList.files ?? [],
            prefetchedNextPageToken: fileList.nextPageToken,
            isPrefetching: false,
            clearPrefetchedToken: fileList.nextPageToken == null,
          ),
        );
      } else {
        debugPrint('DownloadCubit: prefetch returned null fileList');
        emit(state.copyWith(isPrefetching: false));
      }
    } catch (e) {
      debugPrint('DownloadCubit: prefetchDriveFiles error: $e');
      if (isClosed) return;
      emit(state.copyWith(isPrefetching: false));
    }
  }
}
