import 'dart:io';

import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

mixin RoomMediaMixin<T extends StatefulWidget> on State<T> {
  // DownloadManager logic moved to DownloadCubit

  Future<void> pickVideo(String roomId) async {
    if (!mounted) return;
    final file = await Navigator.push<drive.File>(
      context,
      MaterialPageRoute(builder: (_) => const DriveFilePickerScreen()),
    );

    // Refresh downloaded videos in Cubit after returning from picker
    // context.read<DownloadCubit>().loadDownloadedVideos(); // Optional, if picker changes things

    if (file != null && mounted) {
      selectVideo(roomId, file);
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

  void playVideo({
    required File videoFile,
    required String roomId,
    required String userId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoFile: videoFile,
          roomId: roomId,
          userId: userId,
        ),
      ),
    );
  }
}
