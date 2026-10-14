import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/responsiveness/web_layout.dart';
import 'package:emotional/product/widget/pinned_bottom_scroll_view.dart';
import 'package:emotional/features/room/presentation/widgets/screen_share_video_view.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Screen share next to the room controls.
///
/// Portrait screens stack the share above the controls. Wide screens
/// (desktop browsers, landscape phones) put them side by side, so the share
/// keeps a usable size and nothing overlaps it.
class SplitMediaLayout extends StatelessWidget {
  final CallConnected callState;
  final String sharingUserId;
  final String currentUserId;
  final Map<String, String> userNames;
  final Map<String, UserMediaState> usersState;

  // Room props for the controls panel
  final String roomId;
  final List<String> participants;
  final String hostId;
  final bool isHost;
  final String? driveFileName;
  final String? driveFileId;
  final VoidCallback onPickVideo;
  final void Function(drive.File) onSelectVideo;
  final VoidCallback onPlayVideo;

  final Widget topBar;
  final VoidCallback onEnterFullscreen;

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
    required this.topBar,
    required this.onEnterFullscreen,
  });

  static const double _wideMinWidth = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= _wideMinWidth &&
            constraints.maxWidth > constraints.maxHeight;
        return isWide
            ? _buildSideBySide(constraints.maxWidth)
            : _buildStacked();
      },
    );
  }

  Widget _buildSideBySide(double width) {
    final panelWidth = (width * 0.3).clamp(340.0, 440.0);
    return SafeArea(
      child: Column(
        children: [
          topBar,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSharePane(showFullscreenButton: true)),
                SizedBox(width: panelWidth, child: _buildControlsPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStacked() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(flex: 5, child: _buildSharePane()),
            Expanded(flex: 5, child: _buildControlsPanel()),
          ],
        ),
        SafeArea(
          child: Align(alignment: Alignment.topCenter, child: topBar),
        ),
        // Below the top bar, which overlays the share here.
        Positioned(
          top: 100,
          right: 16,
          child: _FullscreenButton(onPressed: onEnterFullscreen),
        ),
      ],
    );
  }

  Widget _buildSharePane({bool showFullscreenButton = false}) {
    final isMe = sharingUserId == currentUserId;
    final renderer = isMe
        ? callState.localRenderer
        : callState.remoteRenderers[sharingUserId];

    return Container(
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
            if (renderer != null) ScreenShareVideoView(renderer),

            // Simple overlay indicator
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            if (showFullscreenButton)
              Positioned(
                top: 8,
                right: 8,
                child: _FullscreenButton(onPressed: onEnterFullscreen),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return PinnedBottomScrollView(
      top: ParticipantVideoRow(
        participants: participants,
        userNames: userNames,
        currentUserId: currentUserId,
        roomId: roomId,
        hostId: hostId,
        usersState: usersState,
      ),
      bottom: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WebContentWidth(
          maxWidth: 640,
          child: VideoControlSheet(
            isHost: isHost,
            roomId: roomId,
            fileName: driveFileName,
            fileId: driveFileId,
            onPickVideo: onPickVideo,
            onSelectVideo: onSelectVideo,
            onPlay: onPlayVideo,
          ),
        ),
      ),
    );
  }
}

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      backgroundColor: Colors.black54,
      onPressed: onPressed,
      child: const Icon(Icons.fullscreen, color: Colors.white),
    );
  }
}
