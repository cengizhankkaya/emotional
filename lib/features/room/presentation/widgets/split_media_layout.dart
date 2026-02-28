import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class SplitMediaLayout extends StatelessWidget {
  final CallConnected callState;
  final String sharingUserId;
  final String currentUserId;
  final Map<String, String> userNames;
  final Map<String, UserMediaState> usersState;

  // Room props for bottom half
  final String roomId;
  final List<String> participants;
  final String hostId;
  final bool isHost;
  final String? driveFileName;
  final String? driveFileId;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onPlayVideo;

  const SplitMediaLayout({
    super.key,
    required this.callState,
    required this.sharingUserId,
    required this.currentUserId,
    required this.userNames,
    required this.usersState,
    required this.roomId,
    required this.participants,
    required this.hostId,
    required this.isHost,
    this.driveFileName,
    this.driveFileId,
    required this.onPickVideo,
    required this.onSelectVideo,
    required this.onPlayVideo,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = sharingUserId == currentUserId;
    final renderer = isMe
        ? callState.localRenderer
        : callState.remoteRenderers[sharingUserId];

    return Column(
      children: [
        // 1. TOP: Screen Share Area (smaller than immersive)
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (renderer != null)
                    RTCVideoView(
                      renderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),

                  // Simple overlay indicator
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.screen_share,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LocaleKeys.call_sharing.tr(
                              args: [
                                userNames[sharingUserId] ??
                                    LocaleKeys.room_someone.tr(),
                              ],
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. BOTTOM: Standard Room Controls & Participants
        Expanded(
          flex: 5,
          child: Column(
            children: [
              ParticipantVideoRow(
                participants: participants,
                userNames: userNames,
                currentUserId: currentUserId,
                roomId: roomId,
                hostId: hostId,
                usersState: usersState,
              ),
              const Spacer(),
              VideoControlSheet(
                isHost: isHost,
                roomId: roomId,
                fileName: driveFileName,
                fileId: driveFileId,
                onPickVideo: onPickVideo,
                onSelectVideo: onSelectVideo,
                onPlay: onPlayVideo,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
