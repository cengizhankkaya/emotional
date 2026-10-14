import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart'
    show MediaStreamWeb, MediaStreamTrackWeb;
import 'package:emotional/features/call/domain/enums/peer_status.dart';
import 'package:emotional/features/call/service/signaling_service.dart';
import 'package:emotional/features/call/service/webrtc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

// Shared by the browser call tests: Firebase signaling replaced by an
// in-memory inbox per user, and synthetic microphones and cameras.

Future<void> waitConnected(WebRTCService service, String peer) => waitFor(
  () => service.peerStatus(peer).status == PeerStatus.connected,
  'connection to $peer',
);

Future<void> waitFor(bool Function() condition, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> waitForAsync(
  Future<bool> Function() condition,
  String what,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Future<int> videoBytesReceived(RTCPeerConnection pc) =>
    _inboundBytes(pc, 'video');

/// A silent microphone: the stream a call starts with.
MediaStream microphoneOnly() {
  final destination = web.AudioContext().createMediaStreamDestination();
  return MediaStreamWeb(destination.stream, 'local');
}

/// A camera stand-in: a canvas that keeps drawing frames.
/// [width] x [height]: 320x240 is a laptop-style picture, 180x320 a phone
/// held upright.
({MediaStreamTrack track, void Function() stop}) fakeCamera({
  int width = 320,
  int height = 240,
}) {
  final canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  var frame = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
    context.fillStyle = 'hsl(${frame++ * 10 % 360}, 80%, 50%)'.toJS;
    context.fillRect(0, 0, width, height);
  });
  final track = canvas.captureStream(20).getVideoTracks().toDart.first;
  return (
    track: MediaStreamTrackWeb(track),
    stop: () {
      timer.cancel();
      track.stop();
    },
  );
}

class SignalInbox {
  final Map<String, RTCSessionDescription> offers = {};
  final Map<String, RTCSessionDescription> answers = {};
  final Map<String, List<RTCIceCandidate>> candidates = {};
}

class SignalBus {
  final Map<String, SignalInbox> _inboxes = {};
  final Map<String, FakeSignaling> _listening = {};
  bool dropByes = false;
  int answersSent = 0;

  SignalInbox inbox(String userId) =>
      _inboxes.putIfAbsent(userId, SignalInbox.new);

  /// Delivers like a database listener: later, and only to a listener.
  void deliver(String to, void Function(FakeSignaling listener) event) {
    scheduleMicrotask(() {
      final listener = _listening[to];
      if (listener != null && !listener.isDisposed) event(listener);
    });
  }
}

class FakeSignaling implements SignalingService {
  FakeSignaling(
    this.bus,
    this.roomId,
    this.userId, {
    this.wipesInboxOnStart = false,
  });

  /// Older app versions cleared their whole inbox when the call started.
  final bool wipesInboxOnStart;

  final SignalBus bus;
  @override
  final String roomId;
  @override
  final String userId;

  bool isDisposed = false;

  @override
  OnRemoteOffer? onRemoteOffer;
  @override
  OnRemoteAnswer? onRemoteAnswer;
  @override
  OnIceCandidate? onRemoteIceCandidate;
  @override
  OnBye? onRemoteBye;

  @override
  Future<void> initialize() async {
    if (wipesInboxOnStart) await clearSignal();
    listenForIncomingSignals();
  }

  @override
  void listenForIncomingSignals() {
    bus._listening[userId] = this;
    // Like onChildAdded: whatever is already waiting fires first.
    final inbox = bus.inbox(userId);
    for (final entry in inbox.offers.entries.toList()) {
      bus.deliver(userId, (l) => l.onRemoteOffer?.call(entry.value, entry.key));
    }
    for (final entry in inbox.answers.entries.toList()) {
      bus.deliver(
        userId,
        (l) => l.onRemoteAnswer?.call(entry.value, entry.key),
      );
    }
    for (final entry in inbox.candidates.entries.toList()) {
      for (final candidate in entry.value.toList()) {
        bus.deliver(
          userId,
          (l) => l.onRemoteIceCandidate?.call(candidate, entry.key),
        );
      }
    }
  }

  @override
  Future<void> sendOffer(String target, RTCSessionDescription offer) async {
    bus.inbox(target).offers[userId] = offer;
    bus.deliver(target, (l) => l.onRemoteOffer?.call(offer, userId));
  }

  @override
  Future<void> sendAnswer(String target, RTCSessionDescription answer) async {
    bus.answersSent++;
    bus.inbox(target).answers[userId] = answer;
    bus.deliver(target, (l) => l.onRemoteAnswer?.call(answer, userId));
  }

