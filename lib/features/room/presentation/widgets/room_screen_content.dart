import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/domain/enums/room_layout_mode.dart';
import 'package:emotional/features/room/presentation/widgets/screen_share_fullscreen_view.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/room_seating_widget.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:emotional/features/room/presentation/widgets/split_media_layout.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class RoomScreenContent extends StatefulWidget {
  final String roomId;
  final List<String> participants;
  final Map<String, String> userNames;
  final String hostId;
  final String currentUserId;
  final bool isHost;
  final String? driveFileName;
  final String? driveFileId;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onLeave;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onPlayVideo;
  final bool isInPiPMode;

  const RoomScreenContent({
    super.key,
    required this.roomId,
    required this.participants,
    required this.userNames,
    required this.hostId,
    required this.currentUserId,
    required this.isHost,
    this.driveFileName,
    this.driveFileId,
    required this.scaffoldKey,
    required this.onLeave,
    required this.onPickVideo,
    required this.onSelectVideo,
    required this.onPlayVideo,
    this.isInPiPMode = false,
  });

  @override
  State<RoomScreenContent> createState() => _RoomScreenContentState();
}

class _RoomScreenContentState extends State<RoomScreenContent> {
  RoomLayoutMode _currentLayoutMode = RoomLayoutMode.normal;
  String? _lastSharingUserId;

  @override
  void dispose() {
    // Reset orientation when leaving the room
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isInPiPMode) {
      return _buildPiPView();
    }

