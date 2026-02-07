import 'dart:async';
import 'package:media_kit/media_kit.dart';

abstract class VideoPlayerService {
  Future<void> initialize();
  Future<void> dispose();
  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);

  Player get player;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<double> get rateStream;

  bool get isPlaying;
  Duration get position;
  double get rate;

  Future<void> setAudioTrack(AudioTrack track);
  Future<void> setSubtitleTrack(SubtitleTrack track);

  Stream<Track> get trackStream;
  Stream<Tracks> get tracksStream;

  Track get track;
  Tracks get tracks;

  Stream<bool> get bufferingStream;
  bool get isBuffering;
}

class MediaKitVideoPlayerService implements VideoPlayerService {
  late final Player _player;

  @override
  Player get player => _player;

  @override
  Future<void> initialize() async {
    _player = Player();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }

  @override
  Future<void> open(String path) async {
    await _player.open(Media(path), play: true);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setRate(double rate) async {
    await _player.setRate(rate);
  }

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<double> get rateStream => _player.stream.rate;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Duration get position => _player.state.position;

  @override
  double get rate => _player.state.rate;

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
  }

  @override
  Stream<Track> get trackStream => _player.stream.track;

  @override
  Stream<Tracks> get tracksStream => _player.stream.tracks;

  @override
  Track get track => _player.state.track;

  @override
  Tracks get tracks => _player.state.tracks;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  bool get isBuffering => _player.state.buffering;
}
