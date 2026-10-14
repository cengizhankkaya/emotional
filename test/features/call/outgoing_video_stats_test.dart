import 'package:emotional/features/call/domain/screen_share/outgoing_video_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the WebRTC qualityLimitationReason values', () {
    expect(VideoQualityLimit.fromStat('none'), VideoQualityLimit.none);
    expect(VideoQualityLimit.fromStat(null), VideoQualityLimit.none);
    expect(
      VideoQualityLimit.fromStat('bandwidth'),
      VideoQualityLimit.bandwidth,
    );
    expect(VideoQualityLimit.fromStat('cpu'), VideoQualityLimit.cpu);
    expect(VideoQualityLimit.fromStat('other'), VideoQualityLimit.other);
  });

  test('the weakest peer is the one with the lowest resolution', () {
    const sharp = OutgoingVideoStats(height: 1080, bitrate: 1000000);
    const blurry = OutgoingVideoStats(height: 540, bitrate: 5000000);
    const slower = OutgoingVideoStats(height: 1080, bitrate: 500000);
    expect(blurry.isWorseThan(sharp), isTrue);
    expect(slower.isWorseThan(sharp), isTrue);
    expect(sharp.isWorseThan(blurry), isFalse);
  });
}
