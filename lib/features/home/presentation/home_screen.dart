import 'package:emotional/features/home/presentation/widgets/web_home_body.dart';
import 'package:emotional/product/utility/responsiveness/web_layout.dart';
import 'package:app_links/app_links.dart';
import 'package:emotional/features/room/presentation/manager/helpers/download_permission_helper.dart';
import 'package:emotional/core/services/permission_service.dart';
import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/home/presentation/helpers/user_helper.dart';
import 'package:emotional/features/home/presentation/widgets/create_room_card.dart';
import 'package:emotional/features/home/presentation/widgets/home_app_bar.dart';
import 'package:emotional/features/home/presentation/widgets/home_download_card.dart';
import 'package:emotional/features/home/presentation/widgets/join_room_card.dart';
import 'package:emotional/features/home/presentation/widgets/permission_sheet.dart';
import 'package:emotional/features/home/presentation/widgets/web_permission_dialog.dart';
import 'package:emotional/features/home/presentation/widgets/room_divider.dart';
import 'package:emotional/features/room/bloc/download_cubit.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/manager/download_manager.dart';
import 'package:emotional/features/room/presentation/room_screen.dart';
import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:emotional/features/room/presentation/invite/room_invite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import '../../../core/manager/cache_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomIdController = TextEditingController();
  final _cacheManager = CacheManager();
  bool _isJoiningRoom = false;
  String? _pendingDeepLinkRoomId; // Pending room ID if blocked by permissions

  @override
  void initState() {
    super.initState();
    // Clean up unused rooms when app starts/home loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        WebCallPermissions.introduceOnce(context);
      } else {
        _checkAndRequestPermissions();
      }
      _initDeepLinkListener();
      _loadLastRoomId();
    });
  }

  Future<void> _loadLastRoomId() async {
    // Only load from cache if the field is empty (to avoid overwriting deep link)
    if (_roomIdController.text.isNotEmpty) return;

    final lastRoomId = await _cacheManager.getLastRoomId();
    if (lastRoomId != null && mounted && _roomIdController.text.isEmpty) {
      _roomIdController.text = lastRoomId;
    }
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
    // On web the "link" is the page address, e.g. emoti-izle.web.app/join/1.
    final roomId = RoomInvite.roomIdFrom(
      uri,
      ownHost: kIsWeb ? Uri.base.host : null,
    );

    if (roomId != null && roomId.trim().isNotEmpty) {
      final cleanRoomId = roomId.trim();
      debugPrint('Deep link detected for room: $cleanRoomId');
      _roomIdController.text = cleanRoomId;
      _joinRoom(context);
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    final permissionService = PermissionService();

    // 1. Zaten verilmişse hiçbir şey yapma
    if (await permissionService.areCallPermissionsGranted) return;
    if (!mounted) return;

    // 2. Kalıcı olarak reddedilmişse → Ayarlar'a yönlendir
    if (await permissionService.isCallPermissionPermanentlyDenied) {
      _showPermanentlyDeniedDialog();
      return;
    }
    if (!mounted) return;

    // 3. Henüz verilmemiş → PermissionSheet göster
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PermissionSheet(
        onGrant: () async {
          Navigator.pop(sheetContext);
          await permissionService.requestCameraAndMicrophonePermissions();
          await DownloadPermissionHelper().requestInitialPermissions();

          // The sheet is gone by now; join with the screen's own context.
          if (_pendingDeepLinkRoomId != null && mounted) {
            _joinRoom(context);
          }
        },
      ),
    );
  }

  /// Kalıcı olarak reddedilmiş izinler için Ayarlar yönlendirme diyalogu
  void _showPermanentlyDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColorsCustom.darkABlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              LocaleKeys.home_permissions_settingsTitle.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          LocaleKeys.home_permissions_settingsMessage.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              LocaleKeys.button_cancel.tr(),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await PermissionService().openAppSettings();
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(LocaleKeys.home_permissions_openSettings.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsCustom.skyBlue,
              foregroundColor: ColorsCustom.darkBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<bool> _hasRequiredPermissions() async {
    // Browsers ask in one prompt and need no app settings or storage.
    if (kIsWeb) return WebCallPermissions.ensure(context);

    final permissionService = PermissionService();

    // Zaten verilmişse geç
    if (await permissionService.areCallPermissionsGranted) return true;

    // Kalıcı red → diyalog göster, false döndür
    if (await permissionService.isCallPermissionPermanentlyDenied) {
      _showPermanentlyDeniedDialog();
      return false;
    }

    // Henüz istenmemiş → PermissionSheet göster
    _checkAndRequestPermissions();
    return false;
  }

  Future<void> _createRoom(BuildContext context) async {
    // Shows whatever explanation is needed itself.
    if (!await _hasRequiredPermissions()) return;
    if (!context.mounted) return;

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final userName = UserHelper.getUserDisplayName(user);
    context.read<RoomBloc>().add(CreateRoomRequested(user.uid, userName));
  }

  Future<void> _joinRoom(BuildContext context) async {
    if (_roomIdController.text.isEmpty) return;

    // Aynı anda birden fazla JoinRoomRequested göndermemek için
    // hem yerel flag hem de Bloc state'ini kullanıyoruz.
    if (_isJoiningRoom) return;

    final roomState = context.read<RoomBloc>().state;
    if (roomState is RoomLoading || roomState is RoomJoined) return;

    if (!await _hasRequiredPermissions()) {
      _pendingDeepLinkRoomId = _roomIdController.text.trim();
      return;
    }
    if (!context.mounted) return;

    // Clear pending ID as we are proceeding with join
    _pendingDeepLinkRoomId = null;

    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final userName = UserHelper.getUserDisplayName(user);
    _isJoiningRoom = true;
    context.read<RoomBloc>().add(
      JoinRoomRequested(
        roomId: _roomIdController.text.trim(),
        userId: user.uid,
        userName: userName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current user for display
    final authState = context.watch<AuthBloc>().state;
    final userName = authState is AuthAuthenticated
        ? UserHelper.getUserDisplayName(authState.user)
        : LocaleKeys.room_someone.tr();

    return BlocProvider<DownloadCubit>(
      create: (context) => DownloadCubit(
        downloadManager: DownloadManager(),
        driveService: context.read<DriveService>(),
      ),
      child: Scaffold(
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
              _isJoiningRoom = false;
              _pendingDeepLinkRoomId = null; // Clear on error
              String errorMessage = state.message;
              if (errorMessage.contains('Room not found')) {
                errorMessage = LocaleKeys.home_feedback_roomNotFound.tr();
                _cacheManager
                    .clearLastRoomId(); // Clear invalid room ID from cache
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: ColorsCustom.imperilRead,
                ),
              );
            } else if (state is RoomCreated) {
              _isJoiningRoom = false;
              _cacheManager.saveLastRoomId(state.roomId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LocaleKeys.home_feedback_roomCreated.tr(
                      args: [state.roomId],
                    ),
                  ),
                  backgroundColor: ColorsCustom.darkABlue,
                ),
              );
            } else if (state is RoomJoined) {
              _isJoiningRoom = false;
              _cacheManager.saveLastRoomId(state.roomId);
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
                    content: Text(
                      LocaleKeys.home_feedback_roomJoined.tr(
                        args: [state.roomId],
                      ),
                    ),
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
            if (WebLayout.isWide(context)) {
              return WebHomeBody(
                userName: userName,
                roomIdController: _roomIdController,
                onCreateRoom: () => _createRoom(context),
                onJoinRoom: () => _joinRoom(context),
              );
            }
            return Center(
              child: SingleChildScrollView(
                padding: const ProjectPadding.allLarge(),
                child: WebContentWidth(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.home_welcome.tr(args: [userName]),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: context.dynamicValue(24),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.dynamicHeight(0.05)),
                      CreateRoomCard(onCreateRoom: () => _createRoom(context)),
                      SizedBox(height: context.dynamicHeight(0.03)),
                      const RoomDivider(),
                      SizedBox(height: context.dynamicHeight(0.03)),
                      JoinRoomCard(
                        roomIdController: _roomIdController,
                        onJoinRoom: () => _joinRoom(context),
                      ),
                      SizedBox(height: context.dynamicHeight(0.03)),
                      // Browsers stream videos; there is nothing to download.
                      if (!kIsWeb) const HomeDownloadCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
