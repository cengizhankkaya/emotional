import 'dart:async';
import 'dart:io';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/presentation/call_widget.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/bloc/video_player_state.dart';
import 'package:emotional/features/video_player/presentation/logic/video_sync_manager.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({super.key, required this.videoFile});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // late final Player _player; // Removed local player
  // late final VideoController _controller; // Removed local controller
  VideoSyncManager? _syncManager; // Nullable now as we wait for player
  bool _isChatVisible = true;
  double? _callOffsetX;
  double? _callOffsetY;
  bool _isCallDragging = false;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize global player
    context.read<VideoPlayerBloc>().add(InitializePlayer(widget.videoFile));
  }

  void _initializeSyncManager(Player player) {
    if (_syncManager != null) return;
    _syncManager = VideoSyncManager(player: player, context: context);
    _setupListeners(player);
    _syncManager!.syncWithRoomState();
  }

  // ... existing subscriptions ...

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_callOffsetX == null || _callOffsetY == null) {
      final size = MediaQuery.of(context).size;
      _callOffsetX = size.width - 320;
      _callOffsetY = 20;
    }
  }

  void _ensureCallVisible(Size size) {
    if (_callOffsetX == null || _callOffsetY == null) return;

    final widgetWidth = context.dynamicValue(320.0);
    const widgetHeight = 200.0; // Reasonable estimate for clamping
    const padding = 16.0;

    // Check if current offsets are outside the new screen size bounds
    double newX = _callOffsetX!;
    double newY = _callOffsetY!;

    if (newX + widgetWidth > size.width) {
      newX = size.width - widgetWidth - padding;
    }
    if (newY + widgetHeight > size.height) {
      newY = size.height - widgetHeight - padding;
    }

    // Always clamp to positive at least
    newX = newX.clamp(padding, size.width - widgetWidth - padding);
    newY = newY.clamp(padding, size.height - widgetHeight - padding);

    if (newX != _callOffsetX || newY != _callOffsetY) {
      // Use schedulePostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _callOffsetX = newX;
            _callOffsetY = newY;
          });
        }
      });
    }
  }

  void _onCallPanEnd(DragEndDetails details) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final widgetWidth = context.dynamicValue(320.0);
    const padding = 16.0;

    double targetX = _callOffsetX ?? padding;
    double targetY = _callOffsetY ?? padding;

    // Horizontal snap
    if (targetX + widgetWidth / 2 < size.width / 2) {
      targetX = padding;
    } else {
      targetX = size.width - widgetWidth - padding;
    }

    // Vertical clamp - allow it to practically use the whole screen
    // Final safe position should at least show some of the card.
    targetY = targetY.clamp(0.0, size.height - 100.0);

    setState(() {
      _isCallDragging = false;
      _callOffsetX = targetX;
      _callOffsetY = targetY;
    });
  }

  void _setupListeners(Player player) {
    _playingSubscription = player.stream.playing.listen((isPlaying) {
      _syncManager?.onPlayerStateUpdate(isPlaying: isPlaying);
    });

    _positionSubscription = player.stream.position.listen((position) {
      _syncManager?.onPlayerStateUpdate(position: position);
    });
  }

  @override
  void dispose() {
    // Reset orientation to portrait when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    // Do NOT dispose _player here, as it is global now.
    // The Bloc handles disposal on ClosePlayer event.
    super.dispose();
  }

  void _toggleFullscreen() {
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

  void _onJoinCall(BuildContext context) {
    final callBloc = context.read<CallBloc>();
    final roomState = context.read<RoomBloc>().state;

    String roomId = '';
    String userId = '';

    if (roomState is RoomJoined) {
      roomId = roomState.roomId;
      userId = roomState.userId;
    } else if (roomState is RoomCreated) {
      roomId = roomState.roomId;
      userId = roomState.userId;
    }

    if (roomId.isNotEmpty && userId.isNotEmpty) {
      callBloc.add(JoinCall(roomId: roomId, userId: userId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot join call: User/Room info missing'),
        ),
      );
    }
  }

  void _onToggleVideo(BuildContext context) {
    context.read<CallBloc>().add(ToggleVideo());
  }

  void _onLeaveCall(BuildContext context) {
    context.read<CallBloc>().add(LeaveCall());
  }

  Widget _buildVideoPlayer() {
    // Capture the CallBloc from the current valid context
    final callBloc = context.read<CallBloc>();

    return Stack(
      children: [
        Center(
          child: BlocConsumer<VideoPlayerBloc, VideoPlayerState>(
            listener: (context, state) {
              if (state is VideoPlayerActive) {
                // Initialize sync manager if needed
                _initializeSyncManager(state.player);
              }
            },
            builder: (context, vpState) {
              if (vpState is VideoPlayerInitial) {
                return const CircularProgressIndicator();
              }
              if (vpState is VideoPlayerActive) {
                return MaterialVideoControlsTheme(
                  normal: MaterialVideoControlsThemeData(
                    padding: const EdgeInsets.only(
                      bottom: 20,
                      left: 10,
                      right: 10,
                      top: 10,
                    ),
                    bottomButtonBar: [
                      const MaterialPositionIndicator(),
                      const Spacer(),
                      MaterialCustomButton(
                        onPressed: _toggleFullscreen,
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                    topButtonBar: [
                      TextButton.icon(
                        onPressed: () {
                          context.read<VideoPlayerBloc>().add(
                            const ToggleMinimize(isMinimized: true),
                          );
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "Odaya Dön",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // Call Controls
                      BlocBuilder<CallBloc, CallState>(
                        bloc: callBloc, // Explicitly pass the bloc
                        builder: (blocContext, callState) {
                          final isConnected = callState is CallConnected;
                          if (!isConnected) {
                            // Join Button
                            return MaterialCustomButton(
                              onPressed: () => _onJoinCall(context),
                              icon: const Icon(
                                Icons.videocam,
                                color: Colors.white,
                              ),
                            );
                          } else {
                            // Connected: Toggle Video + End Call
                            final isVideoEnabled = callState.isVideoEnabled;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MaterialCustomButton(
                                  onPressed: () => _onToggleVideo(context),
                                  icon: Icon(
                                    isVideoEnabled
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    color: Colors.white,
                                  ),
                                ),
                                MaterialCustomButton(
                                  onPressed: () => _onLeaveCall(context),
                                  icon: const Icon(
                                    Icons.call_end,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      MaterialCustomButton(
                        onPressed: () {
                          setState(() {
                            _isChatVisible = !_isChatVisible;
                          });
                        },
                        icon: Icon(
                          _isChatVisible
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                          color: Colors.white,
                        ),
                      ),
                      MaterialCustomButton(
                        onPressed: () =>
                            VideoSettingsModal.show(context, vpState.player),
                        icon: const Icon(Icons.settings, color: Colors.white),
                      ),
                    ],
                  ),
                  fullscreen: MaterialVideoControlsThemeData(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      top: 16,
                    ), // More padding for fullscreen
                    bottomButtonBar: [
                      // const Expanded(child: MaterialSeekBar()),
                      const MaterialPositionIndicator(),
                      const Spacer(),
                      MaterialCustomButton(
                        onPressed: _toggleFullscreen,
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ],
                    topButtonBar: [
                      TextButton.icon(
                        onPressed: () {
                          context.read<VideoPlayerBloc>().add(
                            const ToggleMinimize(isMinimized: true),
                          );
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "Odaya Dön",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      BlocBuilder<CallBloc, CallState>(
                        bloc: callBloc, // Explicitly pass the bloc
                        builder: (blocContext, callState) {
                          final isConnected = callState is CallConnected;
                          if (!isConnected) {
                            return MaterialCustomButton(
                              onPressed: () => _onJoinCall(context),
                              icon: const Icon(
                                Icons.videocam,
                                color: Colors.white,
                              ),
                            );
                          } else {
                            final isVideoEnabled = callState.isVideoEnabled;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MaterialCustomButton(
                                  onPressed: () => _onToggleVideo(context),
                                  icon: Icon(
                                    isVideoEnabled
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    color: Colors.white,
                                  ),
                                ),
                                MaterialCustomButton(
                                  onPressed: () => _onLeaveCall(context),
                                  icon: const Icon(
                                    Icons.call_end,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      MaterialCustomButton(
                        onPressed: () {
                          setState(() {
                            _isChatVisible = !_isChatVisible;
                          });
                        },
                        icon: Icon(
                          _isChatVisible
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                          color: Colors.white,
                        ),
                      ),
                      MaterialCustomButton(
                        onPressed: () =>
                            VideoSettingsModal.show(context, vpState.player),
                        icon: const Icon(Icons.settings, color: Colors.white),
                      ),
                    ],
                  ),
                  child: Video(
                    controller: vpState.controller,
                    controls: MaterialVideoControls,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel({required bool isLandscape}) {
    return Container(
      width: isLandscape ? 350 : null,
      decoration: BoxDecoration(
        border: Border(
          left: isLandscape
              ? const BorderSide(color: Colors.white24, width: 1)
              : BorderSide.none,
          top: !isLandscape
              ? const BorderSide(color: Colors.white24, width: 1)
              : BorderSide.none,
        ),
      ),
      child: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          String roomId = '';
          if (state is RoomJoined) {
            roomId = state.roomId;
          } else if (state is RoomCreated) {
            roomId = state.roomId;
          }

          if (roomId.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ChatWidget(
            roomId: roomId,
            onClose: () {
              setState(() {
                _isChatVisible = false;
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoomBloc, RoomState>(
      listener: (context, state) => _syncManager?.onRoomStateChanged(state),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // User popped the screen (Back button or Navigator.pop)
            // Minimize the player
            context.read<VideoPlayerBloc>().add(
              const ToggleMinimize(isMinimized: true),
            );
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _ensureCallVisible(constraints.biggest);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OrientationBuilder(
                      builder: (context, orientation) {
                        final isLandscape =
                            orientation == Orientation.landscape;

                        if (isLandscape) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildVideoPlayer()),
                              if (_isChatVisible)
                                _buildChatPanel(isLandscape: true),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _isChatVisible
                                  ? Column(
                                      children: [
                                        SizedBox(
                                          height: context.width * 9 / 16,
                                          child: _buildVideoPlayer(),
                                        ),
                                        Container(
                                          height: context.dynamicHeight(0.02),
                                          color: Colors
                                              .black, // Explicit spacer color
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: Colors
                                              .white24, // Brighter divider
                                        ),
                                      ],
                                    )
                                  : Expanded(child: _buildVideoPlayer()),
                              if (_isChatVisible)
                                Expanded(
                                  child: _buildChatPanel(isLandscape: false),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                    // Draggable Call Widget & Controls
                    AnimatedPositioned(
                      duration: _isCallDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      top: _callOffsetY ?? 20,
                      left: _callOffsetX ?? 20,
                      child: GestureDetector(
                        onPanStart: (_) =>
                            setState(() => _isCallDragging = true),
                        onPanUpdate: (details) {
                          setState(() {
                            _callOffsetX =
                                (_callOffsetX ?? 20) + details.delta.dx;
                            _callOffsetY =
                                (_callOffsetY ?? 20) + details.delta.dy;
                          });
                        },
                        onPanEnd: _onCallPanEnd,
                        onPanCancel: () =>
                            setState(() => _isCallDragging = false),
                        child: BlocBuilder<CallBloc, CallState>(
                          builder: (context, state) {
                            if (state is! CallConnected)
                              return const SizedBox.shrink();
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: context.dynamicValue(320),
                                maxHeight: context.dynamicValue(400),
                              ),
                              child: const CallWidget(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ), // Scaffold
      ), // PopScope
    ); // BlocListener
  }

  bool isChatVisible(BuildContext context) => _isChatVisible;
}
