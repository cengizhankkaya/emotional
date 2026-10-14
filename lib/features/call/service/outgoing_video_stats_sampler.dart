import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Reads the `outbound-rtp` video statistics of every peer connection and
/// reports the weakest one. Bitrate needs two samples, so keep one instance
/// and call [sample] periodically.
class OutgoingVideoStatsSampler {
  /// Last `bytesSent` per outbound video stream.
  final Map<String, ({num bytes, double timestamp})> _previous = {};

  Future<OutgoingVideoStats?> sample(
    Map<String, RTCPeerConnection> connections,
  ) async {
    OutgoingVideoStats? weakest;
    var limit = VideoQualityLimit.none;
    final seen = <String>{};

    for (final MapEntry(key: peerId, value: connection)
        in connections.entries.toList()) {
      List<StatsReport> reports;
      try {
        reports = await connection.getStats();
      } catch (_) {
        continue;
      }
      for (final report in reports) {
        final values = report.values;
        final kind = values['kind'] ?? values['mediaType'];
        if (report.type != 'outbound-rtp' || kind != 'video') continue;

        final key = '$peerId/${report.id}';
        seen.add(key);
        final stats = OutgoingVideoStats(
          width: (values['frameWidth'] as num?)?.toInt(),
          height: (values['frameHeight'] as num?)?.toInt(),
          framesPerSecond: (values['framesPerSecond'] as num?)?.toDouble(),
          bitrate: _bitrate(key, values['bytesSent'], report.timestamp),
          limit: VideoQualityLimit.fromStat(values['qualityLimitationReason']),
          encoder: values['encoderImplementation'] as String?,
        );

        // Any limited peer counts; a CPU limit wins as it affects them all.
        if (stats.limit != VideoQualityLimit.none &&
            limit != VideoQualityLimit.cpu) {
          limit = stats.limit;
        }
        if (weakest == null || stats.isWorseThan(weakest)) weakest = stats;
      }
    }

    _previous.removeWhere((key, _) => !seen.contains(key));
    if (weakest == null) return null;
    return OutgoingVideoStats(
      width: weakest.width,
      height: weakest.height,
      framesPerSecond: weakest.framesPerSecond,
      bitrate: weakest.bitrate,
      limit: limit,
      encoder: weakest.encoder,
    );
  }

  int? _bitrate(String key, Object? bytes, double timestamp) {
    if (bytes is! num) return null;
    final previous = _previous[key];
    _previous[key] = (bytes: bytes, timestamp: timestamp);
    if (previous == null) return null;
    final seconds = (timestamp - previous.timestamp) / 1000;
    if (seconds <= 0) return null;
    return ((bytes - previous.bytes) * 8 / seconds).round();
  }
}
