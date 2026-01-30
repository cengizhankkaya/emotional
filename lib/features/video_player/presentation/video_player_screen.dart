import 'dart:async';
import 'dart:io';

import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/video_player/presentation/logic/video_sync_manager.dart';
import 'package:emotional/features/video_player/presentation/widgets/video_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/presentation/call_widget.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({super.key, required this.videoFile});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late final VideoSyncManager _syncManager;
  bool _isChatVisible = true;
  double? _callOffsetX;
  double? _callOffsetY;

  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _syncManager = VideoSyncManager(player: _player, context: context);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    await _player.open(Media(widget.videoFile.path), play: false);
    _setupListeners();
    _syncManager.syncWithRoomState();
  }

  // ... existing subscriptions ...

  late RoomBloc _roomBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _roomBloc = context.read<RoomBloc>();
    if (_callOffsetX == null || _callOffsetY == null) {
      final size = MediaQuery.of(context).size;
      // Default to Top-Right (similar to previous fixed position)
      // Width of widget is roughly 300-400. Let's start with enough space.
      _callOffsetX = size.width - 320;
      _callOffsetY = 20;
    }
  }

  void _setupListeners() {
    _playingSubscription = _player.stream.playing.listen((isPlaying) {
      _syncManager.onPlayerStateUpdate(isPlaying: isPlaying);
    });

    _positionSubscription = _player.stream.position.listen((position) {
      _syncManager.onPlayerStateUpdate(position: position);
    });
  }

  @override
  void dispose() {
    // Leave Room
    final state = _roomBloc.state;
    String? roomId;
    String? userId;

    if (state is RoomJoined) {
      roomId = state.roomId;
      userId = state.userId;
    } else if (state is RoomCreated) {
      roomId = state.roomId;
      userId = state.userId;
    }

    if (roomId != null && userId != null) {
      _roomBloc.add(LeaveRoomRequested(roomId: roomId, userId: userId));
    }

    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _onToggleCall(BuildContext context) {
    final callBloc = context.read<CallBloc>();
    final roomState = context.read<RoomBloc>().state;

    if (callBloc.state is CallConnected) {
      callBloc.add(LeaveCall());
    } else {
      String roomId = '';
      String userId =
          ''; // Need to get userId. RoomBloc usually has it or we pass it?
      // RoomBloc state usually has room details but maybe not current UserId explicitly if it's not stored in state directly?
      // Actually roomState usually has 'userId' or we can get it from RoomRepository/Auth?
      // Assuming RoomJoined state has userId or we generated it.
      // Checking RoomRepository source: createRoom takes userId.
      // RoomBloc likely stores userId in state.
      // Let's assume RoomBloc state has userId.

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
  }

  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        Center(
          child: Builder(
            builder: (context) {
              return MaterialVideoControlsTheme(
                normal: MaterialVideoControlsThemeData(
                  topButtonBar: [
                    const Spacer(),
                    // Call Button
                    BlocBuilder<CallBloc, CallState>(
                      builder: (context, callState) {
                        final isConnected = callState is CallConnected;
                        return MaterialCustomButton(
                          onPressed: () => _onToggleCall(context),
                          icon: Icon(
                            isConnected ? Icons.videocam_off : Icons.videocam,
                            color: isConnected ? Colors.red : Colors.white,
                          ),
                        );
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
                          VideoSettingsModal.show(context, _player),
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ],
                ),
                fullscreen: MaterialVideoControlsThemeData(
                  topButtonBar: [
                    const Spacer(),
                    BlocBuilder<CallBloc, CallState>(
                      builder: (context, callState) {
                        final isConnected = callState is CallConnected;
                        return MaterialCustomButton(
                          onPressed: () => _onToggleCall(context),
                          icon: Icon(
                            isConnected ? Icons.videocam_off : Icons.videocam,
                            color: isConnected ? Colors.red : Colors.white,
                          ),
                        );
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
                          VideoSettingsModal.show(context, _player),
                      icon: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ],
                ),
                child: Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                ),
              );
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ChatBloc(chatRepository: ChatRepository()),
        ),
        BlocProvider(create: (_) => CallBloc(roomRepository: RoomRepository())),
      ],
      child: BlocListener<RoomBloc, RoomState>(
        listener: (context, state) => _syncManager.onRoomStateChanged(state),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                OrientationBuilder(
                  builder: (context, orientation) {
                    final isLandscape = orientation == Orientation.landscape;

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
                              ? SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width *
                                      9 /
                                      16,
                                  child: _buildVideoPlayer(),
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
                // Draggable Call Widget & Controls if needed
                // Draggable Call Widget & Controls
                Positioned(
                  top: _callOffsetY ?? 20,
                  left: _callOffsetX ?? 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _callOffsetX = (_callOffsetX ?? 20) + details.delta.dx;
                        _callOffsetY = (_callOffsetY ?? 20) + details.delta.dy;
                      });
                    },
                    child: BlocBuilder<CallBloc, CallState>(
                      builder: (context, state) {
                        if (state is! CallConnected)
                          return const SizedBox.shrink();
                        return const CallWidget();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isChatVisible(BuildContext context) => _isChatVisible;
}