    return Scaffold(
      key: widget.scaffoldKey,
      endDrawer: Drawer(
        width: context.dynamicWidth(0.85),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ChatWidget(
          roomId: widget.roomId,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: const Color(0xFF1A1D21),
      body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          if (state is! RoomJoined) {
            return const Center(child: CircularProgressIndicator());
          }

          // Check if ANYONE is sharing screen
          final sharingUserEntry = state.usersState.entries
              .where((e) => e.value.isScreenSharing)
              .firstOrNull;

          final isAnyoneSharing = sharingUserEntry != null;

          // Auto-switch mode based on sharing status
          if (isAnyoneSharing) {
            if (_lastSharingUserId != sharingUserEntry.key) {
              // Someone NEW started sharing -> Default to immersive for them
              _lastSharingUserId = sharingUserEntry.key;
              _currentLayoutMode = RoomLayoutMode.immersive;
            }
          } else {
            // No one sharing -> Back to normal
            if (_lastSharingUserId != null) {
              // Just stopped sharing -> Reset orientation to portrait
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
            }
            _lastSharingUserId = null;
            _currentLayoutMode = RoomLayoutMode.normal;
          }

          // 1. IMMERSIVE MODE (Fullscreen Share)
          if (isAnyoneSharing &&
              _currentLayoutMode == RoomLayoutMode.immersive) {
            return BlocBuilder<CallBloc, CallState>(
              builder: (context, callState) {
                if (callState is! CallConnected) return const SizedBox.shrink();

                return ScreenShareFullscreenView(
                  callState: callState,
                  sharingUserId: sharingUserEntry.key,
                  currentUserId: widget.currentUserId,
                  userNames: widget.userNames,
                  onToggleSplit: () {
                    setState(() {
                      _currentLayoutMode = RoomLayoutMode.split;
                    });
                  },
                  onToggleOrientation: _toggleOrientation,
                );
              },
            );
          }

          // 2. SPLIT MODE (Share top, Room controls bottom)
          if (isAnyoneSharing && _currentLayoutMode == RoomLayoutMode.split) {
            return BlocBuilder<CallBloc, CallState>(
              builder: (context, callState) {
                if (callState is! CallConnected) return const SizedBox.shrink();

                return Stack(
                  children: [
                    SplitMediaLayout(
                      callState: callState,
                      sharingUserId: sharingUserEntry.key,
                      currentUserId: widget.currentUserId,
                      userNames: widget.userNames,
                      roomId: widget.roomId,
                      participants: widget.participants,
                      hostId: widget.hostId,
                      isHost: widget.isHost,
                      usersState: state.usersState,
                      driveFileName: widget.driveFileName,
                      driveFileId: widget.driveFileId,
                      onPickVideo: widget.onPickVideo,
                      onSelectVideo: widget.onSelectVideo,
                      onPlayVideo: widget.onPlayVideo,
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: RoomTopBar(
                          roomId: widget.roomId,
                          scaffoldKey: widget.scaffoldKey,
                          onLeave: widget.onLeave,
                        ),
                      ),
                    ),
                    // Layout switcher button overlay (back to immersive)
                    Positioned(
                      top: 100, // Below TopBar
                      right: 16,
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.black54,
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _currentLayoutMode = RoomLayoutMode.immersive;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }

          // 3. NORMAL MODE (Seating Layout)
          return Stack(
            children: [
              Positioned.fill(
                child: RoomSeatingWidget(
                  participants: widget.participants,
                  userNames: widget.userNames,
                  isHost: widget.isHost,
                  currentUserId: widget.currentUserId,
                  roomId: widget.roomId,
                  hostId: widget.hostId,
                  usersState: state.usersState,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    RoomTopBar(
                      roomId: widget.roomId,
                      scaffoldKey: widget.scaffoldKey,
                      onLeave: widget.onLeave,
                    ),
                    ParticipantVideoRow(
                      participants: widget.participants,
                      userNames: widget.userNames,
                      currentUserId: widget.currentUserId,
                      roomId: widget.roomId,
                      hostId: widget.hostId,
                      usersState: (state as RoomJoined).usersState,
                    ),
                    const Spacer(),
                    VideoControlSheet(
                      isHost: widget.isHost,
                      roomId: widget.roomId,
                      fileName: widget.driveFileName,
                      fileId: widget.driveFileId,
                      onPickVideo: widget.onPickVideo,
                      onSelectVideo: widget.onSelectVideo,
                      onPlay: widget.onPlayVideo,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPiPView() {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, chatState) {
        final messages = chatState is ChatLoaded
            ? chatState.messages
            : <ChatMessage>[];
        // Show last 3 messages
        final recentMessages = messages.length > 3
            ? messages.sublist(messages.length - 3)
            : messages;

        return BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state is! CallConnected) {
              return const Scaffold(
                backgroundColor: Color(0xFF1A1D21),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              backgroundColor: const Color(0xFF1A1D21),
              body: Stack(
                children: [
                  // Message Layer (Top)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 60, // Leave space for controls
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: recentMessages.map((msg) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 10),
                                children: [
                                  TextSpan(
                                    text: "${msg.senderName}: ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg.text,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Control Layer (Bottom)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PipButton(
                                icon: state.isMuted ? Icons.mic_off : Icons.mic,
                                color: state.isMuted
                                    ? Colors.red
                                    : Colors.green,
                                onPressed: () =>
                                    context.read<CallBloc>().add(ToggleMute()),
                              ),
                              const SizedBox(width: 6),
                              _PipButton(
                                icon: state.isVideoEnabled
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                                color: state.isVideoEnabled
                                    ? Colors.blue
                                    : Colors.red,
                                onPressed: () =>
                                    context.read<CallBloc>().add(ToggleVideo()),
                              ),
                              const SizedBox(width: 6),
                              _PipButton(
                                icon: Icons.stop_circle_rounded,
                                color: Colors.orange,
                                onPressed: () => context.read<CallBloc>().add(
                                  const ToggleScreenShare(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _PipButton(
                                icon: Icons.high_quality_rounded,
                                color: Colors.purpleAccent,
                                onPressed: () {
                                  final current = state.currentQuality;
                                  final next = _getNextQuality(current);
                                  context.read<CallBloc>().add(
                                    ChangeQuality(next),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (state.currentQuality !=
                              CallQualityPreset.balanced)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                state.currentQuality.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  CallQualityPreset _getNextQuality(CallQualityPreset current) {
    switch (current) {
      case CallQualityPreset.low:
        return CallQualityPreset.balanced;
      case CallQualityPreset.balanced:
        return CallQualityPreset.high;
      case CallQualityPreset.high:
        return CallQualityPreset.ultra;
      case CallQualityPreset.ultra:
        return CallQualityPreset.low;
    }
  }
}

class _PipButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _PipButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
