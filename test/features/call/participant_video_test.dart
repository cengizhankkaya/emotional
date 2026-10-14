import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:emotional/features/call/presentation/participant_video.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  const laptop = 16 / 9; // and most webcams' 4:3
  const webcam = 4 / 3;
  const phone = 9 / 16; // upright
  const phoneTurned = 16 / 9;

  const cover = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  const contain = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;

  RTCVideoViewObjectFit fit(double video, double box) =>
      fitVideo(videoAspectRatio: video, boxAspectRatio: box);

  group('VideoShape', () {
    test('laptops are wide, upright phones tall', () {
      expect(VideoShape.of(laptop), VideoShape.landscape);
      expect(VideoShape.of(webcam), VideoShape.landscape);
      expect(VideoShape.of(phone), VideoShape.portrait);
      expect(VideoShape.of(3 / 4), VideoShape.portrait);
      expect(VideoShape.of(1), VideoShape.square);
      expect(VideoShape.of(1.1), VideoShape.square);
    });
  });

  group('fitVideo', () {
    test('a camera shaped like its tile fills it', () {
      expect(fit(laptop, 16 / 9), cover);
      expect(fit(webcam, 16 / 9), cover, reason: '4:3 in 16:9 crops a little');
      expect(fit(laptop, 4 / 3), cover);
      expect(fit(phone, 3 / 4), cover);
      expect(fit(phone, phone), cover);
    });

    test('a phone in a wide tile is shown whole, not cut to a strip', () {
      expect(fit(phone, 4 / 3), contain);
      expect(fit(phone, 16 / 9), contain);
    });

    test('a laptop on an upright phone screen is shown whole', () {
      expect(fit(laptop, 9 / 19.5), contain);
      expect(fit(webcam, 3 / 4), contain);
    });

    test('a phone turned sideways fills a wide tile again', () {
      expect(fit(phoneTurned, 4 / 3), cover);
    });

    test('unknown sizes fall back to filling', () {
      expect(fit(0, 4 / 3), cover);
      expect(fit(laptop, 0), cover);
    });
  });

  group('videoTileAspectRatio', () {
    RTCVideoValue value(double width, double height, {int rotation = 0}) =>
        RTCVideoValue(
          width: width,
          height: height,
          rotation: rotation,
          renderVideo: true,
        );

    test('takes the camera shape', () {
      expect(videoTileAspectRatio(value(640, 480)), closeTo(4 / 3, 0.001));
      expect(videoTileAspectRatio(value(1280, 720)), closeTo(16 / 9, 0.001));
    });

    test('keeps tall and very wide pictures within bounds', () {
      expect(videoTileAspectRatio(value(720, 1280)), 3 / 4);
      expect(videoTileAspectRatio(value(2560, 720)), 16 / 9);
      expect(
        videoTileAspectRatio(value(720, 1280), min: 9 / 16),
        closeTo(9 / 16, 0.001),
      );
    });

    test('a phone camera reported rotated counts as turned', () {
      // Native renderers report the sensor size plus a rotation.
      expect(
        videoTileAspectRatio(value(1280, 720, rotation: 90), min: 9 / 16),
        closeTo(9 / 16, 0.001),
      );
    });

    test('before the first frame it uses the fallback', () {
      expect(videoTileAspectRatio(RTCVideoValue.empty), 4 / 3);
      expect(videoTileAspectRatio(RTCVideoValue.empty, fallback: 1), 1);
    });
  });

  group('ClientPlatform', () {
    test('reads what other apps wrote, ignores the unknown', () {
      for (final platform in ClientPlatform.values) {
        expect(ClientPlatform.fromName(platform.name), platform);
      }
      expect(ClientPlatform.fromName(null), isNull, reason: 'older apps');
      expect(ClientPlatform.fromName('tv'), isNull);
    });

    test('knows the device it runs on', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        ClientPlatform.current,
        kIsWeb ? ClientPlatform.web : ClientPlatform.ios,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        ClientPlatform.current,
        kIsWeb ? ClientPlatform.web : ClientPlatform.android,
      );
    });

    test('phones are phones', () {
      expect(ClientPlatform.android.isPhone, isTrue);
      expect(ClientPlatform.ios.isPhone, isTrue);
      expect(ClientPlatform.web.isPhone, isFalse);
    });
  });

  testWidgets('the badge shows where someone joined from', (tester) async {
    for (final (platform, icon) in [
      (ClientPlatform.web, Icons.language),
      (ClientPlatform.android, Icons.phone_android),
      (ClientPlatform.ios, Icons.phone_iphone),
      (ClientPlatform.windows, Icons.laptop),
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: PlatformBadge(platform: platform)),
      );
      expect(find.byIcon(icon), findsOneWidget, reason: platform.name);
      // Keys stand in for text: no translations are loaded in tests.
      expect(find.byTooltip('call.platform.connectedFrom'), findsOneWidget);
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformBadge(platform: ClientPlatform.ios, showTooltip: false),
      ),
    );
    expect(find.byType(Tooltip), findsNothing);
  });
}
