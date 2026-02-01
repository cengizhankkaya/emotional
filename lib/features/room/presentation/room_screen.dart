import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/manager/floating_message_manager.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_widget.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/sofa_widget.dart';
import 'package:emotional/features/room/presentation/widgets/table_widget.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
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
      final driveService = context.read<DriveService>();
      _downloadManager.downloadVideo(driveService, fileId, fileName, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RoomDecorationCubit(),
      child: BlocConsumer<RoomBloc, RoomState>(
        listener: (context, state) {
          if (state is RoomInitial) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is RoomJoined) {
            if (state.driveFileName != null) {
              _downloadManager.checkFileExists(state.driveFileName!);
            }

            // Auto-switch from love theme when 3+ participants
            final participants = state.participants;
            if (participants.length >= 3) {
              final decorationCubit = context.read<RoomDecorationCubit>();
              if (decorationCubit.state.armchairStyle == ArmchairStyle.love) {
                decorationCubit.setArmchairStyle(ArmchairStyle.modern);
              }
            }
          }
        },
        builder: (context, roomState) {
          if (roomState is! RoomJoined) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

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

          // Load chat messages when room is joined
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<ChatBloc>().add(LoadMessages(roomId));
          });

          // Video State
          final driveFileName = roomState.driveFileName;
          final driveFileId = roomState.driveFileId;

          return BlocListener<ChatBloc, ChatState>(
            listener: (context, chatState) {
              if (chatState is ChatLoaded && chatState.messages.isNotEmpty) {
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
                      isVideoDownloaded: _downloadManager.isVideoDownloaded,
                      localVideoFile: _downloadManager.localVideoFile,
                      onPickVideo: () => _pickVideo(roomId),
                      onSelectVideo: (video) => _selectVideo(roomId, video),
                      onDownloadOrPlay: () {
                        if (driveFileId != null && driveFileName != null) {
                          _handleDownloadOrPlay(driveFileId, driveFileName);
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
    );
  }

  Widget _buildRoomLayout(List<String> participantNames) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: constraints.maxHeight * 0.05,
              child: _buildSofa(context, participantNames),
            ),
            Positioned(
              top: constraints.maxHeight * 0.35,
              child: const TableWidget(),
            ),
            if (context.watch<RoomDecorationCubit>().state.armchairStyle !=
                ArmchairStyle.love) ...[
              Positioned(
                left: context.dynamicValue(10),
                top: constraints.maxHeight * 0.45,
                child: _buildArmchair(
                  context,
                  participantNames.length > 4 ? participantNames[4] : null,
                  isLeft: true,
                ),
              ),
              Positioned(
                right: context.dynamicValue(10),
                top: constraints.maxHeight * 0.45,
                child: _buildArmchair(
                  context,
                  participantNames.length > 5 ? participantNames[5] : null,
                  isLeft: false,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSofa(BuildContext context, List<String> participants) {
    final style = context.watch<RoomDecorationCubit>().state.armchairStyle;

    return SofaWidget(
      participants: participants,
      buildAvatarSlot: _buildAvatarSlot,
      style: style,
    );
  }

  Widget _buildArmchair(
    BuildContext context,
    String? participant, {
    required bool isLeft,
  }) {
    final style = context.watch<RoomDecorationCubit>().state.armchairStyle;

    return ArmchairWidget(
      participant: participant,
      isLeft: isLeft,
      style: style,
      child: _buildAvatarSlot(participant),
    );
  }

  Widget _buildAvatarSlot(String? name) {
    final size = context.dynamicValue(50);
    if (name == null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color.fromARGB(13, 0, 0, 0),
          shape: BoxShape.circle,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        SizedBox(height: context.dynamicValue(4)),
        Text(
          name.length > 6 ? '${name.substring(0, 6)}...' : name,
          style: TextStyle(
            color: Colors.black87,
            fontSize: context.dynamicValue(10),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
