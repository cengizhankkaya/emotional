import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
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
            title: Text(
              LocaleKeys.video_player_settings_playbackSpeed.tr(),
              style: const TextStyle(color: Colors.white),
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
          const Divider(color: Colors.white12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      LocaleKeys.video_player_settings_audioChannel.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    StreamBuilder<double>(
                      stream: player.stream.volume,
                      builder: (context, snapshot) {
                        final volume = (snapshot.data ?? player.state.volume)
                            .round();
                        return Text(
                          '%$volume',
                          style: const TextStyle(color: Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
                StreamBuilder<double>(
                  stream: player.stream.volume,
                  builder: (context, snapshot) {
                    final volume = snapshot.data ?? player.state.volume;
                    return Slider(
                      value: volume,
                      min: 0.0,
                      max: 100.0,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.white10,
                      onChanged: (value) {
                        player.setVolume(value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.audiotrack, color: Colors.white),
            title: Text(
              LocaleKeys.video_player_settings_audioChannel.tr(),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              VideoAudioModal.show(context, player);
            },
          ),
          ListTile(
            leading: const Icon(Icons.subtitles, color: Colors.white),
            title: Text(
              LocaleKeys.video_player_settings_subtitle.tr(),
              style: const TextStyle(color: Colors.white),
            ),
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
