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
  Player? _player;

  @override
  Player get player {
    if (_player == null) {
      throw StateError(
        'Player has not been initialized. Call initialize() first.',
      );
    }
    return _player!;
  }

  static bool _mediaKitInitialized = false;

  @override
  Future<void> initialize() async {
    // Lazy-initialize MediaKit only when first Player is created.
    // Doing this at app startup causes mpv to allocate ~4GB virtual memory
    // on iOS, which crashes the app before any UI is shown.
    if (!_mediaKitInitialized) {
      MediaKit.ensureInitialized();
      _mediaKitInitialized = true;
    }

    // Dispose existing player if already initialized
    if (_player != null) {
      await _player!.dispose();
    }
    _player = Player();
  }


  @override
  Future<void> dispose() async {
    if (_player != null) {
      final p = _player;
      _player = null;
      try {
        await p?.pause();
      } catch (_) {}
      // Delay disposal by 500ms to allow Flutter's unmount and surface resize to finish safely
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await p?.dispose();
        } catch (e) {
          // Ignore async disposal errors
        }
      });
    }
  }

  @override
  Future<void> open(String path) async {
    await player.open(Media(path), play: true);
  }

  @override
  Future<void> play() async {
    await player.play();
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  @override
  Future<void> setRate(double rate) async {
    await player.setRate(rate);
  }

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<double> get rateStream => player.stream.rate;

  @override
  bool get isPlaying => player.state.playing;

  @override
  Duration get position => player.state.position;

  @override
  double get rate => player.state.rate;

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await player.setSubtitleTrack(track);
  }

  @override
  Stream<Track> get trackStream => player.stream.track;

  @override
  Stream<Tracks> get tracksStream => player.stream.tracks;

  @override
  Track get track => player.state.track;

  @override
  Tracks get tracks => player.state.tracks;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  bool get isBuffering => player.state.buffering;
}
