import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/auth/presentation/login_screen.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/home/presentation/home_screen.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthStatusWrapper extends StatelessWidget {
  const AuthStatusWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          // Cleanup call and room when logged out
          context.read<CallBloc>().add(LeaveCall());

          final roomState = context.read<RoomBloc>().state;
          if (roomState is RoomJoined) {
            context.read<RoomBloc>().add(
              LeaveRoomRequested(
                roomId: roomState.roomId,
                userId: roomState.userId,
              ),
            );
          }
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
