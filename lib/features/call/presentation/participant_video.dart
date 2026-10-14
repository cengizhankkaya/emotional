import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/domain/client_platform.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// How a camera picture is shaped. Laptop and desktop cameras are wide;
/// phone cameras held upright are tall, and turn wide when rotated.
enum VideoShape {
  landscape,
  portrait,
  square;

  /// From width / height; a few percent either way still counts as square.
  static VideoShape of(double aspectRatio) {
    if (aspectRatio > 1.15) return VideoShape.landscape;
    if (aspectRatio < 0.87) return VideoShape.portrait;
    return VideoShape.square;
  }
}

/// Fill the box when the camera is shaped about like it (little is cut
/// off); otherwise show the whole picture, so a phone's tall picture in a
/// wide tile doesn't lose the face to cropping, nor a laptop's wide one in
/// a tall tile.
RTCVideoViewObjectFit fitVideo({
  required double videoAspectRatio,
  required double boxAspectRatio,
}) {
  if (videoAspectRatio <= 0 || boxAspectRatio <= 0) {
    return RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
  }
  final mismatch = videoAspectRatio > boxAspectRatio
      ? videoAspectRatio / boxAspectRatio
      : boxAspectRatio / videoAspectRatio;
  // 4:3 in 16:9 (or the reverse) is 1.33 and still fills fine; a phone's
  // 9:16 in a 4:3 tile is 2.37 and would lose most of the picture.
  return mismatch <= 1.45
      ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
      : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
}

/// A participant's camera that adapts to the picture it receives: fills
/// the box or fits inside it (see [fitVideo]), and follows a phone being
/// turned or a camera being switched.
class ParticipantVideo extends StatelessWidget {
  const ParticipantVideo({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.background = Colors.black,
  });

  final RTCVideoRenderer renderer;
  final bool mirror;

  /// Shows around a picture that doesn't fill the box.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: renderer,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final box = constraints.biggest;
          final fit = !box.isFinite || box.height == 0 || value.width == 0
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              : fitVideo(
                  videoAspectRatio: value.aspectRatio,
                  boxAspectRatio: box.width / box.height,
                );
          return ColoredBox(
            color: background,
            child: RTCVideoView(renderer, objectFit: fit, mirror: mirror),
          );
        },
      ),
    );
  }
}

/// The aspect ratio a tile should take for [renderer]'s picture, kept
/// between [min] (tall) and [max] (wide); [fallback] until it's known.
double videoTileAspectRatio(
  RTCVideoValue value, {
  double fallback = 4 / 3,
  double min = 3 / 4,
  double max = 16 / 9,
}) {
  if (value.width == 0 || value.height == 0) return fallback;
  return value.aspectRatio.clamp(min, max);
}

/// Laptop or phone icon, with "Connected from …" on hover/long press.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.platform,
    this.size = 12,
    this.color = Colors.white70,
    this.showTooltip = true,
  });

  final ClientPlatform platform;
  final double size;
  final Color color;

  /// Off where a long press already means something else.
  final bool showTooltip;

  static IconData iconFor(ClientPlatform platform) => switch (platform) {
    ClientPlatform.web => Icons.language,
    ClientPlatform.android => Icons.phone_android,
    ClientPlatform.ios => Icons.phone_iphone,
    ClientPlatform.macos ||
    ClientPlatform.windows ||
    ClientPlatform.linux => Icons.laptop,
  };

  static String labelFor(ClientPlatform platform) => switch (platform) {
    ClientPlatform.web => LocaleKeys.call_platform_web,
    ClientPlatform.android => LocaleKeys.call_platform_android,
    ClientPlatform.ios => LocaleKeys.call_platform_ios,
    ClientPlatform.macos => LocaleKeys.call_platform_macos,
    ClientPlatform.windows => LocaleKeys.call_platform_windows,
    ClientPlatform.linux => LocaleKeys.call_platform_linux,
  }.tr();

  @override
  Widget build(BuildContext context) {
    final label = LocaleKeys.call_platform_connectedFrom.tr(
      args: [labelFor(platform)],
    );
    final icon = Icon(
      iconFor(platform),
      size: size,
      color: color,
      semanticLabel: label,
    );
    return showTooltip ? Tooltip(message: label, child: icon) : icon;
  }
}

/// Gives [child] the shape of [renderer]'s picture, e.g. for an enlarged
/// camera: a phone held upright gets a tall frame instead of a thin column
/// in a wide one.
class VideoAspectRatio extends StatelessWidget {
  const VideoAspectRatio({
    super.key,
    required this.renderer,
    required this.child,
    this.fallback = 16 / 9,
    this.min = 9 / 16,
    this.max = 16 / 9,
  });

  final RTCVideoRenderer renderer;
  final Widget child;
  final double fallback;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: renderer,
      builder: (context, value, child) => AspectRatio(
        aspectRatio: videoTileAspectRatio(
          value,
          fallback: fallback,
          min: min,
          max: max,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
