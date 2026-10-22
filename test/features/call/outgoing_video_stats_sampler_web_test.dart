@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart'
    show MediaStreamTrackWeb, MediaStreamWeb;
import 'package:emotional/features/call/service/outgoing_video_stats_sampler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'reads resolution, bitrate and encoder from a live connection',
    () async {
      // A moving canvas so the encoder has something to send.
      final canvas = web.HTMLCanvasElement()
        ..width = 640
        ..height = 360;
      final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      var frame = 0;
      final painter = Timer.periodic(const Duration(milliseconds: 33), (_) {
        context
          ..fillStyle = 'hsl(${frame++ % 360}, 80%, 50%)'.toJS
          ..fillRect(0, 0, 640, 360);
      });
      addTearDown(painter.cancel);

      final jsStream = canvas.captureStream(30);
      final stream = MediaStreamWeb(jsStream, 'local');
      final track = MediaStreamTrackWeb(jsStream.getVideoTracks().toDart.first);

      final sender = await createPeerConnection({});
      final receiver = await createPeerConnection({});
      addTearDown(() async {
        await sender.close();
        await receiver.close();
      });
      sender.onIceCandidate = (c) => receiver.addCandidate(c);
      receiver.onIceCandidate = (c) => sender.addCandidate(c);
      await sender.addTrack(track, stream);

      final offer = await sender.createOffer();
      await sender.setLocalDescription(offer);
      await receiver.setRemoteDescription(offer);
      final answer = await receiver.createAnswer();
      await receiver.setLocalDescription(answer);
      await sender.setRemoteDescription(answer);

      final sampler = OutgoingVideoStatsSampler();
      final connections = {'peer': sender};
      await Future<void>.delayed(const Duration(seconds: 2));
      await sampler.sample(connections);
      await Future<void>.delayed(const Duration(seconds: 2));
      final stats = await sampler.sample(connections);

      expect(stats, isNotNull);
      expect(stats!.height, greaterThan(0));
      expect(stats.width, greaterThan(0));
      expect(stats.bitrate, greaterThan(0));
      expect(stats.framesPerSecond, isNotNull);
      // Excluding this track must remove its report, not merely its bitrate.
      expect(
        await sampler.sample(connections, excludedTrackIds: {track.id!}),
        isNull,
      );
      expect(await sampler.sample(connections), isNotNull);
      // Chrome only names the encoder once the page holds camera permission,
      // which a test page doesn't.
      // ignore: avoid_print
      print(
        'outgoing: ${stats.width}x${stats.height} '
        '${stats.framesPerSecond} fps ${stats.bitrate} bps '
        '${stats.limit} ${stats.encoder}',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
