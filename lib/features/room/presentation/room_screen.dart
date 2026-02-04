import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/manager/floating_message_manager.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/furniture_theme_data.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final DownloadManager _downloadManager;
  late final FloatingMessageManager _floatingMessageManager;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _downloadManager = DownloadManager();
    _downloadManager.setOnStateChanged(() {
      if (mounted) setState(() {});
    });
    _downloadManager.setOnError((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
    _downloadManager.initialize();

    _floatingMessageManager = FloatingMessageManager();

    // Load downloaded videos after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driveService = context.read<DriveService>();
      _downloadManager.loadDownloadedVideos(driveService);

      // Check if already joined to auto-start call
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined) {
        context.read<CallBloc>().add(
          JoinCall(roomId: roomState.roomId, userId: roomState.userId),
        );
        // Check if video already exists on re-entry
        if (roomState.driveFileName != null) {
          _downloadManager.checkFileExists(roomState.driveFileName!);
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh database or state when app comes back
      // Download checks etc.
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined && roomState.driveFileName != null) {
        _downloadManager.checkFileExists(roomState.driveFileName!);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadManager.dispose();
    _floatingMessageManager.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(String roomId) async {
    if (!mounted) return;
    final file = await Navigator.push<drive.File>(
      context,
      MaterialPageRoute(builder: (_) => const DriveFilePickerScreen()),
    );

    if (mounted) {
      _downloadManager.loadDownloadedVideos(context.read<DriveService>());
    }

    if (file != null && mounted) {
      _selectVideo(roomId, file);
    }
  }

  void _selectVideo(String roomId, drive.File file) {
    context.read<RoomBloc>().add(
      UpdateRoomVideoRequested(
        roomId: roomId,
        fileId: file.id!,
        fileName: file.name!,
        fileSize: file.size ?? '0',
      ),
    );
  }

  void _handleDownloadOrPlay(String fileId, String fileName) {
    if (_downloadManager.isVideoDownloaded &&
        _downloadManager.localVideoFile != null) {
      final roomState = context.read<RoomBloc>().state;
      String currentRoomId = '';
      String currentUserId = '';

      if (roomState is RoomJoined) {
        currentRoomId = roomState.roomId;
        currentUserId = roomState.userId;
      } else if (roomState is RoomCreated) {
        currentRoomId = roomState.roomId;
        currentUserId = roomState.userId;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoFile: _downloadManager.localVideoFile!,
            roomId: currentRoomId,
            userId: currentUserId,
          ),
        ),
      );
    } else {
      _downloadManager.downloadVideo(
        context.read<DriveService>(),
        fileId,
        fileName,
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomBloc, RoomState>(
      listenWhen: (prev, curr) {
        if (curr is RoomError || curr is RoomInitial) return true;
        if (curr is RoomJoined) {
          if (prev is! RoomJoined) return true;
          return prev.driveFileName != curr.driveFileName;
        }
        return false;
      },
      listener: (context, state) {
        if (state is RoomError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is RoomInitial) {
          if (!_isLeaving) {
            _isLeaving = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Oda kapatıldı veya odadan ayrıldınız.'),
              ),
            );
            Navigator.of(context).pop();
          }
        } else if (state is RoomJoined) {
          // Join the call when room is joined, but only if not already connected
          final callState = context.read<CallBloc>().state;
          if (callState is! CallConnected ||
              context.read<CallBloc>().userId != state.userId) {
            context.read<CallBloc>().add(
              JoinCall(roomId: state.roomId, userId: state.userId),
            );
          }

          if (state.driveFileName != null) {
            _downloadManager.checkFileExists(state.driveFileName!);
          }
        }
      },
      builder: (context, state) {
        if (state is! RoomJoined) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final roomState = state;
        final roomId = roomState.roomId;
        final participants = roomState.participants;
        final userNames = roomState.userNames;
        final hostId = roomState.hostId;
        final currentUserId =
            (context.read<AuthBloc>().state as AuthAuthenticated).user.uid;
        final isHost = currentUserId == hostId;

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && !_isLeaving) {
              _isLeaving = true;
              print('RoomScreen: Pop detected, cleaning up room and call.');
              // Ensure we leave the call and the room when the screen is closed (popped)
              context.read<CallBloc>().add(LeaveCall());
              context.read<RoomBloc>().add(
                LeaveRoomRequested(roomId: roomId, userId: currentUserId),
              );
            }
          },
          child: BlocProvider(
            key: ValueKey(roomId),
            create: (context) => RoomDecorationCubit(
              roomRepository: context.read<RoomRepository>(),
              roomId: roomId,
            ),
            child: BlocListener<RoomBloc, RoomState>(
              listenWhen: (previous, current) {
                if (previous is RoomJoined && current is RoomJoined) {
                  return previous.armchairStyle != current.armchairStyle;
                }
                return false;
              },
              listener: (context, state) {
                if (state is RoomJoined && state.armchairStyle != null) {
                  context.read<RoomDecorationCubit>().updateFromSync(
                    state.armchairStyle!,
                  );
                }
              },
              child: Builder(
                builder: (context) {
                  // Initialize cubit from initial room state
                  final initialStyle =
                      (context.read<RoomBloc>().state as RoomJoined)
                          .armchairStyle;
                  if (initialStyle != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<RoomDecorationCubit>().updateFromSync(
                        initialStyle,
                      );
                    });
                  }

                  // Load chat messages when room is joined
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.read<ChatBloc>().add(LoadMessages(roomId));
                  });

                  // Video State
                  final driveFileName = roomState.driveFileName;
                  final driveFileId = roomState.driveFileId;

                  return BlocListener<ChatBloc, ChatState>(
                    listener: (context, chatState) {
                      if (chatState is ChatLoaded &&
                          chatState.messages.isNotEmpty) {
                        final lastMessage = chatState.messages.last;
                        _floatingMessageManager.showFloatingMessage(
                          context,
                          lastMessage,
                          participants,
                        );
                      }
                    },
                    child: Scaffold(
                      key: _scaffoldKey,
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
                            child: _buildRoomLayout(
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
                                  scaffoldKey: _scaffoldKey,
                                ),
                                const Spacer(),
                                VideoControlSheet(
                                  isHost: isHost,
                                  roomId: roomId,
                                  fileName: driveFileName,
                                  fileId: driveFileId,
                                  downloadedVideos:
                                      _downloadManager.downloadedVideos,
                                  downloadProgress:
                                      _downloadManager.downloadProgress,
                                  downloadStatus:
                                      _downloadManager.downloadStatus,
                                  isVideoDownloaded:
                                      _downloadManager.isVideoDownloaded,
                                  localVideoFile:
                                      _downloadManager.localVideoFile,
                                  onPickVideo: () => _pickVideo(roomId),
                                  onSelectVideo: (video) =>
                                      _selectVideo(roomId, video),
                                  onDownloadOrPlay: () {
                                    if (driveFileId != null &&
                                        driveFileName != null) {
                                      _handleDownloadOrPlay(
                                        driveFileId,
                                        driveFileName,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomLayout({
    required List<String> participants,
    required Map<String, String> userNames,
    required bool isHost,
    required String currentUserId,
    required String roomId,
    required String hostId,
  }) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, callState) {
        return Center(
          child: AspectRatio(
            aspectRatio: 1024 / 747,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final style = context
                    .watch<RoomDecorationCubit>()
                    .state
                    .armchairStyle;
                final theme = FurnitureThemeData.getTheme(style);
                final isEsce = style == ArmchairStyle.esce;

                final seatPositions = isEsce
                    ? [
                        {'top': 0.90, 'left': 0.30, 'right': null},
                        {'top': 0.62, 'left': 0.51, 'right': null},
                      ]
                    : [
                        {'top': 0.27, 'left': 0.30, 'right': null},
                        {'top': 0.33, 'left': null, 'right': 0.18},
                        {'top': 0.41, 'left': 0.20, 'right': null},
                        {'top': 0.52, 'left': null, 'right': 0.06},
                        {'top': 0.52, 'left': 0.05, 'right': null},
                        {'top': 0.49, 'left': 0.52, 'right': null},
                      ];

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: theme.image != null
                          ? theme.image!.image(fit: BoxFit.cover)
                          : Container(color: theme.baseColor),
                    ),
                    ...List.generate(seatPositions.length, (index) {
                      final pos = seatPositions[index];
                      final String? participantId = index < participants.length
                          ? participants[index]
                          : null;
                      final name = participantId != null
                          ? userNames[participantId] ?? participantId
                          : null;

                      return Positioned(
                        top: constraints.maxHeight * (pos['top'] as double),
                        left: pos['left'] != null
                            ? constraints.maxWidth * (pos['left'] as double)
                            : null,
                        right: pos['right'] != null
                            ? constraints.maxWidth * (pos['right'] as double)
                            : null,
                        child: _buildAvatarSlot(
                          name,
                          participantId: participantId,
                          callState: callState,
                          currentUserId: currentUserId,
                          isParticipantHost: participantId == hostId,
                          canTransferHost:
                              isHost &&
                              participantId != null &&
                              participantId != currentUserId,
                          roomId: roomId,
                          hideAvatar: false,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarSlot(
    String? name, {
    String? participantId,
    required CallState callState,
    required String currentUserId,
    bool isParticipantHost = false,
    bool canTransferHost = false,
    String? roomId,
    bool hideAvatar = false,
  }) {
    final size = context.dynamicValue(50);
    if (name == null) {
      if (hideAvatar) return const SizedBox();
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
      );
    }

    final isLocal = participantId == currentUserId;
    bool hasVideo = false;
    bool isMuted = false;
    RTCVideoRenderer? renderer;

    if (callState is CallConnected) {
      if (isLocal) {
        hasVideo = callState.isVideoEnabled;
        isMuted = callState.isMuted;
        renderer = callState.localRenderer;
      } else if (participantId != null) {
        hasVideo = callState.userVideoStates[participantId] ?? false;
        isMuted = !(callState.userAudioStates[participantId] ?? true);
        renderer = callState.remoteRenderers[participantId];
      }
    }

    final avatarContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideAvatar)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isParticipantHost
                      ? Colors.amber[700]
                      : Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isParticipantHost ? Colors.amber : Colors.white,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size / 2),
                  child: hasVideo && renderer != null
                      ? RTCVideoView(
                          renderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: isLocal,
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
              ),
              if (isParticipantHost)
                Positioned(
                  top: -size * 0.2,
                  right: -size * 0.1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: size * 0.35,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.dynamicValue(10),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (callState is CallConnected && participantId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLocal) ...[
                        _buildMiniToggle(
                          icon: isMuted ? Icons.mic_off : Icons.mic,
                          isActive: !isMuted,
                          onTap: () =>
                              context.read<CallBloc>().add(ToggleMute()),
                        ),
                        const SizedBox(width: 2),
                        _buildMiniToggle(
                          icon: hasVideo ? Icons.videocam : Icons.videocam_off,
                          isActive: hasVideo,
                          onTap: () =>
                              context.read<CallBloc>().add(ToggleVideo()),
                        ),
                      ] else ...[
                        Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          size: 10,
                        ),
                        if (!isMuted) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.graphic_eq,
                            color: Colors.greenAccent,
                            size: 10,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (canTransferHost && roomId != null && participantId != null) {
      return GestureDetector(
        onLongPress: () {
          _showTransferHostDialog(context, roomId, participantId, name);
        },
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  Widget _buildMiniToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isActive ? Colors.greenAccent : Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black87 : Colors.white70,
          size: 12,
        ),
      ),
    );
  }

  void _showTransferHostDialog(
    BuildContext context,
    String roomId,
    String newHostId,
    String userName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('Host Devret', style: TextStyle(color: Colors.white)),
        content: Text(
          'Host yetkisini $userName kullanıcısına devretmek istiyor musunuz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<RoomBloc>().add(
                TransferHostRequested(roomId: roomId, newHostId: newHostId),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Devret', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
