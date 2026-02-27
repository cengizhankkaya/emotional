import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenShareFullscreenView extends StatefulWidget {
  final CallConnected callState;
  final String sharingUserId;
  final String currentUserId;
  final Map<String, String> userNames;
  final VoidCallback onToggleSplit;
  final VoidCallback onToggleOrientation;

  const ScreenShareFullscreenView({
    super.key,
    required this.callState,
    required this.sharingUserId,
    required this.currentUserId,
    required this.userNames,
    required this.onToggleSplit,
    required this.onToggleOrientation,
  });

  @override
  State<ScreenShareFullscreenView> createState() =>
      _ScreenShareFullscreenViewState();
}

class _ScreenShareFullscreenViewState extends State<ScreenShareFullscreenView> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    final isMe = widget.sharingUserId == widget.currentUserId;
    final renderer = isMe
        ? widget.callState.localRenderer
        : widget.callState.remoteRenderers[widget.sharingUserId];

    if (renderer == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Blurred Background layer (fill aspect ratio gaps)
            Positioned.fill(
              child: Opacity(
                opacity: 0.6,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: RTCVideoView(
                    renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

            // 2. Main Content layer
            Center(
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              ),
            ),

            // 3. Floating Glass Control Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              bottom: _showControls ? context.dynamicHeight(0.04) : -120,
              left: context.dynamicWidth(0.05),
              right: context.dynamicWidth(0.05),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _FloatingControlBar(
                    isMe: isMe,
                    callState: widget.callState,
                    sharingUserName:
                        widget.userNames[widget.sharingUserId] ??
                        LocaleKeys.room_someone.tr(),
                    onToggleSplit: widget.onToggleSplit,
                    onToggleOrientation: widget.onToggleOrientation,
                    onHide: () => setState(() => _showControls = false),
                  ),
                ),
              ),
            ),

            // 4. Participant Overlay (Top Right)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              top: _showControls ? context.dynamicHeight(0.06) : -250,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showControls ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _ParticipantOverlay(
                    callState: widget.callState,
                    currentUserId: widget.currentUserId,
                    userNames: widget.userNames,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingControlBar extends StatelessWidget {
  final bool isMe;
  final CallConnected callState;
  final String sharingUserName;
  final VoidCallback onToggleSplit;
  final VoidCallback onToggleOrientation;
  final VoidCallback onHide;

  const _FloatingControlBar({
    required this.isMe,
    required this.callState,
    required this.sharingUserName,
    required this.onToggleSplit,
    required this.onToggleOrientation,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMe) ...[
                  _ControlButton(
                    icon: Icons.stop_screen_share,
                    label: LocaleKeys.call_stopSharing.tr(),
                    color: Colors.redAccent,
                    onPressed: () =>
                        context.read<CallBloc>().add(ToggleScreenShare()),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      LocaleKeys.call_sharing.tr(args: [sharingUserName]),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                _ControlButton(
                  icon: Icons.sync_rounded,
                  label: LocaleKeys.call_rotate.tr(),
                  color: Colors.orangeAccent,
                  onPressed: onToggleOrientation,
                ),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: Icons.grid_view_rounded,
                  label: LocaleKeys.call_splitScreen.tr(),
                  color: Colors.deepPurpleAccent,
                  onPressed: onToggleSplit,
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: Colors.white24),
                const SizedBox(width: 8),
                _ControlButton(
                  icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                  color: callState.isMuted
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  onPressed: () => context.read<CallBloc>().add(ToggleMute()),
                ),
                const SizedBox(width: 4),
                _ControlButton(
                  icon: callState.isVideoEnabled
                      ? Icons.videocam
                      : Icons.videocam_off,
                  color: callState.isVideoEnabled
                      ? Colors.blueAccent
                      : Colors.redAccent,
                  onPressed: () => context.read<CallBloc>().add(ToggleVideo()),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildQualityButton(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityButton(BuildContext context) {
    final current = callState.currentQuality;
    return PopupMenuButton<CallQualityPreset>(
      initialValue: current,
      tooltip: LocaleKeys.call_streamQuality.tr(),
      onSelected: (quality) =>
          context.read<CallBloc>().add(ChangeQuality(quality)),
      itemBuilder: (context) => CallQualityPreset.values
          .map(
            (q) => PopupMenuItem(
              value: q,
              child: Row(
                children: [
                  Icon(
                    q == current ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: q == current ? Colors.blueAccent : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(q.displayName, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Icon(
          Icons.high_quality_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white.withOpacity(0.15);
    final isTransparent = color == Colors.transparent;

    return label != null
        ? InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: effectiveColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: effectiveColor.withOpacity(0.9), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: !isTransparent
                  ? Border.all(color: effectiveColor.withOpacity(0.3))
                  : null,
              boxShadow: !isTransparent
                  ? [
                      BoxShadow(
                        color: effectiveColor.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(
                icon,
                color: effectiveColor.withOpacity(0.9),
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: !isTransparent
                    ? effectiveColor.withOpacity(0.15)
                    : Colors.transparent,
                padding: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
  }
}

class _ParticipantOverlay extends StatelessWidget {
  final CallConnected callState;
  final String currentUserId;
  final Map<String, String> userNames;

  const _ParticipantOverlay({
    required this.callState,
    required this.currentUserId,
    required this.userNames,
  });

  @override
  Widget build(BuildContext context) {
    final participants = callState.activeUsers.keys.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: participants.map((uid) {
        final name = userNames[uid] ?? LocaleKeys.room_someone.tr();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.blueAccent,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                uid == currentUserId ? LocaleKeys.room_me.tr() : name,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      }).toList(),
    );
  }
}
