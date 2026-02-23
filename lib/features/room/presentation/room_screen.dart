import 'dart:io';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/core/services/youtube_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DownloadCubit>(
      create: (context) => DownloadCubit(
        downloadManager: DownloadManager(),
        driveService: context.read<DriveService>(),
      ),
      child: const _RoomBody(),
    );
  }
}

class _RoomBody extends StatefulWidget {
  const _RoomBody();

  @override
  State<_RoomBody> createState() => _RoomBodyState();
}

class _RoomBodyState extends State<_RoomBody>
    with WidgetsBindingObserver, RoomMediaMixin, RoomExitMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final FloatingMessageManager _floatingMessageManager;
  static const _channel = MethodChannel('com.example.emotional/screen_share');

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

    // PiP and Notification Actions Listener
    _channel.setMethodCallHandler((call) async {
      debugPrint(
        '[RoomScreen] Native MethodChannel call received: ${call.method}',
      );
      if (call.method == 'onStopPressed') {
        final callState = context.read<CallBloc>().state;
        if (callState is CallConnected && callState.isScreenSharing) {
          context.read<CallBloc>().add(
            const ToggleScreenShare(fromNotification: true),
          );
        }
      } else if (call.method == 'onLeaveRoomPressed') {
        if (mounted) {
          performPopCleanup(context);
        }
      } else if (call.method == 'onToggleMutePressed') {
        if (mounted) {
          context.read<CallBloc>().add(ToggleMute());
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Removed SuspendMedia() logic to allow background audio.
    // The OS (especially iOS) will automatically handle camera suspension.
    // We keep the audio session active.

    if (state == AppLifecycleState.resumed) {
      // Refresh downloads when coming back to foreground
      context.read<DownloadCubit>().loadDownloadedVideos();
    } else if (state == AppLifecycleState.detached) {
      // App is being killed from the recent apps list or force closed.
      // Force an immediate 'goOffline' to trigger onDisconnect events gracefully on the server.
      try {
        FirebaseDatabase.instance.goOffline();
      } catch (e) {
        debugPrint('RoomScreen: Error going offline on detach: $e');
      }
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
            // Now this works because DownloadCubit is provided above _RoomBody
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
              // DownloadCubit is now provided at the top of RoomScreen
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
                      // YouTube Link Check
                      if (driveFileId != null &&
                          YouTubeService().isValidYouTubeUrl(driveFileId)) {
                        playVideo(
                          videoFile: File(''),
                          youtubeUrl: driveFileId,
                          roomId: roomId,
                          userId: currentUserId,
                          savedAudioTrack: roomState.selectedAudioTrack,
                          savedSubtitleTrack: roomState.selectedSubtitleTrack,
                        );
                        return;
                      }

                      if (cubit.state.localVideoFile != null) {
                        playVideo(
                          videoFile: cubit.state.localVideoFile!,
                          roomId: roomId,
                          userId: currentUserId,
                          savedAudioTrack: roomState.selectedAudioTrack,
                          savedSubtitleTrack: roomState.selectedSubtitleTrack,
                        );
                      } else {
                        // File is not available, show error and trigger recheck
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Video dosyası bulunamadı. Kontrol ediliyor...',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        if (driveFileName != null) {
                          cubit.checkFileExists(driveFileName);
                        }
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
