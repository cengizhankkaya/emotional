import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/floating_message_manager.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoomScreenListeners extends StatelessWidget {
  final Widget child;
  final FloatingMessageManager floatingMessageManager;
  final List<String> participants;

  const RoomScreenListeners({
    super.key,
    required this.child,
    required this.floatingMessageManager,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
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
            if (state.isVideoDownloaded && state.localVideoFile != null) {
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
        BlocListener<ChatBloc, ChatState>(
          listener: (context, chatState) {
            if (chatState is ChatLoaded && chatState.messages.isNotEmpty) {
              final lastMessage = chatState.messages.last;
              floatingMessageManager.showFloatingMessage(
                context,
                lastMessage,
                participants,
              );
            }
          },
        ),
      ],
      child: child,
    );
  }
}
