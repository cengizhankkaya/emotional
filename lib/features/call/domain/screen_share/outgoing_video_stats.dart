import 'package:equatable/equatable.dart';

/// Why the browser is sending less than the capture provides, from the
/// `qualityLimitationReason` WebRTC statistic.
enum VideoQualityLimit {
  none,

  /// The connection can't carry more; resolution or frame rate is reduced.
  bandwidth,

  /// The encoder can't keep up on this computer.
  cpu,
  other;

  static VideoQualityLimit fromStat(Object? value) => switch (value) {
    'none' || null => VideoQualityLimit.none,
    'bandwidth' => VideoQualityLimit.bandwidth,
    'cpu' => VideoQualityLimit.cpu,
    _ => VideoQualityLimit.other,
  };
}

/// What actually leaves this device for the weakest peer connection.
class OutgoingVideoStats extends Equatable {
  const OutgoingVideoStats({
    this.width,
    this.height,
    this.framesPerSecond,
    this.bitrate,
    this.limit = VideoQualityLimit.none,
    this.encoder,
  });

  final int? width;
  final int? height;
  final double? framesPerSecond;

  /// Bits per second, measured between two samples.
  final int? bitrate;
  final VideoQualityLimit limit;

  /// `encoderImplementation`, e.g. libvpx or VideoToolbox.
  final String? encoder;

  /// Lower is worse; used to pick the weakest peer.
  int get _rank => (height ?? 0) * 100000000 + (bitrate ?? 0);

  bool isWorseThan(OutgoingVideoStats other) => _rank < other._rank;

  @override
  List<Object?> get props => [
    width,
    height,
    framesPerSecond,
    bitrate,
    limit,
    encoder,
  ];
}
