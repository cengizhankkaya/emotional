import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatPanel extends StatelessWidget {
  final bool isLandscape;
  final VoidCallback onClose;

  const ChatPanel({
    super.key,
    required this.isLandscape,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
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

          return ChatWidget(roomId: roomId, onClose: onClose);
        },
      ),
    );
  }
}
