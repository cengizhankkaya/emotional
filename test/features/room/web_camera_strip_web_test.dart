@TestOn('browser')
library;

import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:emotional/features/room/presentation/widgets/web/web_camera_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../call/support/call_test_support.dart';

/// The camera strip beside a screen share, with real renderers: the
/// sharer's tile shows their camera (sent next to the screen), never the
/// screen itself, and follows the camera being switched on and off.
void main() {
  final cleanups = <void Function()>[];
  tearDown(() {
    for (final cleanup in cleanups) {
      cleanup();
    }
    cleanups.clear();
  });

  Future<RTCVideoRenderer> renderer(String label) async {
    final fake = fakeCamera();
    cleanups.add(fake.stop);
    final stream = await createLocalMediaStream(label);
    await stream.addTrack(fake.track);
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    cleanups.add(renderer.dispose);
    renderer.srcObject = stream;
    return renderer;
  }

  /// RTCVideoView's web element schedules a short timer; let it run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget strip(CallConnected state, {required String sharer}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 200,
        height: 600,
        child: WebCameraStrip(
          callState: state,
          participants: const ['me', 'sharer'],
          userNames: const {'sharer': 'Sharer'},
          currentUserId: 'me',
          sharingUserId: sharer,
        ),
      ),
    ),
  );

  List<RTCVideoRenderer> shown(WidgetTester tester) => tester
      .widgetList<ParticipantVideo>(find.byType(ParticipantVideo))
      .map((v) => v.renderer)
      .toList();

  testWidgets("someone else's camera shows next to their screen, live", (
    tester,
  ) async {
    late RTCVideoRenderer local;
    late RTCVideoRenderer screen;
    late RTCVideoRenderer camera;
    await tester.runAsync(() async {
      local = await renderer('local');
      screen = await renderer('screen');
      camera = await renderer('camera');
    });

    final sharing = CallConnected(
      localRenderer: local,
      remoteRenderers: {'sharer': screen},
      userVideoStates: const {'sharer': true},
      userScreenSharingStates: const {'sharer': true},
      shareCameraRenderers: {'sharer': camera},
      userShareCameraStates: const {'sharer': true},
    );
    await tester.pumpWidget(strip(sharing, sharer: 'sharer'));
    expect(shown(tester), [camera], reason: 'the camera, not the screen');
    expect(find.text('web.sharingScreen'), findsOneWidget);

    // Camera switched off mid-share: their initial, still marked sharing.
    await tester.pumpWidget(
      strip(
        sharing.copyWith(userShareCameraStates: const {'sharer': false}),
        sharer: 'sharer',
      ),
    );
    expect(shown(tester), isEmpty);
    expect(find.text('S'), findsOneWidget);
    expect(find.byTooltip('web.cameraOffWhileSharing'), findsOneWidget);

    // And on again.
    await tester.pumpWidget(strip(sharing, sharer: 'sharer'));
    expect(shown(tester), [camera]);

    // An older app sends no camera with its screen: the initial again.
    await tester.pumpWidget(
      strip(
        sharing.copyWith(
          shareCameraRenderers: const {},
          userShareCameraStates: const {},
        ),
        sharer: 'sharer',
      ),
    );
    expect(shown(tester), isEmpty);
    await finish(tester);
  });

  testWidgets('my own camera shows next to my screen, mirrored', (
    tester,
  ) async {
    late RTCVideoRenderer screen;
    late RTCVideoRenderer camera;
    late RTCVideoRenderer other;
    await tester.runAsync(() async {
      screen = await renderer('screen');
      camera = await renderer('camera');
      other = await renderer('other');
    });

    // While I share, localRenderer shows my screen.
    final sharing = CallConnected(
      localRenderer: screen,
      remoteRenderers: {'sharer': other},
      userVideoStates: const {'sharer': true},
      isScreenSharing: true,
      isVideoEnabled: true,
      cameraAfterShare: true,
      localShareCameraRenderer: camera,
    );
    // Here "me" is the sharer and "sharer" just another camera.
    await tester.pumpWidget(strip(sharing, sharer: 'me'));
    expect(shown(tester), containsAll([camera, other]));
    expect(shown(tester), isNot(contains(screen)));
    final mine = tester
        .widgetList<ParticipantVideo>(find.byType(ParticipantVideo))
        .singleWhere((v) => v.renderer == camera);
    expect(mine.mirror, isTrue);

    // Camera off mid-share: my tile shows my initial, not my screen.
    await tester.pumpWidget(
      strip(
        sharing.copyWith(
          cameraAfterShare: false,
          localShareCameraRenderer: null,
        ),
        sharer: 'me',
      ),
    );
    expect(shown(tester), [other]);
    await finish(tester);
  });
}
