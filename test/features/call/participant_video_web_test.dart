@TestOn('browser')
library;

import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'support/call_test_support.dart';

/// ParticipantVideo with real browser renderers and synthetic cameras:
/// 320x240 like a laptop, 180x320 like a phone held upright.
void main() {
  final cleanups = <void Function()>[];
  tearDown(() {
    for (final cleanup in cleanups) {
      cleanup();
    }
    cleanups.clear();
  });

  Future<MediaStream> camera({required int width, required int height}) async {
    final fake = fakeCamera(width: width, height: height);
    cleanups.add(fake.stop);
    final stream = await createLocalMediaStream('camera-$width-$height');
    await stream.addTrack(fake.track);
    return stream;
  }

  /// A renderer showing [stream], once the browser knows its size.
  Future<RTCVideoRenderer> showing(MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    cleanups.add(renderer.dispose);
    renderer.srcObject = stream;
    await waitFor(() => renderer.value.width > 0, 'the first frame');
    return renderer;
  }

  /// RTCVideoView's web element schedules a short timer; let it run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  RTCVideoViewObjectFit shownFit(WidgetTester tester) =>
      tester.widget<RTCVideoView>(find.byType(RTCVideoView)).objectFit;

  Widget tile(RTCVideoRenderer renderer, Size size) => MaterialApp(
    home: Center(
      child: SizedBox.fromSize(
        size: size,
        child: ParticipantVideo(renderer: renderer),
      ),
    ),
  );

  testWidgets('a laptop fills a wide tile; a phone is shown whole in it', (
    tester,
  ) async {
    late RTCVideoRenderer laptop;
    late RTCVideoRenderer phone;
    await tester.runAsync(() async {
      laptop = await showing(await camera(width: 320, height: 240));
      phone = await showing(await camera(width: 180, height: 320));
    });
    expect(VideoShape.of(laptop.value.aspectRatio), VideoShape.landscape);
    expect(VideoShape.of(phone.value.aspectRatio), VideoShape.portrait);

    const wideTile = Size(200, 150);
    await tester.pumpWidget(tile(laptop, wideTile));
    expect(shownFit(tester), RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);

    await tester.pumpWidget(tile(phone, wideTile));
    expect(
      shownFit(tester),
      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      reason: 'cover would cut the face out of a tall picture',
    );

    // The same phone in a tall tile fills it.
    await tester.pumpWidget(tile(phone, const Size(150, 266)));
    expect(shownFit(tester), RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
    await finish(tester);
  });

  testWidgets('follows the picture when it changes shape', (tester) async {
    // A phone turned sideways, or a different camera picked.
    late RTCVideoRenderer renderer;
    late MediaStream turned;
    await tester.runAsync(() async {
      renderer = await showing(await camera(width: 180, height: 320));
      turned = await camera(width: 320, height: 180);
    });
    await tester.pumpWidget(tile(renderer, const Size(200, 150)));
    expect(
      shownFit(tester),
      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );

    await tester.runAsync(() async {
      renderer.srcObject = turned;
      await waitFor(
        () => renderer.value.aspectRatio > 1.5,
        'the new shape to be known',
      );
    });
    await tester.pump();
    expect(shownFit(tester), RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
    await finish(tester);
  });

  testWidgets('an enlarged camera takes the picture shape', (tester) async {
    late RTCVideoRenderer phone;
    await tester.runAsync(() async {
      phone = await showing(await camera(width: 180, height: 320));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VideoAspectRatio(
            renderer: phone,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final frame = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(frame.aspectRatio, closeTo(180 / 320, 0.001));
  });
}
