import 'dart:isolate';
import 'dart:ui';
import 'dart:io';
import 'dart:math';

import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:permission_handler/permission_handler.dart';

// ... (other imports)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomIdController = TextEditingController();
  double? _downloadProgress;
  String? _downloadStatus;
  bool _isVideoDownloaded = false;
  File? _localVideoFile;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    _roomIdController.dispose();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    final boolean = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    // If registration fails (e.g. hot reload), remove naming and retry?
    // Usually safe to just ignore or handle.
    // But for robustness:
    if (!boolean) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'downloader_send_port',
      );
    }

    _port.listen((dynamic data) {
      final String id = data[0];
      final int status = data[1];
      final int progress = data[2];

      print(
        'DEBUG: HomeScreen port received: id=$id, status=$status, progress=$progress',
      );

      // DownloadTaskStatus:
      // 0: undefined, 1: enqueued, 2: running, 3: complete, 4: failed, 5: canceled, 6: paused

      if (mounted) {
        setState(() {
          if (status == 3) {
            print('DEBUG: Download complete for id=$id');
            // Complete
            _downloadProgress = null;
            _downloadStatus = null;
          } else if (status == 4) {
            print('DEBUG: Download failed for id=$id');
            // Failed
            _downloadStatus = 'İndirme başarısız.';
            _downloadProgress = null;
          } else {
            _downloadProgress = progress / 100;

            // Try to get total size for better status
            final roomState = context.read<RoomBloc>().state;
            if (roomState is RoomJoined && roomState.driveFileSize != null) {
              final totalBytes = int.tryParse(roomState.driveFileSize!) ?? 0;
              if (totalBytes > 0) {
                final currentBytes = (totalBytes * progress / 100).floor();
                _downloadStatus =
                    '${_formatBytes(currentBytes)} / ${_formatBytes(totalBytes)} ($progress%)';
              } else {
                _downloadStatus = 'İndiriliyor: $progress%';
              }
            } else {
              _downloadStatus = 'İndiriliyor: $progress%';
            }
          }
        });

        // Handle completion outside setState to allow async file check
        if (status == 3 && _currentDownloadingFileName != null) {
          _checkFileExists(_currentDownloadingFileName!);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('İndirme tamamlandı.')));
        }
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
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

  void _leaveRoom(BuildContext context, String roomId) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    context.read<RoomBloc>().add(
      LeaveRoomRequested(roomId: roomId, userId: user.uid),
    );
  }

  Future<void> _pickVideo(BuildContext context, String roomId) async {
    final file = await Navigator.push<drive.File>(
      context,
      MaterialPageRoute(builder: (_) => const DriveFilePickerScreen()),
    );

    if (file != null && context.mounted) {
      context.read<RoomBloc>().add(
        UpdateRoomVideoRequested(
          roomId: roomId,
          fileId: file.id!,
          fileName: file.name!,
          fileSize: file.size ?? '0',
        ),
      );
    }
  }

  Future<void> _checkFileExists(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$fileName');
    if (await file.exists()) {
      setState(() {
        _isVideoDownloaded = true;
        _localVideoFile = file;
      });
    } else {
      setState(() {
        _isVideoDownloaded = false;
        _localVideoFile = null;
      });
    }
  }

  // Helper to store current downloading filename
  String? _currentDownloadingFileName;

  Future<void> _downloadVideo(
    BuildContext context,
    String fileId,
    String fileName,
  ) async {
    try {
      setState(() {
        _downloadProgress = 0;
        _downloadStatus = 'İndirme başlatılıyor...';
        _currentDownloadingFileName = fileName;
      });

      final driveService = context.read<DriveService>();

      // Request notification permission for Android 13+
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'İndirme bildirimlerini görmek için izin vermelisiniz.',
                ),
              ),
            );
          }
          // We continue download anyway, just without notifications potentially visible
        }
      }

      // Use background download
      await driveService.downloadVideoInBackground(fileId, fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İndirme arka planda başlatıldı...')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress = null;
          _downloadStatus = 'Hata oluştu';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      appBar: AppBar(
        title: const Text('Emotional Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
      body: BlocConsumer<RoomBloc, RoomState>(
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

            if (state.driveFileName != null) {
              _checkFileExists(state.driveFileName!);
            }
          }
        },
        builder: (context, state) {
          if (state is RoomLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RoomCreated || state is RoomJoined) {
            final roomId = state is RoomCreated
                ? (state).roomId
                : (state as RoomJoined).roomId;

            final participants = state is RoomJoined
                ? state.participants
                : <String>[];

            final driveFileName = state is RoomJoined
                ? state.driveFileName
                : null;
            final driveFileId = state is RoomJoined ? state.driveFileId : null;
            final currentHostId = state is RoomJoined ? state.hostId : null;

            // Check file existence if we haven't checked or if it changed
            // NOTE: We ideally shouldn't do side effects in build.
            // Better to move to listener or use a separate widget/hook.
            // But for simplicity, we can do a check if driveFileName != null && !_isVideoDownloaded
            // However, doing async in build is bad.
            // Let's rely on listener!

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hoşgeldin, $userName',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.meeting_room,
                    size: 60,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Oda ID: $roomId',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Katılımcılar (${participants.length}):'),
                  const SizedBox(height: 10),
                  // Display participants list
                  if (participants.isNotEmpty)
                    Container(
                      height: 150,
                      width: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: Colors.deepPurple,
                            ),
                            title: Text(participants[index]),
                          );
                        },
                      ),
                    )
                  else
                    const Text('Diğerlerinin katılması bekleniyor...'),

                  const SizedBox(height: 20),

                  // Drive Video Logic
                  if (driveFileName != null) ...[
                    Text(
                      'Seçilen Video: $driveFileName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (_downloadProgress != null)
                      LinearProgressIndicator(value: _downloadProgress),

                    if (_downloadStatus != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _downloadStatus!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],

                    if (_downloadProgress == null)
                      if (_isVideoDownloaded && _localVideoFile != null) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  videoFile: _localVideoFile!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Videoyu Oynat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _downloadVideo(
                            context,
                            driveFileId!,
                            driveFileName,
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Videoyu İndir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                  ],

                  if (authState is AuthAuthenticated &&
                      currentHostId != null &&
                      authState.user.uid == currentHostId) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _pickVideo(context, roomId),
                      icon: const Icon(Icons.add_to_drive),
                      label: const Text('Drive\'dan Video Seç'),
                    ),
                  ],

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => _leaveRoom(context, roomId),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Odadan Ayrıl'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            );
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
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("VEYA"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _roomIdController,
                            decoration: InputDecoration(
                              labelText: 'Oda ID',
                              hintText: '6 haneli Oda ID girin',
                              prefixIcon: const Icon(Icons.numbers),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                foregroundColor: Colors.deepPurple,
                                side: const BorderSide(
                                  color: Colors.deepPurple,
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

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  print(
    'DEBUG: Background Isolate Callback: id=$id, status=$status, progress=$progress',
  );
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'downloader_send_port',
  );
  send?.send([id, status, progress]);
}
