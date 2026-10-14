import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:equatable/equatable.dart';

/// What the shared content is optimised for.
///
/// Drives the capture resolution and frame rate, the video track's
/// `contentHint` (how the encoder trades sharpness against smoothness when
/// bandwidth drops) and the sender's bitrate cap.
enum ScreenShareProfile {
  /// Slides, documents, code: keeps full resolution and drops frames first,
  /// so text stays readable.
  detail(
    width: 1920,
    height: 1080,
    frameRate: 15,
    contentHint: 'detail',
    maxBitrate: 4000000,
  ),

  /// Video, games, animation: keeps the frame rate and drops resolution
  /// first, so motion stays smooth.
  motion(
    width: 1920,
    height: 1080,
    frameRate: 30,
    contentHint: 'motion',
    maxBitrate: 6000000,
  ),

  /// Lets the browser decide; a sensible default for mixed content.
  balanced(
    width: 1920,
    height: 1080,
    frameRate: 24,
    contentHint: '',
    maxBitrate: 4500000,
  );

  const ScreenShareProfile({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.contentHint,
    required this.maxBitrate,
  });

  final int width;
  final int height;
  final int frameRate;

  /// `MediaStreamTrack.contentHint` value; empty means no hint.
  final String contentHint;

  /// Upper bound for the video sender, in bits per second. Only a ceiling:
  /// the browser still sends less when the connection can't carry it.
  final int maxBitrate;

  String get title => switch (this) {
    ScreenShareProfile.detail => LocaleKeys.call_screenShare_profileDetail.tr(),
    ScreenShareProfile.motion => LocaleKeys.call_screenShare_profileMotion.tr(),
    ScreenShareProfile.balanced =>
      LocaleKeys.call_screenShare_profileBalanced.tr(),
  };

  String get description => switch (this) {
    ScreenShareProfile.detail =>
      LocaleKeys.call_screenShare_profileDetailDesc.tr(),
    ScreenShareProfile.motion =>
      LocaleKeys.call_screenShare_profileMotionDesc.tr(),
    ScreenShareProfile.balanced =>
      LocaleKeys.call_screenShare_profileBalancedDesc.tr(),
  };
}

/// The kind of surface being shared, matching the browser's
/// `displaySurface` values.
enum ScreenShareSurface {
  /// No preference: the browser picker opens on its default tab.
  any(null),
  browser('browser'),
  window('window'),
  monitor('monitor');

  const ScreenShareSurface(this.displaySurface);

  final String? displaySurface;

  static ScreenShareSurface fromDisplaySurface(String? value) =>
      ScreenShareSurface.values.firstWhere(
        (s) => s.displaySurface == value,
        orElse: () => ScreenShareSurface.any,
      );

  String get title => switch (this) {
    ScreenShareSurface.any => LocaleKeys.call_screenShare_sourceAny.tr(),
    ScreenShareSurface.browser =>
      LocaleKeys.call_screenShare_sourceBrowser.tr(),
    ScreenShareSurface.window => LocaleKeys.call_screenShare_sourceWindow.tr(),
    ScreenShareSurface.monitor =>
      LocaleKeys.call_screenShare_sourceMonitor.tr(),
  };
}

/// What the user picked before starting a share.
class ScreenShareOptions extends Equatable {
  const ScreenShareOptions({
    this.profile = ScreenShareProfile.balanced,
    this.preferredSurface = ScreenShareSurface.any,
    this.shareAudio = false,
  });

  factory ScreenShareOptions.fromJson(Map<String, dynamic> json) {
    return ScreenShareOptions(
      profile: ScreenShareProfile.values.firstWhere(
        (p) => p.name == json['profile'],
        orElse: () => ScreenShareProfile.balanced,
      ),
      preferredSurface: ScreenShareSurface.values.firstWhere(
        (s) => s.name == json['surface'],
        orElse: () => ScreenShareSurface.any,
      ),
      shareAudio: json['audio'] == true,
    );
  }

  final ScreenShareProfile profile;
  final ScreenShareSurface preferredSurface;
  final bool shareAudio;

  Map<String, dynamic> toJson() => {
    'profile': profile.name,
    'surface': preferredSurface.name,
    'audio': shareAudio,
  };

  ScreenShareOptions copyWith({
    ScreenShareProfile? profile,
    ScreenShareSurface? preferredSurface,
    bool? shareAudio,
  }) {
    return ScreenShareOptions(
      profile: profile ?? this.profile,
      preferredSurface: preferredSurface ?? this.preferredSurface,
      shareAudio: shareAudio ?? this.shareAudio,
    );
  }

  /// Options for `navigator.mediaDevices.getDisplayMedia` in the browser.
  /// Browsers ignore the hints they don't support.
  Map<String, dynamic> toDisplayMediaConstraints() {
    return {
      'video': {
        'width': {'ideal': profile.width},
        'height': {'ideal': profile.height},
        'frameRate': {'ideal': profile.frameRate, 'max': profile.frameRate},
        if (preferredSurface.displaySurface != null)
          'displaySurface': preferredSurface.displaySurface,
      },
      // Voice processing would damage music and film audio.
      'audio': shareAudio
          ? {
              'echoCancellation': false,
              'noiseSuppression': false,
              'autoGainControl': false,
              // Keep playing the tab's sound for the person sharing it.
              'suppressLocalAudioPlayback': false,
            }
          : false,
      'systemAudio': shareAudio ? 'include' : 'exclude',
      // Hide the Emoti tab itself so nobody shares an infinite mirror.
      'selfBrowserSurface': 'exclude',
      // Chrome's "Share this tab instead" button.
      'surfaceSwitching': 'include',
      'monitorTypeSurfaces': 'include',
    };
  }

  @override
  List<Object?> get props => [profile, preferredSurface, shareAudio];
}

/// What the current browser can do; drives which options the UI offers.
class ScreenShareCapabilities extends Equatable {
  const ScreenShareCapabilities({
    required this.isSupported,
    required this.canPreferSurface,
    required this.canShareAudio,
  });

  static const none = ScreenShareCapabilities(
    isSupported: false,
    canPreferSurface: false,
    canShareAudio: false,
  );

  final bool isSupported;

  /// The browser honours the `displaySurface` hint (Chromium).
  final bool canPreferSurface;

  /// The browser can capture tab/system audio (Chromium only).
  final bool canShareAudio;

  @override
  List<Object?> get props => [isSupported, canPreferSurface, canShareAudio];
}

/// The share that is currently live, as reported by the browser.
class ActiveScreenShare extends Equatable {
  const ActiveScreenShare({
    required this.profile,
    required this.surface,
    required this.audioRequested,
    required this.hasAudio,
  });

  final ScreenShareProfile profile;

  /// What the user actually picked in the browser dialog, which may differ
  /// from the preference.
  final ScreenShareSurface surface;
  final bool audioRequested;
  final bool hasAudio;

  /// Audio was asked for but the user didn't tick "share audio" (or picked a
  /// surface without audio).
  bool get isAudioMissing => audioRequested && !hasAudio;

  @override
  List<Object?> get props => [profile, surface, audioRequested, hasAudio];
}
