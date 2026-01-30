import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoAudioModal extends StatelessWidget {
  final Player player;

  const VideoAudioModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => VideoAudioModal(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = player.state.tracks.audio;
    return ListView(
      shrinkWrap: true,
      children: tracks.map((track) {
        return ListTile(
          title: Text(
            track.title ?? track.language ?? track.id,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            track.id,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: player.state.track.audio == track
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
          onTap: () {
            player.setAudioTrack(track);
            Navigator.pop(context);

            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final roomState = context.read<RoomBloc>().state;
              if (roomState is RoomJoined &&
                  roomState.hostId == authState.user.uid) {
                context.read<RoomBloc>().add(
                  SyncSettingsAction(
                    roomId: roomState.roomId,
                    audioTrack: track.id,
                    userId: authState.user.uid,
                  ),
                );
              }
            }
          },
        );
      }).toList(),
    );
  }
}