  @override
  Future<void> sendIceCandidate(
    String target,
    RTCIceCandidate candidate,
  ) async {
    bus.inbox(target).candidates.putIfAbsent(userId, () => []).add(candidate);
    bus.deliver(target, (l) => l.onRemoteIceCandidate?.call(candidate, userId));
  }

  @override
  Future<void> sendBye(String target) async {
    if (bus.dropByes) return;
    bus.deliver(target, (l) => l.onRemoteBye?.call(userId));
  }

  @override
  Future<void> clearSignal() async => bus._inboxes.remove(userId);

  @override
  Future<void> clearIncomingFromUser(String fromUserId) async {
    final inbox = bus.inbox(userId);
    inbox.offers.remove(fromUserId);
    inbox.answers.remove(fromUserId);
    inbox.candidates.remove(fromUserId);
  }

  @override
  Future<void> clearOutgoingToUser(String targetUserId) async {
    final inbox = bus.inbox(targetUserId);
    inbox.offers.remove(userId);
    inbox.answers.remove(userId);
    inbox.candidates.remove(userId);
  }

  @override
  void dispose() {
    isDisposed = true;
    if (bus._listening[userId] == this) bus._listening.remove(userId);
    onRemoteOffer = null;
    onRemoteAnswer = null;
    onRemoteIceCandidate = null;
    onRemoteBye = null;
  }
}

/// A microphone that hums a 440 Hz tone, so audio levels are measurable.
({MediaStream stream, MediaStreamTrack track, void Function() stop})
toneMicrophone() {
  final context = web.AudioContext();
  final oscillator = context.createOscillator()..frequency.value = 440;
  final destination = context.createMediaStreamDestination();
  oscillator
    ..connect(destination)
    ..start();
  final stream = MediaStreamWeb(destination.stream, 'local');
  return (
    stream: stream,
    track: stream.getAudioTracks().first,
    stop: () {
      oscillator.stop();
      context.close();
    },
  );
}

Future<int> audioBytesReceived(RTCPeerConnection pc) =>
    _inboundBytes(pc, 'audio');

Future<int> _inboundBytes(RTCPeerConnection pc, String kind) async {
  var bytes = 0;
  for (final report in await pc.getStats()) {
    if (report.type == 'inbound-rtp' &&
        (report.values['kind'] ?? report.values['mediaType']) == kind) {
      bytes += (report.values['bytesReceived'] as num? ?? 0).toInt();
    }
  }
  return bytes;
}

/// Peers on one in-memory signaling bus, torn down together.
class PeerHarness {
  final SignalBus bus = SignalBus();
  final List<WebRTCService> _services = [];

  Future<WebRTCService> join(
    String userId, {
    bool isHost = false,
    MediaStream? localStream,
  }) async {
    final service = WebRTCService(
      signalingFactory: (roomId, uid) => FakeSignaling(bus, roomId, uid),
    );
    _services.add(service);
    service.updateLocalStream(localStream);
    await service.joinRoom('room', userId, isHost: isHost);
    return service;
  }

  Future<void> dispose() async {
    for (final service in _services) {
      await service.dispose();
    }
    _services.clear();
  }
}

/// Waits until [read] has grown by more than [by] from where it is now.
Future<void> waitForGrowth(
  Future<int> Function() read,
  String what, {
  int by = 0,
}) async {
  final start = await read();
  await waitForAsync(() async => await read() > start + by, what);
}

/// Whether this browser lets audio run without a click. Without it, the
/// synthetic microphones stay silent; run the media tests through
/// tool/chrome_with_fake_media.sh (see README).
Future<bool> audioCanRun() async {
  final context = web.AudioContext();
  try {
    await context.resume().toDart.timeout(const Duration(seconds: 1));
  } catch (_) {
    // Stays suspended.
  }
  final running = context.state == 'running';
  await context.close().toDart;
  return running;
}

const String needsAutoplay =
    'Audio needs autoplay: run with '
    'CHROME_EXECUTABLE=tool/chrome_with_fake_media.sh';

/// Plays [stream] like the app's renderer does; Chrome only measures the
/// level of received audio that is actually played.
Future<void Function()> playRemoteAudio(MediaStream stream) async {
  final element = web.HTMLAudioElement()
    ..srcObject = (stream as MediaStreamWeb).jsStream;
  await element.play().toDart;
  return () {
    element.pause();
    element.srcObject = null;
  };
}
