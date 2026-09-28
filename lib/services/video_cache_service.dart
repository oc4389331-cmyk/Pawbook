import 'video_cache_service_stub.dart'
    if (dart.library.html) 'video_cache_service_web.dart';

/// Pawtbook Smart Video Precache & Buffer Service.
/// Preloads upcoming videos in the TikTok feed in the background so that
/// playback starts with zero latency (0ms) and provides offline playback resilience.
class VideoCacheService {
  static final VideoCacheService instance = VideoCacheService._internal();

  VideoCacheService._internal();

  final VideoCachePlatform _platform = VideoCachePlatform.instance;

  /// Returns the cached file (on native mobile) if available in disk cache.
  Future<dynamic> getCachedFile(String url) => _platform.getCachedFile(url);

  /// Preloads a video URL in the background.
  Future<void> precacheVideo(String url) => _platform.precacheVideo(url);

  /// Clears the video cache.
  Future<void> clearCache() => _platform.clearCache();
}
