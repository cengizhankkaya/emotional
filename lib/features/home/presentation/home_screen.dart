import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:emotional/features/room/presentation/room_screen.dart';
import 'package:emotional/features/room/repository/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ... (other imports)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomIdController = TextEditingController();

  void initState() {
    super.initState();
    // Clean up unused rooms when app starts/home loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomRepository>().cleanupEmptyRooms();
    });
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  // ...

  void _createRoom(BuildContext context) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final userName =
        user.displayName ??
        (user.isAnonymous ? 'Misafir' : user.email) ??
        'Kullanıcı';
    context.read<RoomBloc>().add(CreateRoomRequested(user.uid, userName));
  }

  void _joinRoom(BuildContext context) {
    if (_roomIdController.text.isNotEmpty) {
      final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
      final userName =
          user.displayName ??
          (user.isAnonymous ? 'Misafir' : user.email) ??
          'Kullanıcı';
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
        ? (authState.user.displayName ??
              (authState.user.isAnonymous ? 'Misafir' : authState.user.email))
        : 'Kullanıcı';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1D21),
      appBar: AppBar(
        title: const Text(
          'Emotional Player',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
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
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is RoomCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Oda Oluşturuldu: ${state.roomId}'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is RoomJoined) {
            if (state.notificationMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.notificationMessage!),
                  backgroundColor: Colors.blueAccent,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state.participants.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Odaya Katılındı: ${state.roomId}'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            // Navigate to RoomScreen
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

          // If we are already in a room (e.g. popped back to home manually), show a "Return" button
          // if (state is RoomJoined) { ... } logic removed per user request

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
                  Card(
                    color: const Color(0xFF1E2229),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            'Yeni Oda Oluştur',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Yeni bir oturum başlat ve arkadaşlarını davet et.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => _createRoom(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('ODA OLUŞTUR'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "VEYA",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFF1E2229),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            'Odaya Katıl',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _roomIdController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Oda ID',
                              labelStyle: const TextStyle(color: Colors.grey),
                              hintText: '6 haneli Oda ID girin',
                              hintStyle: const TextStyle(color: Colors.white24),
                              prefixIcon: const Icon(
                                Icons.numbers,
                                color: Colors.deepPurple,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.deepPurple,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => _joinRoom(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.deepPurpleAccent,
                                side: const BorderSide(
                                  color: Colors.deepPurpleAccent,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('ODAYA KATIL'),
                            ),
                          ),
                        ],
                      ),
                    ),
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
