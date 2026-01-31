import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class ProductScope extends StatelessWidget {
  const ProductScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveReadonlyScope],
    );
    final driveService = DriveService(googleSignIn: googleSignIn);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RoomRepository>(
          create: (context) => RoomRepository(),
        ),
        RepositoryProvider<ChatRepository>(
          create: (context) => ChatRepository(),
        ),
        RepositoryProvider<DriveService>.value(value: driveService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(googleSignIn: googleSignIn)..add(AuthCheckRequested()),
          ),
          BlocProvider<RoomBloc>(
            create: (context) =>
                RoomBloc(roomRepository: context.read<RoomRepository>()),
          ),
          BlocProvider<ChatBloc>(
            create: (context) =>
                ChatBloc(chatRepository: context.read<ChatRepository>()),
          ),
          BlocProvider<CallBloc>(
            create: (context) =>
                CallBloc(roomRepository: context.read<RoomRepository>()),
          ),
        ],
        child: child,
      ),
    );
  }
}
