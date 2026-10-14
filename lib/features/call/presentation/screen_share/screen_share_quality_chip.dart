import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the sharer what their viewers actually receive (resolution, frame
/// rate, bitrate) and, when the browser lowers quality, whether the network
/// or the computer is the reason.
class ScreenShareQualityChip extends StatefulWidget {
  const ScreenShareQualityChip({super.key});

  @override
  State<ScreenShareQualityChip> createState() => _ScreenShareQualityChipState();
}

class _ScreenShareQualityChipState extends State<ScreenShareQualityChip> {
  static const _interval = Duration(seconds: 2);

  Timer? _timer;
  OutgoingVideoStats? _stats;

  @override
  void initState() {
    super.initState();
    _sample();
    _timer = Timer.periodic(_interval, (_) => _sample());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    final stats = await context.read<CallBloc>().outgoingVideoStats();
    if (mounted && stats != _stats) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final height = stats?.height;
    final measured = stats != null && height != null && height > 0;

    final label = measured
        ? [
            '${height}p',
            if (stats.framesPerSecond != null)
              '${stats.framesPerSecond!.round()} fps',
            if (stats.bitrate != null)
              '${(stats.bitrate! / 1000000).toStringAsFixed(1)} Mbps',
          ].join(' · ')
        : LocaleKeys.call_screenShare_qualityMeasuring.tr();

    final (color, reason) = switch (stats?.limit) {
      _ when !measured => (Colors.white38, null),
      VideoQualityLimit.bandwidth => (
        Colors.orangeAccent,
        LocaleKeys.call_screenShare_qualityBandwidth.tr(),
      ),
      VideoQualityLimit.cpu => (
        Colors.orangeAccent,
        LocaleKeys.call_screenShare_qualityCpu.tr(),
      ),
      VideoQualityLimit.other => (
        Colors.amberAccent,
        LocaleKeys.call_screenShare_qualityOther.tr(),
      ),
      _ => (Colors.greenAccent, LocaleKeys.call_screenShare_qualityGood.tr()),
    };

    final tooltip = [
      ?reason,
      if (stats?.encoder case final encoder?)
        LocaleKeys.call_screenShare_qualityEncoder.tr(args: [encoder]),
    ].join('\n');

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (measured && stats.limit != VideoQualityLimit.none) ...[
              const SizedBox(width: 6),
              Icon(Icons.info_outline, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
