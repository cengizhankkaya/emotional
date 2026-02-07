import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/room_screen.dart';
import 'package:emotional/features/room/presentation/widgets/leave_room_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

mixin RoomExitMixin on State<RoomScreen> {
  bool isLeaving = false;

  Future<bool> showExitConfirmationDialog(BuildContext context) async {
    final result = await LeaveRoomDialog.show(context);
    return result ?? false;
  }

  void performPopCleanup(BuildContext context) {
    if (isLeaving) return;

    setState(() {
      isLeaving = true;
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
