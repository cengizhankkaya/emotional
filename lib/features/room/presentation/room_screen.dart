import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/manager/floating_message_manager.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/mixins/room_exit_mixin.dart';
import 'package:emotional/features/room/presentation/mixins/room_media_mixin.dart';
import 'package:emotional/features/room/presentation/widgets/room_screen_content.dart';
import 'package:emotional/features/room/presentation/widgets/room_screen_listeners.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with WidgetsBindingObserver, RoomMediaMixin, RoomExitMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FloatingMessageManager _floatingMessageManager;

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
          if (mounted) {
            // Always mark as leaving to prevent loops (and stop further cleanup calls if any)
            setState(() {
              isLeaving = true;
            });

            // Show message only if we are actually popping a screen
            if (Navigator.canPop(context)) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Oda kapatıldı veya odadan ayrıldınız.'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            }
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
            final shouldPop = await showExitConfirmationDialog(context);
            if (shouldPop && context.mounted) {
              performPopCleanup(context);
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

                return RoomScreenListeners(
                  floatingMessageManager: _floatingMessageManager,
                  participants: participants,
                  child: RoomScreenContent(
                    roomId: roomId,
                    participants: participants,
                    userNames: userNames,
                    hostId: hostId,
                    currentUserId: currentUserId,
                    isHost: isHost,
                    driveFileName: driveFileName,
                    driveFileId: driveFileId,
                    scaffoldKey: _scaffoldKey,
                    onLeave: () async {
                      if (context.mounted) {
                        final shouldLeave = await showExitConfirmationDialog(
                          context,
                        );
                        if (shouldLeave && context.mounted) {
                          performPopCleanup(context);
                        }
                      }
                    },
                    onPickVideo: () => pickVideo(roomId),
                    onSelectVideo: (video) => selectVideo(roomId, video),
                    onPlayVideo: () {
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
                );
              },
            ),
          ),
        );
      },
    );
  }
}
