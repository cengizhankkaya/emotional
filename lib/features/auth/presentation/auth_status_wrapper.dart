import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/auth/presentation/login_screen.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/home/presentation/home_screen.dart';
import 'package:emotional/features/moderation/bloc/moderation_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthStatusWrapper extends StatelessWidget {
  const AuthStatusWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: ColorsCustom.imperilRead,
            ),
          );
        }

        if (state is AuthUnauthenticated) {
          context.read<CallBloc>().add(LeaveCall());

          final roomState = context.read<RoomBloc>().state;

          String? roomId;
          String? userId;

          if (roomState is RoomJoined) {
            roomId = roomState.roomId;
            userId = roomState.userId;
          } else if (roomState is RoomCreated) {
            roomId = roomState.roomId;
            userId = roomState.userId;
          }

          if (roomId != null && userId != null) {
            context.read<RoomBloc>().add(
              LeaveRoomRequested(roomId: roomId, userId: userId),
            );
          }
        }
      },
      builder: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        final isDeleting = state is AuthLoading && user != null;

        if (user != null) {
          // Load blocked users for the authenticated user
          context.read<ModerationBloc>().add(LoadBlockedUsers(user.uid));

          return Stack(
            children: [
              const HomeScreen(),
              if (isDeleting)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        }

        return const LoginScreen();
      },
    );
  }
}
