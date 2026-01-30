import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallWidget extends StatefulWidget {
  const CallWidget({super.key});

  @override
  State<CallWidget> createState() => _CallWidgetState();
}

class _CallWidgetState extends State<CallWidget> {
  bool _areControlsVisible = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        if (state is CallConnected) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: null, // Auto width always
            constraints: const BoxConstraints(maxWidth: 320),
            padding: _areControlsVisible
                ? const EdgeInsets.all(8)
                : EdgeInsets.zero,
            decoration: _areControlsVisible
                ? BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  )
                : const BoxDecoration(color: Colors.transparent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header / Toggle Area (Added for better UX)
                Column(
                  children: [
                    // Video List
                    SizedBox(
                      height: 90,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Local User - Filter if disabled
                            if (state.isVideoEnabled)
                              _buildVideoItem(state.localRenderer, true, 'You'),

                            // Remote Users - Iterate strictly over activeUsers
                            ...state.activeUsers.entries.map((entry) {
                              final userId = entry.key;
                              final userName = entry.value;

                              // Skip local user in this loop
                              if (userId == context.read<CallBloc>().userId)
                                return const SizedBox.shrink();

                              final renderer = state.remoteRenderers[userId];
                              bool hasVideo = false;

                              if (renderer != null &&
                                  renderer.srcObject != null) {
                                final videoTracks = renderer.srcObject!
                                    .getVideoTracks();
                                // Check track enablement
                                final trackEnabled =
                                    videoTracks.isNotEmpty &&
                                    videoTracks.first.enabled;

                                // Check Firebase state (source of truth for "active" video)
                                final firebaseVideoEnabled =
                                    state.userVideoStates[userId] ?? false;

                                // Require BOTH for positive video display check to avoid black frames,
                                // but primarily rely on Firebase state to know if we SHOULD failover to avatar.
                                if (trackEnabled && firebaseVideoEnabled) {
                                  hasVideo = true;
                                }
                              }

                              if (hasVideo) {
                                return _buildVideoItem(
                                  renderer!,
                                  false,
                                  userName,
                                );
                              } else {
                                // Only show avatar if controls are visible (expanded)
                                if (_areControlsVisible) {
                                  return _buildAvatarItem(userName);
                                }
                                return const SizedBox.shrink();
                              }
                            }),
                          ],
                        ),
                      ),
                    ),
                    // Collapse Indicator
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _areControlsVisible = !_areControlsVisible;
                        });
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        child: Icon(
                          _areControlsVisible
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                // Controls
                AnimatedCrossFade(
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlBtn(
                          icon: state.isMuted ? Icons.mic_off : Icons.mic,
                          color: state.isMuted
                              ? Colors.redAccent
                              : Colors.white,
                          onPressed: () =>
                              context.read<CallBloc>().add(ToggleMute()),
                        ),
                        _buildControlBtn(
                          icon: state.isVideoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          color: state.isVideoEnabled
                              ? Colors.white
                              : Colors.redAccent,
                          onPressed: () =>
                              context.read<CallBloc>().add(ToggleVideo()),
                        ),
                        _buildControlBtn(
                          icon: Icons.cameraswitch,
                          color: Colors.white,
                          onPressed: () =>
                              context.read<CallBloc>().add(SwitchCamera()),
                        ),
                        _buildControlBtn(
                          icon: Icons.call_end,
                          color: Colors.redAccent,
                          onPressed: () =>
                              context.read<CallBloc>().add(LeaveCall()),
                          backgroundColor: Colors.white10,
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _areControlsVisible
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildVideoItem(
    RTCVideoRenderer renderer,
    bool isLocal,
    String userName,
  ) {
    return Container(
      width: 160,
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: isLocal,
            ),
            if (isLocal)
              Positioned(
                bottom: 4,
                right: 4,
                child: Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarItem(String userName) {
    // Get initials
    String initials = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    if (userName.contains(' ') && userName.split(' ').length > 1) {
      initials += userName.split(' ')[1][0].toUpperCase();
    }

    return Container(
      width: 160,
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white10,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userName,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
