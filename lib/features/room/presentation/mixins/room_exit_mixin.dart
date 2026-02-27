import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';

import 'package:emotional/features/room/presentation/widgets/leave_room_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

mixin RoomExitMixin<T extends StatefulWidget> on State<T> {
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

    // 1. Önce CallBloc'u temizle (async cleanup queue'ya giriyor)
    context.read<CallBloc>().add(LeaveCall());

    // 2. RoomBloc'u temizle — bu RoomInitial emit eder.
    // room_screen.dart BlocConsumer listener'ı RoomInitial'i görünce
    // Navigator.pop() çağırır. Burada ayrıca pop YAPILMIYOR.
    if (roomId != null) {
      final currentUserId =
          (context.read<AuthBloc>().state as AuthAuthenticated).user.uid;
      context.read<RoomBloc>().add(
        LeaveRoomRequested(roomId: roomId, userId: currentUserId),
      );
    } else {
      // Oda state'i yoksa (RoomInitial/RoomLoading) direkt pop
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }
}
