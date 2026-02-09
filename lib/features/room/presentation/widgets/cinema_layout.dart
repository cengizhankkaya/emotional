import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CinemaLayout extends StatelessWidget {
  final List<String> participants;
  final Map<String, String> userNames;
  final String currentUserId;
  final String roomId;
  final String hostId;

  const CinemaLayout({
    super.key,
    required this.participants,
    required this.userNames,
    required this.currentUserId,
    required this.roomId,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Screen Share Area (Top 60%)
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BlocBuilder<CallBloc, CallState>(
                builder: (context, state) {
                  if (state is! CallConnected) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  return _ScreenShareContent(
                    callState: state,
                    currentUserId: currentUserId,
                  );
                },
              ),
            ),
          ),
        ),

        // Participants Row (Bottom 40%)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: ParticipantVideoRow(
              participants: participants,
              userNames: userNames,
              currentUserId: currentUserId,
              roomId: roomId,
              hostId: hostId,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenShareContent extends StatelessWidget {
  final CallConnected callState;
  final String currentUserId;

  const _ScreenShareContent({
    required this.callState,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, roomState) {
        String? screenSharingUserId;

        if (roomState is RoomJoined) {
          try {
            // Find the user who is screen sharing
            final entry = roomState.usersState.entries.firstWhere(
              (element) => element.value.isScreenSharing,
              orElse: () => const MapEntry(
                '',
                UserMediaState(
                  isVideoEnabled: false,
                  isAudioEnabled: false,
                  lastUpdatedAt: 0,
                ),
              ),
            );

            if (entry.key.isNotEmpty) {
              screenSharingUserId = entry.key;
            }
          } catch (e) {
            // No one sharing
          }
        }

        RTCVideoRenderer? renderer;

        if (screenSharingUserId != null) {
          if (screenSharingUserId == currentUserId) {
            renderer = callState.localRenderer;
          } else {
            renderer = callState.remoteRenderers[screenSharingUserId];
          }
        }

        if (renderer == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop_screen_share, color: Colors.white54, size: 48),
                SizedBox(height: 16),
                Text(
                  "Ekran paylaşımı bekleniyor...",
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        );
      },
    );
  }
}
