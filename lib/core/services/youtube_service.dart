import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  YoutubeExplode? _ytInstance;

  YoutubeExplode get _yt {
    _ytInstance ??= YoutubeExplode();
    return _ytInstance!;
  }

  /// Validates if the given string is a valid YouTube URL.
  bool isValidYouTubeUrl(String url) {
    if (url.isEmpty) return false;
    // Basic regex for YouTube URLs
    final RegExp regExp = RegExp(
      r'^(https?://)?(www\.)?(youtube\.com|youtu\.be)/(watch\?v=|embed/|v/|shorts/)?([a-zA-Z0-9_-]{11})',
    );
    return regExp.hasMatch(url);
  }

  /// Extracts the Video ID from a YouTube URL.
  String? getVideoId(String url) {
    try {
      return VideoId.parseVideoId(url);
    } catch (e) {
      return null;
    }
  }

  /// Gets the highest quality video stream URL for the given YouTube URL.
  Future<String?> getStreamUrl(String url) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) return null;

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // Get the muxed stream (video + audio) with highest resolution
      final streamInfo = manifest.muxed.withHighestBitrate();

      return streamInfo.url.toString();
    } catch (e) {
      print('Error getting YouTube stream URL: $e');
      return null;
    }
  }

  /// Gets video metadata (title, author, thumbnail) for the given YouTube URL.
  Future<Video?> getVideoMetadata(String url) async {
    try {
      final videoId = getVideoId(url);
      if (videoId == null) return null;

      return await _yt.videos.get(videoId);
    } catch (e) {
      print('Error getting YouTube video metadata: $e');
      return null;
    }
  }

  /// Searches for videos based on the given query.
  Future<List<Video>> searchVideos(String query) async {
    try {
      if (query.isEmpty) return [];
      final searchList = await _yt.search.search(query);

      // We only return the videos (ignoring playlists/channels for now)
      return searchList.whereType<Video>().toList();
    } catch (e) {
      print('Error searching YouTube videos: $e');
      return [];
    }
  }

  void dispose() {
    _ytInstance?.close();
    _ytInstance = null;
  }
}
