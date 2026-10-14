import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';

/// Compact "live" pill describing the current share: what is shared, which
/// profile is used and whether audio is going out.
class ScreenShareStatus extends StatelessWidget {
  const ScreenShareStatus({super.key, required this.share});

  final ActiveScreenShare share;

  static String _details(ActiveScreenShare share) => [
    if (share.surface != ScreenShareSurface.any) share.surface.title,
    share.profile.title,
  ].join(' · ');

  /// One-line description of [share], e.g. for a tooltip.
  static String summary(ActiveScreenShare share) => [
    LocaleKeys.call_screenShare_sharingNow.tr(args: [_details(share)]),
    if (share.hasAudio)
      LocaleKeys.call_screenShare_withAudio.tr()
    else if (share.isAudioMissing)
      LocaleKeys.call_screenShare_audioMissing.tr(),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final details = _details(share);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              LocaleKeys.call_screenShare_sharingNow.tr(args: [details]),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (share.hasAudio) ...[
            const SizedBox(width: 10),
            const Icon(Icons.volume_up, size: 14, color: Colors.greenAccent),
            const SizedBox(width: 4),
            Text(
              LocaleKeys.call_screenShare_withAudio.tr(),
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ] else if (share.isAudioMissing) ...[
            const SizedBox(width: 10),
            const Icon(Icons.volume_off, size: 14, color: Colors.orangeAccent),
            const SizedBox(width: 4),
            Text(
              LocaleKeys.call_screenShare_audioMissing.tr(),
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pulsing red "live" dot.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8});

  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
