import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/data/repositories/room_repository_impl.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';
import 'package:emotional/features/room/domain/usecases/create_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/join_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/leave_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/reassign_host_usecase.dart';
import 'package:emotional/features/room/domain/usecases/stream_room_usecase.dart';
import 'package:emotional/features/room/domain/usecases/sync_settings_usecase.dart';
import 'package:emotional/features/room/domain/usecases/sync_video_usecase.dart';
import 'package:emotional/features/room/domain/usecases/update_room_video_usecase.dart';
import 'package:emotional/features/video_player/bloc/video_player_bloc.dart';
import 'package:emotional/core/bloc/network/network_bloc.dart';
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
          create: (context) => RoomRepositoryImpl(),
        ),
        RepositoryProvider<ChatRepository>(
          create: (context) => ChatRepository(),
        ),
        RepositoryProvider<DriveService>.value(value: driveService),
        // UseCases
        RepositoryProvider(
          create: (context) =>
              CreateRoomUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) => JoinRoomUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) => LeaveRoomUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) =>
              StreamRoomUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) => SyncVideoUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) =>
              SyncSettingsUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) =>
              UpdateRoomVideoUseCase(context.read<RoomRepository>()),
        ),
        RepositoryProvider(
          create: (context) =>
              ReassignHostUseCase(context.read<RoomRepository>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(googleSignIn: googleSignIn)..add(AuthCheckRequested()),
          ),
          BlocProvider<RoomBloc>(
            create: (context) => RoomBloc(
              createRoom: context.read<CreateRoomUseCase>(),
              joinRoom: context.read<JoinRoomUseCase>(),
              leaveRoom: context.read<LeaveRoomUseCase>(),
              streamRoom: context.read<StreamRoomUseCase>(),
              syncVideo: context.read<SyncVideoUseCase>(),
              syncSettings: context.read<SyncSettingsUseCase>(),
              updateRoomVideo: context.read<UpdateRoomVideoUseCase>(),
              reassignHost: context.read<ReassignHostUseCase>(),
              repository: context.read<RoomRepository>(),
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) =>
                ChatBloc(chatRepository: context.read<ChatRepository>()),
          ),
          BlocProvider<CallBloc>(
            create: (context) =>
                CallBloc(roomRepository: context.read<RoomRepository>()),
          ),
          BlocProvider<VideoPlayerBloc>(create: (context) => VideoPlayerBloc()),
          BlocProvider<NetworkBloc>(create: (context) => NetworkBloc()),
        ],
        child: child,
      ),
    );
  }
}
