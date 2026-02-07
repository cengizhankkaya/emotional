import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/room_seating_widget.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class RoomScreenContent extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      endDrawer: Drawer(
        width: context.dynamicWidth(0.85),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ChatWidget(
          roomId: roomId,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: const Color(0xFF1A1D21),
      body: Stack(
        children: [
          // Background Room Layout
          Positioned.fill(
            child: RoomSeatingWidget(
              participants: participants,
              userNames: userNames,
              isHost: isHost,
              currentUserId: currentUserId,
              roomId: roomId,
              hostId: hostId,
            ),
          ),
          // UI Overlay
          SafeArea(
            child: Column(
              children: [
                RoomTopBar(
                  roomId: roomId,
                  scaffoldKey: scaffoldKey,
                  onLeave: onLeave,
                ),
                ParticipantVideoRow(
                  participants: participants,
                  userNames: userNames,
                  currentUserId: currentUserId,
                  roomId: roomId,
                  hostId: hostId,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
