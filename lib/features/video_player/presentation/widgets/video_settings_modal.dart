import 'package:emotional/features/video_player/presentation/widgets/video_audio_modal.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_speed_modal.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_subtitle_modal.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class VideoSettingsModal extends StatelessWidget {
  final Player player;

  const VideoSettingsModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => VideoSettingsModal(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.speed, color: Colors.white),
            title: const Text(
              'Oynatma Hızı',
              style: TextStyle(color: Colors.white),
            ),
            trailing: Text(
              '${player.state.rate}x',
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Navigator.pop(context);
              VideoSpeedModal.show(context, player);
            },
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack, color: Colors.white),
            title: const Text('Ses', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              VideoAudioModal.show(context, player);
            },
          ),
          ListTile(
            leading: const Icon(Icons.subtitles, color: Colors.white),
            title: const Text('Altyazı', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              VideoSubtitleModal.show(context, player);
            },
          ),
        ],
      ),
    );
  }
}
