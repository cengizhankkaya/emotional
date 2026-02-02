import 'dart:async';
import 'dart:io';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/features/video_player/bloc/video_player_event.dart';
import 'package:emotional/features/video_player/presentation/logic/video_sync_manager.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_landscape_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_portrait_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_player_view.dart';
import 'package:emotional/features/video_player/presentation/widgets/chat_panel.dart';
import 'package:emotional/features/video_player/presentation/widgets/draggable_call_overlay.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

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

                        final videoPlayer = VideoPlayerView(
                          isChatVisible: _isChatVisible,
                          onToggleChat: () =>
                              setState(() => _isChatVisible = !_isChatVisible),
                          onJoinCall: () => _onJoinCall(context),
                          onToggleVideo: () => _onToggleVideo(context),
                          onLeaveCall: () => _onLeaveCall(context),
                          onToggleFullscreen: _toggleFullscreen,
                          onPlayerActive: _initializeSyncManager,
                        );

                        final chatPanel = ChatPanel(
                          isLandscape: isLandscape,
                          onClose: () => setState(() => _isChatVisible = false),
                        );

                        return isLandscape
                            ? VideoPlayerLandscapeView(
                                videoPlayer: videoPlayer,
                                chatPanel: chatPanel,
                                isChatVisible: _isChatVisible,
                              )
                            : VideoPlayerPortraitView(
                                videoPlayer: videoPlayer,
                                chatPanel: chatPanel,
                                isChatVisible: _isChatVisible,
                              );
                      },
                    ),
                    DraggableCallOverlay(
                      offsetX: _callOffsetX ?? 20,
                      offsetY: _callOffsetY ?? 20,
                      isDragging: _isCallDragging,
                      onPanStart: () => setState(() => _isCallDragging = true),
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
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool isChatVisible(BuildContext context) => _isChatVisible;
}
