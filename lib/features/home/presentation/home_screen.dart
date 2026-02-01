import 'package:app_links/app_links.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/home/presentation/helpers/user_helper.dart';
import 'package:emotional/features/home/presentation/widgets/create_room_card.dart';
import 'package:emotional/features/home/presentation/widgets/home_app_bar.dart';
import 'package:emotional/features/home/presentation/widgets/join_room_card.dart';
import 'package:emotional/features/home/presentation/widgets/permission_sheet.dart';
import 'package:emotional/features/home/presentation/widgets/room_divider.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/room_screen.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clean up unused rooms when app starts/home loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomRepository>().cleanupEmptyRooms();
      _checkAndRequestPermissions();
      _initDeepLinkListener();
    });
  }

  Future<void> _initDeepLinkListener() async {
    final appLinks = AppLinks();

    // Check initial link
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('Deep Link Error: $e');
    }

    // Listen for future links
    appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    String? roomId;

    // 1. Custom Scheme: emotional://join/123
    if (uri.scheme == 'emotional' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments[0] == 'join' && uri.pathSegments.length > 1) {
        roomId = uri.pathSegments[1];
      }
    }
    // 2. Universal Link: https://emotional-app-b42af.web.app/join/123
    else if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host == 'emotional-app-b42af.web.app' &&
        uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments[0] == 'join' && uri.pathSegments.length > 1) {
        roomId = uri.pathSegments[1];
      }
    }

    if (roomId != null && roomId.isNotEmpty) {
      debugPrint('Auto-joining room: $roomId');
      _roomIdController.text = roomId;
      _joinRoom(context);
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    final permissionService = PermissionService();

    // Check if we need to show rationale
    // Simply check if any is NOT granted first
    final isCameraGranted = await permissionService.isCameraGranted;
    final isMicGranted = await permissionService.isMicrophoneGranted;
    // Notification check is platform specific inside service but returns bool
    final isNotifGranted = await permissionService
        .requestNotificationPermission();

    // Check storage too (will likely be true or implicitly handled on new Androids, but matters for old ones)
    final isStorageGranted = await permissionService.requestStoragePermission();

    // If already granted, do nothing (notification request above acts as check/request for Android 13)
    if (isCameraGranted && isMicGranted && isNotifGranted && isStorageGranted)
      return;

    if (!mounted) return;

    // Request directly without custom dialog
    // await permissionService.requestCameraAndMicrophonePermissions();
    // await permissionService.requestNotificationPermission();

    // Show custom permission sheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PermissionSheet(
        onGrant: () async {
          Navigator.pop(context);
          // Request all sequentialy
          await permissionService.requestCameraAndMicrophonePermissions();
          await permissionService.requestNotificationPermission();
          await permissionService.requestStoragePermission();
        },
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  // ...

  Future<bool> _hasRequiredPermissions() async {
    final permissionService = PermissionService();
    final isCameraGranted = await permissionService.isCameraGranted;
    final isMicGranted = await permissionService.isMicrophoneGranted;
    return isCameraGranted && isMicGranted;
  }

  Future<void> _createRoom(BuildContext context) async {
    if (!await _hasRequiredPermissions()) {
      _checkAndRequestPermissions();
      return;
    }

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final userName = UserHelper.getUserDisplayName(user);
    context.read<RoomBloc>().add(CreateRoomRequested(user.uid, userName));
  }

  Future<void> _joinRoom(BuildContext context) async {
    if (_roomIdController.text.isNotEmpty) {
      if (!await _hasRequiredPermissions()) {
        _checkAndRequestPermissions();
        return;
      }

      final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
      final userName = UserHelper.getUserDisplayName(user);
      context.read<RoomBloc>().add(
        JoinRoomRequested(
          roomId: _roomIdController.text.trim(),
          userId: user.uid,
          userName: userName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current user for display
    final authState = context.watch<AuthBloc>().state;
    final userName = authState is AuthAuthenticated
        ? UserHelper.getUserDisplayName(authState.user)
        : 'Kullanıcı';

    return Scaffold(
      backgroundColor: ColorsCustom.darkBlue,
      appBar: const HomeAppBar(),
      body: BlocConsumer<RoomBloc, RoomState>(
        listenWhen: (previous, current) {
          // Listen for errors, creation success, or joining success
          return current is RoomError ||
              current is RoomCreated ||
              (previous is! RoomJoined && current is RoomJoined);
        },
        listener: (context, state) {
          if (state is RoomError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: ColorsCustom.imperilRead,
              ),
            );
          } else if (state is RoomCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Oda Oluşturuldu: ${state.roomId}'),
                backgroundColor: ColorsCustom.darkABlue,
              ),
            );
          } else if (state is RoomJoined) {
            if (state.notificationMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.notificationMessage!),
                  backgroundColor: ColorsCustom.darkABlue,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state.participants.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Odaya Katılındı: ${state.roomId}'),
                  backgroundColor: ColorsCustom.darkABlue,
                ),
              );
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoomScreen()),
            );
          }
        },
        builder: (context, state) {
          if (state is RoomLoading || state is RoomCreated) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Merhaba, $userName!',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  CreateRoomCard(onCreateRoom: () => _createRoom(context)),
                  const SizedBox(height: 24),
                  const RoomDivider(),
                  const SizedBox(height: 24),
                  JoinRoomCard(
                    roomIdController: _roomIdController,
                    onJoinRoom: () => _joinRoom(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
