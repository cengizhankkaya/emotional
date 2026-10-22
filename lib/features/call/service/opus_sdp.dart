/// Asks peers for stereo Opus in an SDP we are about to use.
///
/// Browsers encode Opus in mono unless the receiving side's SDP says
/// `stereo=1`, which would fold a shared film's or song's sound into one
/// channel. Microphones are mono and stay mono; only stereo sources (a
/// shared tab's sound) use the second channel.
String withStereoOpus(String sdp) {
  final opus = RegExp(
    r'^a=rtpmap:(\d+) opus/48000/2',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(sdp).map((m) => m.group(1)!).toSet();
  if (opus.isEmpty) return sdp;

  final lineBreak = sdp.contains('\r\n') ? '\r\n' : '\n';
  final fmtp = RegExp(r'^a=fmtp:(\d+) (.*)$');
  final lines = sdp.split(lineBreak);
  for (var i = 0; i < lines.length; i++) {
    final match = fmtp.firstMatch(lines[i]);
    if (match == null || !opus.contains(match.group(1))) continue;
    final keys = match
        .group(2)!
        .split(';')
        .map((p) => p.split('=').first.trim().toLowerCase())
        .toSet();
    for (final key in const ['stereo', 'sprop-stereo']) {
      if (!keys.contains(key)) lines[i] += ';$key=1';
    }
  }
  return lines.join(lineBreak);
}
