import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenShareOptions.toDisplayMediaConstraints', () {
    test('maps the profile to capture size and frame rate', () {
      const options = ScreenShareOptions(profile: ScreenShareProfile.detail);
      final video = options.toDisplayMediaConstraints()['video'] as Map;

      expect(video['width'], {'ideal': 1920});
      expect(video['height'], {'ideal': 1080});
      expect(video['frameRate'], {'ideal': 15, 'max': 15});
    });

    test('adds the surface hint only when one is preferred', () {
      const any = ScreenShareOptions();
      const tab = ScreenShareOptions(
        preferredSurface: ScreenShareSurface.browser,
      );

      expect(
        (any.toDisplayMediaConstraints()['video'] as Map).containsKey(
          'displaySurface',
        ),
        isFalse,
      );
      expect(
        (tab.toDisplayMediaConstraints()['video'] as Map)['displaySurface'],
        'browser',
      );
    });

    test('requests unprocessed audio only when sharing audio', () {
      final silent = const ScreenShareOptions().toDisplayMediaConstraints();
      final withAudio = const ScreenShareOptions(
        shareAudio: true,
      ).toDisplayMediaConstraints();

      expect(silent['audio'], isFalse);
      expect(silent['systemAudio'], 'exclude');
      expect(withAudio['audio'], {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
        'suppressLocalAudioPlayback': false,
      });
      expect(withAudio['systemAudio'], 'include');
    });

    test('never offers the app tab itself', () {
      expect(
        const ScreenShareOptions()
            .toDisplayMediaConstraints()['selfBrowserSurface'],
        'exclude',
      );
    });
  });

  group('ScreenShareOptions JSON', () {
    test('round-trips', () {
      const options = ScreenShareOptions(
        profile: ScreenShareProfile.motion,
        preferredSurface: ScreenShareSurface.window,
        shareAudio: true,
      );

      expect(ScreenShareOptions.fromJson(options.toJson()), options);
    });

    test('falls back to defaults for unknown values', () {
      expect(
        ScreenShareOptions.fromJson(const {'profile': 'x', 'surface': 'y'}),
        const ScreenShareOptions(),
      );
    });
  });

  group('ActiveScreenShare.isAudioMissing', () {
    test('is true only when audio was requested but not captured', () {
      const missing = ActiveScreenShare(
        profile: ScreenShareProfile.balanced,
        surface: ScreenShareSurface.monitor,
        audioRequested: true,
        hasAudio: false,
      );
      const notRequested = ActiveScreenShare(
        profile: ScreenShareProfile.balanced,
        surface: ScreenShareSurface.monitor,
        audioRequested: false,
        hasAudio: false,
      );

      expect(missing.isAudioMissing, isTrue);
      expect(notRequested.isAudioMissing, isFalse);
    });
  });

  test('ScreenShareSurface.fromDisplaySurface maps browser values', () {
    expect(
      ScreenShareSurface.fromDisplaySurface('browser'),
      ScreenShareSurface.browser,
    );
    expect(
      ScreenShareSurface.fromDisplaySurface('monitor'),
      ScreenShareSurface.monitor,
    );
    expect(ScreenShareSurface.fromDisplaySurface(null), ScreenShareSurface.any);
  });
}
