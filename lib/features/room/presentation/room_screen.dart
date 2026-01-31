import 'dart:io';

import 'dart:ui';
import 'dart:isolate';

import 'package:emotional/core/services/drive_service.dart';
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/room/bloc/room_bloc.dart';
import 'package:emotional/features/room/presentation/drive_file_picker_screen.dart';
import 'package:emotional/features/room/presentation/manager/room_decoration_cubit.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_selector_sheet.dart';
import 'package:emotional/features/room/presentation/widgets/armchair_widget.dart';
import 'package:emotional/features/room/presentation/widgets/floating_message_bubble.dart';
import 'package:emotional/features/room/presentation/widgets/sofa_widget.dart';
import 'package:emotional/features/room/presentation/widgets/table_widget.dart';
import 'package:emotional/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/chat/presentation/chat_widget.dart';
import 'package:permission_handler/permission_handler.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final ReceivePort _port = ReceivePort();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double? _downloadProgress;
  String? _downloadStatus;
  bool _isVideoDownloaded = false;
  File? _localVideoFile;
  String? _currentDownloadingFileName;

  List<drive.File> _downloadedVideos = [];

  // Floating message system
  final List<OverlayEntry> _activeFloatingMessages = [];
  String? _lastProcessedMessageId;

  @override
  void initState() {
    super.initState();
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    _loadDownloadedVideos();
  }

  Future<void> _loadDownloadedVideos() async {
    try {
      final driveService = context.read<DriveService>();
      final files = await driveService.listVideoFiles();
      final appDir = await getApplicationDocumentsDirectory();

      final downloaded = <drive.File>[];
      for (var file in files) {
        if (file.name != null) {
          final localFile = File('${appDir.path}/${file.name}');
          if (await localFile.exists()) {
            downloaded.add(file);
          }
        }
      }

      if (mounted) {
        setState(() {
          _downloadedVideos = downloaded;
        });
      }
    } catch (e) {
      print('Error loading downloaded videos: $e');
    }
  }

  // ... (dispose, bind/unbind/callback methods remain the same)

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    // Clean up any active floating messages
    for (var entry in _activeFloatingMessages) {
      entry.remove();
    }
    _activeFloatingMessages.clear();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    final boolean = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!boolean) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'downloader_send_port',
      );
    }

    _port.listen((dynamic data) {
      // final String id = data[0];
      final int status = data[1];
      final int progress = data[2];

      if (mounted) {
        setState(() {
          if (status == 3) {
            _downloadProgress = null;
            _downloadStatus = null;
            // Refresh list when a download completes
            _loadDownloadedVideos();
          } else if (status == 4) {
            _downloadStatus = 'İndirme başarısız.';
            _downloadProgress = null;
          } else {
            _downloadProgress = progress / 100;
            _downloadStatus = 'İndiriliyor: $progress%';
          }
        });

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

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(
      'downloader_send_port',
    );
    send?.send([id, status, progress]);
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

  Future<void> _pickVideo(String roomId) async {
    if (!mounted) return;
    final file = await Navigator.push<drive.File>(
      context,
      MaterialPageRoute(builder: (_) => const DriveFilePickerScreen()),
    );

    if (file != null && mounted) {
      _selectVideo(roomId, file);
    }
  }

  void _selectVideo(String roomId, drive.File file) {
    context.read<RoomBloc>().add(
      UpdateRoomVideoRequested(
        roomId: roomId,
        fileId: file.id!,
        fileName: file.name!,
        fileSize: file.size ?? '0',
      ),
    );
  }

  Future<void> _downloadVideo(String fileId, String fileName) async {
    try {
      setState(() {
        _downloadProgress = 0;
        _downloadStatus = 'İndirme başlatılıyor...';
        _currentDownloadingFileName = fileName;
      });

      if (!mounted) return;
      final driveService = context.read<DriveService>();

      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bildirim izni gerekli.')),
            );
          }
        }
      }

      await driveService.downloadVideoInBackground(fileId, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme arka planda başlatıldı...')),
        );
      }
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
    return BlocProvider(
      create: (context) => RoomDecorationCubit(),
      child: BlocConsumer<RoomBloc, RoomState>(
        listener: (context, state) {
          if (state is RoomInitial) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is RoomJoined) {
            if (state.driveFileName != null) {
              _checkFileExists(state.driveFileName!);
            }

            // Auto-switch from love theme when 3+ participants
            final participants = state.participants;
            if (participants.length >= 3) {
              final decorationCubit = context.read<RoomDecorationCubit>();
              if (decorationCubit.state.armchairStyle == ArmchairStyle.love) {
                decorationCubit.setArmchairStyle(ArmchairStyle.modern);
              }
            }
          }
        },
        builder: (context, roomState) {
          if (roomState is! RoomJoined) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final roomId = roomState.roomId;
          final participants = roomState.participants;
          final userNames = roomState.userNames;
          final hostId = roomState.hostId;
          final currentUser =
              (context.read<AuthBloc>().state as AuthAuthenticated).user;
          final isHost = currentUser.uid == hostId;

          // Map participant IDs to names for display
          final participantNames = participants
              .map((id) => userNames[id] ?? id)
              .toList();

          // Load chat messages when room is joined
          // This ensures bubbles work even when chat drawer is closed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<ChatBloc>().add(LoadMessages(roomId));
          });

          // Video State
          final driveFileName = roomState.driveFileName;
          final driveFileId = roomState.driveFileId;

          return BlocListener<ChatBloc, ChatState>(
            listener: (context, chatState) {
              print('🔔 ChatBloc state changed: ${chatState.runtimeType}');
              if (chatState is ChatLoaded && chatState.messages.isNotEmpty) {
                final lastMessage = chatState.messages.last;
                print(
                  '📨 Last message: ${lastMessage.text} from ${lastMessage.senderName}',
                );
                print('👥 Participants: $participants');
                _showFloatingMessage(lastMessage, participants);
              }
            },
            child: Scaffold(
              key: _scaffoldKey,
              endDrawer: Drawer(
                width: MediaQuery.of(context).size.width * 0.85,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: ChatWidget(
                  roomId: roomId,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
              backgroundColor: const Color(0xFF1A1D21),
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, roomId),
                    const Spacer(flex: 1),
                    Expanded(
                      flex: 5,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: constraints.maxHeight * 0.05,
                                child: _buildSofa(context, participantNames),
                              ),
                              // Table in the center
                              Positioned(
                                top: constraints.maxHeight * 0.35,
                                child: const TableWidget(),
                              ),
                              if (context
                                      .watch<RoomDecorationCubit>()
                                      .state
                                      .armchairStyle !=
                                  ArmchairStyle.love) ...[
                                Positioned(
                                  left: 10,
                                  top: constraints.maxHeight * 0.45,
                                  child: _buildArmchair(
                                    context,
                                    participantNames.length > 4
                                        ? participantNames[4]
                                        : null,
                                    isLeft: true,
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  top: constraints.maxHeight * 0.45,
                                  child: _buildArmchair(
                                    context,
                                    participantNames.length > 5
                                        ? participantNames[5]
                                        : null,
                                    isLeft: false,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    // Chat Area Removed from here
                    // Video Control Sheet
                    _buildVideoControlSheet(
                      context,
                      isHost,
                      roomId,
                      driveFileName,
                      driveFileId,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String roomId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final user =
                  (context.read<AuthBloc>().state as AuthAuthenticated).user;
              context.read<RoomBloc>().add(
                LeaveRoomRequested(roomId: roomId, userId: user.uid),
              );
            },
            icon: const Icon(Icons.no_meeting_room, color: Colors.redAccent),
            tooltip: 'Odadan Çık',
            style: IconButton.styleFrom(
              backgroundColor: const Color.fromARGB(26, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  'Oda ID: $roomId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (c) {
                  // Pass the cubit to the sheet
                  return BlocProvider.value(
                    value: context.read<RoomDecorationCubit>(),
                    child: const ArmchairSelectorSheet(),
                  );
                },
              );
            },
            icon: const Icon(Icons.chair, color: Colors.white),
            tooltip: 'Koltuk Teması',
            style: IconButton.styleFrom(
              backgroundColor: const Color.fromARGB(26, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: const Color.fromARGB(26, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControlSheet(
    BuildContext context,
    bool isHost,
    String roomId,
    String? fileName,
    String? fileId,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2229),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHost && _downloadedVideos.isNotEmpty) ...[
            const Text(
              'İndirilenler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100, // Adjusted height for cards
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _downloadedVideos.length,
                itemBuilder: (context, index) {
                  final video = _downloadedVideos[index];
                  final isSelected = video.id == fileId;

                  return GestureDetector(
                    onTap: () => _selectVideo(roomId, video),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurple.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Colors.deepPurpleAccent,
                                width: 2,
                              )
                            : Border.all(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: isSelected
                                ? Colors.deepPurpleAccent
                                : Colors.green,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video.name ?? 'Bilinmeyen',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.deepPurpleAccent
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
          ],

          if (fileName != null) ...[
            Text(
              'Selected Video:',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_downloadProgress != null)
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey[800],
              ),
            if (_downloadStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _downloadStatus!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              if (isHost)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickVideo(roomId),
                    icon: const Icon(Icons.video_library),
                    label: const Text('Tümünü Gör'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (isHost && fileName != null) const SizedBox(width: 12),

              if (fileName != null && fileId != null)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_isVideoDownloaded && _localVideoFile != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VideoPlayerScreen(videoFile: _localVideoFile!),
                          ),
                        );
                      } else {
                        _downloadVideo(fileId, fileName);
                      }
                    },
                    icon: Icon(
                      _isVideoDownloaded ? Icons.play_arrow : Icons.download,
                    ),
                    label: Text(_isVideoDownloaded ? 'Oynat' : 'İndir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVideoDownloaded
                          ? Colors.green
                          : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (fileName == null && !isHost)
            const Center(
              child: Text(
                'Host video seçimi yapıyor...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  // ... (rest of the file: _buildSofa, _buildArmchair, etc.)
  Widget _buildSofa(BuildContext context, List<String> participants) {
    // Watch the decoration state
    final style = context.watch<RoomDecorationCubit>().state.armchairStyle;

    return SofaWidget(
      participants: participants,
      buildAvatarSlot: _buildAvatarSlot,
      style: style,
    );
  }

  Widget _buildArmchair(
    BuildContext context,
    String? participant, {
    required bool isLeft,
  }) {
    // Watch the decoration state
    final style = context.watch<RoomDecorationCubit>().state.armchairStyle;

    return ArmchairWidget(
      participant: participant,
      isLeft: isLeft,
      style: style,
      child: _buildAvatarSlot(participant),
    );
  }

  Widget _buildAvatarSlot(String? name) {
    if (name == null) {
      return Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Color.fromARGB(13, 0, 0, 0),
          shape: BoxShape.circle,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          name.length > 6 ? '${name.substring(0, 6)}...' : name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showFloatingMessage(ChatMessage message, List<String> participants) {
    print('🎈 _showFloatingMessage called for: ${message.text}');
    // Don't show duplicate messages
    if (_lastProcessedMessageId == message.id) {
      print('   ⚠️ Duplicate message ID, skipping');
      return;
    }
    _lastProcessedMessageId = message.id;

    // Find sender's position in participants list
    final senderIndex = participants.indexOf(message.senderId);
    print(
      '   Sender: ${message.senderId}, Index: $senderIndex, Participants: $participants',
    );
    if (senderIndex == -1) {
      print('   ⚠️ Sender not in participants list!');
      return;
    }

    // Calculate position based on participant index
    Offset? position;
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;

    if (senderIndex < 4) {
      // User is on the sofa (positions 0-3)
      final sofaY = screenSize.height * 0.25;
      final spacing = 80.0;
      final startX = centerX - (spacing * 1.5);
      position = Offset(startX + (senderIndex * spacing), sofaY - 80);
    } else if (senderIndex == 4) {
      // Left armchair
      final armchairY = screenSize.height * 0.5;
      position = Offset(60, armchairY - 80);
    } else if (senderIndex == 5) {
      // Right armchair
      final armchairY = screenSize.height * 0.5;
      position = Offset(screenSize.width - 160, armchairY - 80);
    }

    if (position == null) return;

    // Create overlay entry
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: position!.dx,
        top: position.dy,
        child: FloatingMessageBubble(
          message: message.text,
          senderName: message.senderName,
          onComplete: () {
            entry.remove();
            _activeFloatingMessages.remove(entry);
          },
        ),
      ),
    );

    _activeFloatingMessages.add(entry);
    overlay.insert(entry);
    print(
      '   ✨ Bubble created at position $position! Active: ${_activeFloatingMessages.length}',
    );
  }
}
