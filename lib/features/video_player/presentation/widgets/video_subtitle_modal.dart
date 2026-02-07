import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoSubtitleModal extends StatelessWidget {
  final Player player;

  const VideoSubtitleModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => VideoSubtitleModal(player: player),
    );
  }

  Future<void> _pickExternalSubtitle(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final uri = Uri.file(path).toString();

        await player.setSubtitleTrack(SubtitleTrack.uri(uri));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Harici altyazı yüklendi.')),
          );
        }
      }
    } catch (e) {
      debugPrint('External subtitle error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = player.state.tracks.subtitle;
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.close, color: Colors.red),
          title: const Text(
            'Kapat (Yok)',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            player.setSubtitleTrack(SubtitleTrack.no());
            Navigator.pop(context);

            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              final roomState = context.read<RoomBloc>().state;
              if (roomState is RoomJoined &&
                  roomState.hostId == authState.user.uid) {
                context.read<RoomBloc>().add(
                  SyncSettingsAction(
                    roomId: roomState.roomId,
                    subtitleTrack: 'no',
                    userId: authState.user.uid,
                  ),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.upload_file, color: Colors.blue),
          title: const Text(
            'Harici Yükle (.srt/.vtt)',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            Navigator.pop(context);
            _pickExternalSubtitle(context);
          },
        ),
        const Divider(color: Colors.grey),
        ...tracks.map((track) {
          return ListTile(
            title: Text(
              track.title ?? track.language ?? track.id,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              track.id,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: player.state.track.subtitle.id == track.id
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              player.setSubtitleTrack(track);
              Navigator.pop(context);

              final authState = context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                final roomState = context.read<RoomBloc>().state;
                if (roomState is RoomJoined &&
                    roomState.hostId == authState.user.uid) {
                  context.read<RoomBloc>().add(
                    SyncSettingsAction(
                      roomId: roomState.roomId,
                      subtitleTrack: track.id,
                      userId: authState.user.uid,
                    ),
                  );
                }
              }
            },
          );
        }),
      ],
    );
  }
}
