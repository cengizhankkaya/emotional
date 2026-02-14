import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AvatarParticipantWidget extends StatelessWidget {
  final String? name;
  final String? participantId;
  final CallState callState;
  final String currentUserId;
  final bool isParticipantHost;
  final bool canTransferHost;
  final String? roomId;
  final bool hideAvatar;
  final bool showVideo; // New flag to control video rendering
  final bool showControls; // New flag to control mic/cam toggles
  final bool isWatchingVideo; // New flag to indicate if user is watching video
  final double? customWidth;
  final double? customHeight;
  final BoxShape shape;

  const AvatarParticipantWidget({
    super.key,
    this.name,
    this.participantId,
    required this.callState,
    required this.currentUserId,
    this.isParticipantHost = false,
    this.canTransferHost = false,
    this.roomId,
    this.hideAvatar = false,
    this.showVideo = true, // Default to true for backward compatibility
    this.showControls = true, // Default to true
    this.isWatchingVideo = false,
    this.customWidth,
    this.customHeight,
    this.shape = BoxShape.circle,
  });

  @override
  Widget build(BuildContext context) {
    final defaultSize = context.dynamicValue(50);
    final width = customWidth ?? defaultSize;
    final height = customHeight ?? defaultSize;

    if (name == null) {
      if (hideAvatar) return const SizedBox();
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(12)
              : null,
        ),
      );
    }

    final isLocal = participantId == currentUserId;
    bool hasVideo = false;
    bool isMuted = false;
    RTCVideoRenderer? renderer;

    if (callState is CallConnected) {
      final connectedState = callState as CallConnected;
      if (isLocal) {
        final isSharing = connectedState.isScreenSharing;
        // Don't show video in this tile if screen sharing is active
        hasVideo = showVideo && connectedState.isVideoEnabled && !isSharing;
        renderer = connectedState.localRenderer;
      } else if (participantId != null) {
        final isSharing =
            connectedState.userScreenSharingStates[participantId] ?? false;
        // Don't show video in this tile if remote user is screen sharing
        hasVideo =
            showVideo &&
            (connectedState.userVideoStates[participantId] ?? false) &&
            !isSharing;
        isMuted = !(connectedState.userAudioStates[participantId] ?? true);
        renderer = connectedState.remoteRenderers[participantId];
      }
    }

    final avatarContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideAvatar)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: isParticipantHost
                      ? Colors.grey[850] // Dark Gray for Host
                      : Colors.grey[900], // Slightly darker for others
                  shape: shape,
                  borderRadius: shape == BoxShape.rectangle
                      ? BorderRadius.circular(12)
                      : null,
                  border: Border.all(
                    color: isParticipantHost
                        ? Colors.white54
                        : Colors.grey[700]!,
                    width: isParticipantHost ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: shape == BoxShape.rectangle
                      ? BorderRadius.circular(
                          10,
                        ) // Slightly less than container border radius
                      : BorderRadius.circular(width / 2),
                  child: hasVideo && renderer != null
                      ? RTCVideoView(
                          renderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: isLocal,
                        )
                      : Center(
                          child: Text(
                            name!.isNotEmpty ? name![0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
              ),
              if (isParticipantHost)
                Positioned(
                  top: -height * 0.1,
                  right: -width * 0.1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey[800], // Dark Gray Star Background
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: width * 0.25,
                    ),
                  ),
                ),
              if (isLocal && showControls)
                const SizedBox.shrink(), // Hidden as it's now in the bottom panel
            ],
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWatchingVideo) ...[
                    const Icon(
                      Icons.visibility,
                      color: Colors.blueAccent,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (isMuted) ...[
                    const Icon(
                      Icons.mic_off,
                      color: Colors.redAccent,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    name!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.dynamicValue(10),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (canTransferHost && roomId != null && participantId != null) {
      return GestureDetector(
        onLongPress: () {
          _showTransferHostDialog(context, roomId!, participantId!, name!);
        },
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  void _showTransferHostDialog(
    BuildContext context,
    String roomId,
    String newHostId,
    String userName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('Host Devret', style: TextStyle(color: Colors.white)),
        content: Text(
          'Host yetkisini $userName kullanıcısına devretmek istiyor musunuz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<RoomBloc>().add(
                TransferHostRequested(roomId: roomId, newHostId: newHostId),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Devret', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
