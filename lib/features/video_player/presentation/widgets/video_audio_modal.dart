import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoAudioModal extends StatefulWidget {
  final Player player;

  const VideoAudioModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VideoAudioModal(player: player),
    );
  }

  @override
  State<VideoAudioModal> createState() => _VideoAudioModalState();
}

class _VideoAudioModalState extends State<VideoAudioModal> {
  String _searchQuery = '';

  String _getTrackDisplayName(AudioTrack track) {
    return track.title ?? track.language ?? track.id;
  }

  List<AudioTrack> _getFilteredTracks() {
    final tracks = widget.player.state.tracks.audio;
    if (_searchQuery.isEmpty) return tracks;

    return tracks.where((track) {
      final displayName = _getTrackDisplayName(track).toLowerCase();
      return displayName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTracks = _getFilteredTracks();
    final currentTrackId = widget.player.state.track.audio.id;
    final hasMultipleTracks = widget.player.state.tracks.audio.length > 5;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Drag indicator
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Row(
                  children: [
                    Icon(Icons.audiotrack, color: Colors.blue[300], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Ses Dili Seçimi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (hasMultipleTracks) ...[
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Dil ara...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Track list
          Flexible(
            child: filteredTracks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dil bulunamadı',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      final isSelected = track.id == currentTrackId;
                      final displayName = _getTrackDisplayName(track);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          leading: Radio<String>(
                            value: track.id,
                            groupValue: currentTrackId,
                            activeColor: Colors.blue,
                            onChanged: (_) => _selectTrack(track),
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.blue[300]
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: track.id != displayName
                              ? Text(
                                  track.id,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Colors.blue[300],
                                )
                              : null,
                          onTap: () => _selectTrack(track),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _selectTrack(AudioTrack track) {
    widget.player.setAudioTrack(track);

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined && roomState.hostId == authState.user.uid) {
        context.read<RoomBloc>().add(
          SyncSettingsAction(
            roomId: roomState.roomId,
            audioTrack: track.id,
            userId: authState.user.uid,
          ),
        );
      }
    }

    // Close and reopen settings modal
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted) {
        VideoSettingsModal.show(context, widget.player);
      }
    });
  }
}
