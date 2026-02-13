import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

class VideoSubtitleModal extends StatefulWidget {
  final Player player;

  const VideoSubtitleModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VideoSubtitleModal(player: player),
    );
  }

  @override
  State<VideoSubtitleModal> createState() => _VideoSubtitleModalState();
}

class _VideoSubtitleModalState extends State<VideoSubtitleModal> {
  String _searchQuery = '';

  String _getTrackDisplayName(SubtitleTrack track) {
    return track.title ?? track.language ?? track.id;
  }

  List<SubtitleTrack> _getFilteredTracks() {
    final tracks = widget.player.state.tracks.subtitle;
    if (_searchQuery.isEmpty) return tracks;

    return tracks.where((track) {
      final displayName = _getTrackDisplayName(track).toLowerCase();
      return displayName.contains(_searchQuery.toLowerCase());
    }).toList();
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

        await widget.player.setSubtitleTrack(SubtitleTrack.uri(uri));

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
    final filteredTracks = _getFilteredTracks();
    final currentTrackId = widget.player.state.track.subtitle.id;
    final hasMultipleTracks = widget.player.state.tracks.subtitle.length > 5;

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
                    Icon(Icons.subtitles, color: Colors.blue[300], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Altyazı Seçimi',
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
                      hintText: 'Altyazı ara...',
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
          // Options and Track list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Special options section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Özel Seçenekler',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // No subtitle option
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: currentTrackId == 'no'
                        ? Colors.red.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: currentTrackId == 'no'
                          ? Colors.red
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Radio<String>(
                      value: 'no',
                      groupValue: currentTrackId,
                      activeColor: Colors.red,
                      onChanged: (_) => _selectNoSubtitle(),
                    ),
                    title: Text(
                      'Altyazı Yok',
                      style: TextStyle(
                        color: currentTrackId == 'no'
                            ? Colors.red[300]
                            : Colors.white,
                        fontWeight: currentTrackId == 'no'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    trailing: currentTrackId == 'no'
                        ? Icon(Icons.check_circle, color: Colors.red[300])
                        : const Icon(Icons.close, color: Colors.grey),
                    onTap: _selectNoSubtitle,
                  ),
                ),
                // External subtitle option
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.green),
                    title: const Text(
                      'Harici Altyazı Yükle',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Text(
                      '.srt, .vtt, .ass',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _pickExternalSubtitle(context);
                    },
                  ),
                ),
                if (filteredTracks.isNotEmpty) ...[
                  // Embedded subtitles section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Gömülü Altyazılar',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (filteredTracks.isEmpty && _searchQuery.isNotEmpty)
                    Padding(
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
                            'Altyazı bulunamadı',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredTracks.map((track) {
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
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectNoSubtitle() {
    widget.player.setSubtitleTrack(SubtitleTrack.no());

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined && roomState.hostId == authState.user.uid) {
        context.read<RoomBloc>().add(
          SyncSettingsAction(
            roomId: roomState.roomId,
            subtitleTrack: 'no',
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

  void _selectTrack(SubtitleTrack track) {
    widget.player.setSubtitleTrack(track);

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined && roomState.hostId == authState.user.uid) {
        context.read<RoomBloc>().add(
          SyncSettingsAction(
            roomId: roomState.roomId,
            subtitleTrack: track.id,
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
