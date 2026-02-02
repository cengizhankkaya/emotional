import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
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
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final DownloadManager _downloadManager;
  late final FloatingMessageManager _floatingMessageManager;

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
    });
  }

  @override
  void dispose() {
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VideoPlayerScreen(videoFile: _downloadManager.localVideoFile!),
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
      listenWhen: (prev, curr) => curr is RoomError || curr is RoomInitial,
      listener: (context, state) {
        if (state is RoomError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is RoomInitial) {
          Navigator.of(context).pop();
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
        final currentUser =
            (context.read<AuthBloc>().state as AuthAuthenticated).user;
        final isHost = currentUser.uid == hostId;

        // Map participant IDs to names for display
        final participantNames = participants
            .map((id) => userNames[id] ?? id)
            .toList();

        return BlocProvider(
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
                    resizeToAvoidBottomInset: false,
                    body: SafeArea(
                      child: Column(
                        children: [
                          RoomTopBar(roomId: roomId, scaffoldKey: _scaffoldKey),
                          const Spacer(flex: 1),
                          Expanded(
                            flex: 5,
                            child: _buildRoomLayout(participantNames),
                          ),
                          VideoControlSheet(
                            isHost: isHost,
                            roomId: roomId,
                            fileName: driveFileName,
                            fileId: driveFileId,
                            downloadedVideos: _downloadManager.downloadedVideos,
                            downloadProgress: _downloadManager.downloadProgress,
                            downloadStatus: _downloadManager.downloadStatus,
                            isVideoDownloaded:
                                _downloadManager.isVideoDownloaded,
                            localVideoFile: _downloadManager.localVideoFile,
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomLayout(List<String> participantNames) {
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

            // Define relative positions based on the image's coordinate space
            // Esce theme has fixed 2 positions
            final seatPositions = isEsce
                ? [
                    {'top': 0.90, 'left': 0.30, 'right': null}, // Character 1
                    {'top': 0.62, 'left': 0.51, 'right': null}, // Character 2
                  ]
                : [
                    // 1. Left Sofa Inner
                    {'top': 0.27, 'left': 0.30, 'right': null},
                    // 2. Right Sofa Inner
                    {'top': 0.33, 'left': null, 'right': 0.18},

                    // 3. Left Sofa Mid
                    {'top': 0.41, 'left': 0.20, 'right': null},
                    // 4. Right Sofa Mid (Outer)
                    {'top': 0.52, 'left': null, 'right': 0.06},

                    // 5. Left Sofa Outer
                    {'top': 0.52, 'left': 0.05, 'right': null},

                    // 6. Center Pouf
                    {'top': 0.49, 'left': 0.52, 'right': null},
                  ];

            return Stack(
              alignment: Alignment.center,
              children: [
                // Background Frame/Background Image
                Positioned.fill(
                  child: theme.image != null
                      ? theme.image!.image(fit: BoxFit.contain)
                      : Container(color: theme.baseColor),
                ),

                // Participant Avatars
                ...List.generate(seatPositions.length, (index) {
                  final pos = seatPositions[index];
                  final name = index < participantNames.length
                      ? participantNames[index]
                      : null;

                  return Positioned(
                    top: constraints.maxHeight * (pos['top'] as double),
                    left: pos['left'] != null
                        ? constraints.maxWidth * (pos['left'] as double)
                        : null,
                    right: pos['right'] != null
                        ? constraints.maxWidth * (pos['right'] as double)
                        : null,
                    child: _buildAvatarSlot(name, hideAvatar: isEsce),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarSlot(String? name, {bool hideAvatar = false}) {
    final size = context.dynamicValue(50);
    if (name == null) {
      if (hideAvatar) return const SizedBox(); // Don't show empty slots in Esce
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.black26, // Visible placeholder
          shape: BoxShape.circle,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideAvatar)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        if (!hideAvatar) SizedBox(height: context.dynamicValue(4)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: hideAvatar
              ? BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: hideAvatar ? Colors.white : Colors.black87,
              fontSize: context.dynamicValue(11),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
