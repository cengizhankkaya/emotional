import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoomTopBar extends StatelessWidget {
  final String roomId;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const RoomTopBar({
    super.key,
    required this.roomId,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildLeaveButton(context),
          const Spacer(),
          _buildRoomIdDisplay(),
          const Spacer(),
          _buildThemeButton(context),
          const SizedBox(width: 8),
          _buildChatButton(context),
        ],
      ),
    );
  }

  Widget _buildLeaveButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
        context.read<RoomBloc>().add(
          LeaveRoomRequested(roomId: roomId, userId: user.uid),
        );
      },
      icon: const Icon(Icons.no_meeting_room, color: Colors.redAccent),
      tooltip: 'Odadan Çık',
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRoomIdDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            'Oda ID: $roomId',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (c) {
            return BlocProvider.value(
              value: context.read<RoomDecorationCubit>(),
              child: const ArmchairSelectorSheet(),
            );
          },
        );
      },
      icon: const Icon(Icons.chair, color: Colors.white),
      tooltip: 'Koltuk Teması',
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildChatButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        scaffoldKey.currentState?.openEndDrawer();
      },
      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: const Color.fromARGB(26, 255, 255, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
