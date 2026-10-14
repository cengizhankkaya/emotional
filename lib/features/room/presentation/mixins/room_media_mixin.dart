import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/room/presentation/widgets/web/web_drive_picker_dialog.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:googleapis/drive/v3.dart' as drive;

mixin RoomMediaMixin<T extends StatefulWidget> on State<T> {
  // DownloadManager logic moved to DownloadCubit

  Future<void> pickVideo(String roomId) async {
    if (!mounted) return;
    final drive.File? file;
    if (kIsWeb) {
      // Browsers only have Drive; phones also list downloads and gallery.
      final roomState = context.read<RoomBloc>().state;
      file = await WebDrivePickerDialog.show(
        context,
        currentFileId: roomState is RoomJoined ? roomState.driveFileId : null,
      );
    } else {
      final downloadCubit = context.read<DownloadCubit>();
      file = await Navigator.push<drive.File>(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: downloadCubit,
            child: const DriveFilePickerScreen(),
          ),
        ),
      );
    }

    // Refresh downloaded videos in Cubit after returning from picker
    // context.read<DownloadCubit>().loadDownloadedVideos(); // Optional, if picker changes things

    if (file != null && mounted) {
      debugPrint('RoomMediaMixin: File picked: ${file.name} (${file.id})');
      selectVideo(roomId, file);
    } else {
      debugPrint('RoomMediaMixin: No file picked (null)');
    }
  }

  void selectVideo(String roomId, drive.File file) {
    context.read<RoomBloc>().add(
      UpdateRoomVideoRequested(
        roomId: roomId,
        fileId: file.id!,
        fileName: file.name!,
        fileSize: file.size ?? '0',
      ),
    );
  }

  /// Web: streams the Drive file through `drive_stream_sw.js` instead of
  /// downloading it first.
  Future<void> playDriveStream({
    required String fileId,
    required String roomId,
    required String userId,
    String? savedAudioTrack,
    String? savedSubtitleTrack,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final driveService = context.read<DriveService>();
    try {
      final streamUrl = await driveService.webStreamUrl(fileId);
      if (!mounted) return;
      playVideo(
        streamUrl: streamUrl,
        roomId: roomId,
        userId: userId,
        savedAudioTrack: savedAudioTrack,
        savedSubtitleTrack: savedSubtitleTrack,
      );
    } catch (e) {
      debugPrint('RoomMediaMixin: Drive stream failed: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(LocaleKeys.video_webStreamFailed.tr(args: ['$e'])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void playVideo({
    File? videoFile,
    String? youtubeUrl,
    String? streamUrl,
    required String roomId,
    required String userId,
    String? savedAudioTrack,
    String? savedSubtitleTrack,
  }) {
    // Notify that user is watching video
    context.read<RoomBloc>().add(
      UpdateWatchingStatus(roomId: roomId, userId: userId, isWatching: true),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoFile: videoFile,
          youtubeUrl: youtubeUrl,
          streamUrl: streamUrl,
          roomId: roomId,
          userId: userId,
          savedAudioTrack: savedAudioTrack,
          savedSubtitleTrack: savedSubtitleTrack,
        ),
      ),
    );
  }
}
