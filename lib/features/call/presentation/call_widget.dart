import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

// ... (existing imports)
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:emotional/features/call/presentation/call_settings_sheet.dart';
import 'package:emotional/features/call/domain/enums/call_video_size.dart';

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
            constraints: BoxConstraints(maxWidth: context.dynamicValue(320)),
            padding: _areControlsVisible
                ? const ProjectPadding.allSmall()
                : EdgeInsets.zero,
            decoration: _areControlsVisible
                ? BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95),
                    borderRadius: ProjectRadius.medium(),
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
                      height: context.dynamicValue(90),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: context.dynamicValue(320),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Local User - Filter if disabled
                              if (state.isVideoEnabled)
                                _buildVideoItem(
                                  state.localRenderer,
                                  true,
                                  'You',
                                  state.videoSize,
                                  userId: context.read<CallBloc>().userId,
                                  isMuted: state.isMuted,
                                ),

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
                                  final audioEnabled =
                                      state.userAudioStates[userId] ?? false;
                                  return _buildVideoItem(
                                    renderer!,
                                    false,
                                    userName,
                                    state.videoSize,
                                    userId: userId,
                                    isMuted: !audioEnabled,
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
                        padding: const ProjectPadding.symmetric(
                          vertical: 4,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Resize Controls
                            if (_areControlsVisible) ...[
                              _buildResizeBtn(Icons.remove, () {
                                final current = state.videoSize;
                                if (current == CallVideoSize.large) {
                                  context.read<CallBloc>().add(
                                    const ChangeVideoSize(CallVideoSize.medium),
                                  );
                                } else if (current == CallVideoSize.medium) {
                                  context.read<CallBloc>().add(
                                    const ChangeVideoSize(CallVideoSize.small),
                                  );
                                }
                              }),
                              const SizedBox(width: 16),
                              _buildResizeBtn(Icons.add, () {
                                final current = state.videoSize;
                                if (current == CallVideoSize.small) {
                                  context.read<CallBloc>().add(
                                    const ChangeVideoSize(CallVideoSize.medium),
                                  );
                                } else if (current == CallVideoSize.medium) {
                                  context.read<CallBloc>().add(
                                    const ChangeVideoSize(CallVideoSize.large),
                                  );
                                }
                              }),
                              const SizedBox(width: 16),
                            ],
                            Icon(
                              _areControlsVisible
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white54,
                              size: context.dynamicValue(16),
                            ),
                          ],
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
                        const SizedBox(width: 8),
                        _buildControlBtn(
                          icon: Icons.settings,
                          color: Colors.white,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (c) => BlocProvider.value(
                                value: context.read<CallBloc>(),
                                child: const CallSettingsSheet(),
                              ),
                            );
                          },
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
        icon: Icon(icon, color: color, size: context.dynamicValue(18)),
        onPressed: onPressed,
        padding: const ProjectPadding.allSmall(),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildVideoItem(
    RTCVideoRenderer renderer,
    bool isLocal,
    String userName,
    CallVideoSize size, {
    String? userId,
    bool isMuted = false,
  }) {
    return Container(
      width: context.dynamicValue(size.width),
      height: context.dynamicValue(size.height),
      margin: const ProjectPadding.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: ProjectRadius.small(),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: ProjectRadius.small(),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.dynamicValue(10),
                    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
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
      width: context.dynamicValue(160),
      height: context.dynamicValue(90),
      margin: const ProjectPadding.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: ProjectRadius.small(),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: context.dynamicValue(20),
              backgroundColor: Colors.white10,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: context.dynamicHeight(0.005)),
            Text(
              userName,
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.dynamicValue(12),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.white70, size: 14),
      ),
    );
  }
}
