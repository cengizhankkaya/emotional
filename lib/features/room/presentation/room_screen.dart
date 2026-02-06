import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/floating_message_manager.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
// import 'package:emotional/features/room/bloc/room_bloc.dart'; // Already exists
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/room_top_bar.dart';
import 'package:emotional/features/room/presentation/widgets/video_control_sheet.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

import 'package:emotional/features/room/presentation/mixins/room_media_mixin.dart';
import 'package:emotional/features/room/presentation/widgets/participant_video_row.dart';
import 'package:emotional/features/room/presentation/widgets/room_seating_widget.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with WidgetsBindingObserver, RoomMediaMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FloatingMessageManager _floatingMessageManager;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    // DownloadManager init is handled by DownloadCubit

    _floatingMessageManager = FloatingMessageManager();

    // Auto-start call join
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomJoined) {
        context.read<CallBloc>().add(
          JoinCall(roomId: roomState.roomId, userId: roomState.userId),
        );
        // Video check is now handled by DownloadCubit listening to RoomBloc or driven by UI
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Suspend camera and mic when app goes to background or task switcher
      context.read<CallBloc>().add(SuspendMedia());
      // Notify RoomBloc to stop aggressive re-joins
      context.read<RoomBloc>().add(const SetRoomAppBackgrounded(true));
    } else if (state == AppLifecycleState.resumed) {
      // Resume camera and mic when app comes back
      context.read<CallBloc>().add(ResumeMedia());
      // Notify RoomBloc that app is active again
      context.read<RoomBloc>().add(const SetRoomAppBackgrounded(false));

      // Refresh downloads
      context.read<DownloadCubit>().loadDownloadedVideos();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // downloadManager dispose is handled by Mixin
    _floatingMessageManager.dispose();
    super.dispose();
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
            context.read<DownloadCubit>().checkFileExists(state.driveFileName!);
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
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _showExitConfirmationDialog(context);
            if (shouldPop && context.mounted) {
              _performPopCleanup(context);
            }
          },
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                key: ValueKey('decoration_$roomId'),
                create: (context) => RoomDecorationCubit(
                  roomRepository: context.read<RoomRepository>(),
                  roomId: roomId,
                ),
              ),
              BlocProvider(
                create: (context) => DownloadCubit(
                  downloadManager: DownloadManager(),
                  driveService: context.read<DriveService>(),
                ),
              ),
            ],
            child: MultiBlocListener(
              listeners: [
                BlocListener<RoomBloc, RoomState>(
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
                ),
                BlocListener<DownloadCubit, DownloadState>(
                  listenWhen: (previous, current) {
                    return previous.error != current.error ||
                        previous.isVideoDownloaded != current.isVideoDownloaded;
                  },
                  listener: (context, state) {
                    if (state.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.error!),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                    if (state.isVideoDownloaded &&
                        state.localVideoFile != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('İndirme tamamlandı!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
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
                            child: RoomSeatingWidget(
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
                                  onLeave: () => _performPopCleanup(context),
                                ),
                                ParticipantVideoRow(
                                  participants: participants,
                                  userNames: userNames,
                                  currentUserId: currentUserId,
                                  roomId: roomId,
                                  hostId: hostId,
                                ),
                                const Spacer(),
                                VideoControlSheet(
                                  isHost: isHost,
                                  roomId: roomId,
                                  fileName: driveFileName,
                                  fileId: driveFileId,
                                  onPickVideo: () => pickVideo(roomId),
                                  onSelectVideo: (video) =>
                                      selectVideo(roomId, video),
                                  onPlay: () {
                                    final cubit = context.read<DownloadCubit>();
                                    if (cubit.state.localVideoFile != null) {
                                      playVideo(
                                        videoFile: cubit.state.localVideoFile!,
                                        roomId: roomId,
                                        userId: currentUserId,
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

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Odadan Çık?'),
            content: const Text('Odadan çıkmak istediğinize emin misiniz?'),
            backgroundColor: const Color(0xFF2B3038),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
            contentTextStyle: const TextStyle(color: Colors.white70),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Çık'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _performPopCleanup(BuildContext context) {
    if (_isLeaving) return;

    setState(() {
      _isLeaving = true;
    });

    final roomState = context.read<RoomBloc>().state;
    String? roomId;
    if (roomState is RoomJoined) {
      roomId = roomState.roomId;
    } else if (roomState is RoomCreated) {
      roomId = roomState.roomId;
    }

    // CallBloc cleanup
    context.read<CallBloc>().add(LeaveCall());

    // RoomBloc cleanup
    if (roomId != null) {
      final currentUserId =
          (context.read<AuthBloc>().state as AuthAuthenticated).user.uid;
      context.read<RoomBloc>().add(
        LeaveRoomRequested(roomId: roomId, userId: currentUserId),
      );
    }

    // Force pop
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}
