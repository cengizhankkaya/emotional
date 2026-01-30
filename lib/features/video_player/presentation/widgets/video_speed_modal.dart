import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoSpeedModal extends StatelessWidget {
  final Player player;

  const VideoSpeedModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => VideoSpeedModal(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return ListView(
      shrinkWrap: true,
      children: speeds.map((speed) {
        return ListTile(
          title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
          trailing: player.state.rate == speed
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
          onTap: () {
            player.setRate(speed);
            Navigator.pop(context);

            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final roomState = context.read<RoomBloc>().state;
              if (roomState is RoomJoined &&
                  roomState.hostId == authState.user.uid) {
                context.read<RoomBloc>().add(
                  SyncSettingsAction(
                    roomId: roomState.roomId,
                    speed: speed,
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
