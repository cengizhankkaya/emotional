import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/auth/presentation/login_screen.dart';
import 'package:emotional/features/home/presentation/home_screen.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/repository/chat_repository.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:emotional/core/services/drive_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'product/init/application_init.dart';

void main() async {
  final initialManager = ApplicationInit();
  await initialManager.start();

  runApp(
    EasyLocalization(
      supportedLocales: initialManager.localize.supportedItems,
      path: initialManager.localize.initialPath,
      startLocale: initialManager.localize.startLocale,
      useOnlyLangCode: true,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        child: MaterialApp(
          title: 'Emotional Video Player',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
            ),
          ),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
