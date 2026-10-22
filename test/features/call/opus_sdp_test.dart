import 'package:emotional/features/call/service/opus_sdp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const audio = [
    'v=0',
    'm=audio 9 UDP/TLS/RTP/SAVPF 111 63',
    'a=rtpmap:111 opus/48000/2',
    'a=fmtp:111 minptime=10;useinbandfec=1',
    'a=rtpmap:63 red/48000/2',
    'a=fmtp:63 111/111',
    'm=video 9 UDP/TLS/RTP/SAVPF 96',
    'a=rtpmap:96 VP8/90000',
    'a=fmtp:96 x-google-start-bitrate=1000',
    '',
  ];

  test('asks for stereo on the Opus format only', () {
    final sdp = withStereoOpus(audio.join('\r\n'));
    final lines = sdp.split('\r\n');

    expect(
      lines,
      contains('a=fmtp:111 minptime=10;useinbandfec=1;stereo=1;sprop-stereo=1'),
    );
    expect(lines, contains('a=fmtp:63 111/111'));
    expect(lines, contains('a=fmtp:96 x-google-start-bitrate=1000'));
    expect(sdp.endsWith('\r\n'), isTrue, reason: 'line endings kept');
  });

  test('keeps what the SDP already says and runs twice safely', () {
    final mono = audio
        .join('\n')
        .replaceFirst('useinbandfec=1', 'useinbandfec=1;stereo=0');
    final once = withStereoOpus(mono);

    expect(once, contains('useinbandfec=1;stereo=0;sprop-stereo=1\n'));
    expect(withStereoOpus(once), once);
  });

  test('leaves an SDP without Opus alone', () {
    const video = 'v=0\r\nm=video 9 UDP 96\r\na=fmtp:96 profile=1\r\n';
    expect(withStereoOpus(video), video);
  });
}
