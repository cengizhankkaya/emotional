import 'dart:async';
import 'dart:js_interop';

import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_event.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/service/audio_session_service.dart';
import 'package:emotional/features/call/service/media_device_service.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:emotional/features/room/domain/entities/room_entity.dart';
import 'package:emotional/features/room/domain/repositories/room_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'call_test_support.dart';

// CallBloc on real browser media, with Firebase and platform plugins
// replaced. Call TestWidgetsFlutterBinding.ensureInitialized() and
// setUpAll(mockCallPlugins) first.

/// Platform plugins aren't registered in tests. Permissions say yes (the
/// browser's own prompt is what Chrome's fake UI answers); wakelock and the
/// audio session are optional, and without an answer the call would wait
/// out their timeouts.
void mockCallPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Unregistered, these never answer and the call waits out its timeouts.
  for (final channel in const [
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    'com.ryanheise.audio_session',
    'com.ryanheise.android_audio_manager',
    'com.ryanheise.av_audio_session',
  ]) {
    messenger.setMockMessageHandler(channel, (_) async => null);
  }
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => switch (call.method) {
          'requestPermissions' => {
            for (final permission in call.arguments as List) permission: 1,
          },
          'checkPermissionStatus' => 1,
          _ => null,
        },
      );
}

Future<bool> devicesAvailable() async {
  try {
    final probe = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    for (final track in probe.getTracks().toDart) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}

const String needsDevices =
    'Needs a camera and microphone: run with '
    'CHROME_EXECUTABLE=tool/chrome_with_fake_media.sh';

typedef CallUser = ({
  CallBloc bloc,
  MediaDeviceService media,
  WebRTCService rtc,
});

/// Users of one room, each with their own CallBloc, on one signaling bus.
class CallHarness {
  final SignalBus bus = SignalBus();
  final FakeRoom room = FakeRoom();
  final List<CallBloc> _blocs = [];

  /// A user in the room joining the call.
  Future<CallUser> join(String userId) async {
    room.addUser(userId);
    final media = MediaDeviceService();
    final rtc = WebRTCService(
      signalingFactory: (roomId, uid) => FakeSignaling(bus, roomId, uid),
    );
    final bloc = CallBloc(
      roomRepository: room,
      callService: rtc,
      mediaDeviceService: media,
      audioSessionService: AudioSessionService(),
    );
    _blocs.add(bloc);
    bloc.add(JoinCall(roomId: 'room', userId: userId));
    await waitFor(
      () => bloc.state is CallConnected || bloc.state is CallError,
      '$userId in the call',
    );
    final state = bloc.state;
    if (state is CallError) fail('$userId could not join: ${state.message}');
    return (bloc: bloc, media: media, rtc: rtc);
  }

  Future<void> dispose() async {
    for (final bloc in _blocs) {
      await bloc.close();
    }
    _blocs.clear();
    await room.close();
  }
}

/// The room in memory: who is in it and their media state, streamed like
/// the database does.
class FakeRoom implements RoomRepository {
  final Map<String, String> users = {};
  final Map<String, UserMediaState> mediaState = {};
  final StreamController<RoomEntity?> _updates =
      StreamController<RoomEntity?>.broadcast();
  int _clock = 0;

  void addUser(String userId) {
    users[userId] = userId;
    _publish();
  }

  RoomEntity get _entity => RoomEntity(
    id: 'room',
    hostId: users.keys.first,
    users: Map.of(users),
    usersState: Map.of(mediaState),
    status: 'waiting',
  );

  void _publish() {
    final entity = _entity;
    scheduleMicrotask(() => _updates.add(entity));
  }

  Future<void> close() => _updates.close();

  @override
  Stream<RoomEntity?> streamRoom(String roomId) async* {
    yield _entity;
    yield* _updates.stream;
  }

  @override
  Future<RoomEntity?> getRoom(String roomId) async => _entity;

  @override
  Future<void> updateUserMediaState(
    String roomId,
    String userId, {
    required bool isVideoEnabled,
    required bool isAudioEnabled,
    required bool isScreenSharing,
    bool? isWatchingVideo,
    String? platform,
    bool? isShareCameraOn,
    bool? acceptsShareCamera,
  }) async {
    // Merged like the database's update().
    final previous = mediaState[userId];
    mediaState[userId] = UserMediaState(
      isVideoEnabled: isVideoEnabled,
      isAudioEnabled: isAudioEnabled,
      isScreenSharing: isScreenSharing,
      lastUpdatedAt: ++_clock,
      platform: platform ?? previous?.platform,
      isShareCameraOn: isShareCameraOn ?? previous?.isShareCameraOn ?? false,
      acceptsShareCamera:
          acceptsShareCamera ?? previous?.acceptsShareCamera ?? false,
    );
    _publish();
  }

  @override
  Future<String> createRoom(String userId, String userName) async => 'room';

  @override
  Future<void> joinRoom(String roomId, String userId, String userName) async =>
      addUser(userId);

  @override
  Future<void> leaveRoom(String roomId, String userId) async {
    users.remove(userId);
    _publish();
  }

  @override
  Future<void> reassignHost(String roomId, String newHostId) async {}

  @override
  Future<void> updateArmchairStyle(String roomId, String styleName) async {}

  @override
  Future<void> updateRoomSettings(
    String roomId,
    double? speed,
    String? audioTrack,
    String? subtitleTrack,
    String userId,
  ) async {}

  @override
  Future<void> updateRoomVideo(
    String roomId,
    String fileId,
    String fileName,
    String fileSize,
  ) async {}

  @override
  Future<void> updateVideoState(
    String roomId,
    bool isPlaying,
    int position,
    String userId,
  ) async {}
}
