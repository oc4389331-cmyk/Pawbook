import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web Video Precache Service (Flutter Web).
/// Preloads video initial chunks using browser HTTP Cache and HTML5 Video Preload.
class VideoCachePlatform {
  static final VideoCachePlatform instance = VideoCachePlatform._internal();

  VideoCachePlatform._internal();

  final Set<String> _preloadedUrls = {};

  Future<dynamic> getCachedFile(String url) async {
    // On web, video_player uses browser network caching directly
    return null;
  }

  /// Precaches the video into the browser's memory and disk cache.
  Future<void> precacheVideo(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || _preloadedUrls.contains(cleanUrl)) return;

    try {
      _preloadedUrls.add(cleanUrl);
      if (_preloadedUrls.length > 15) {
        _preloadedUrls.remove(_preloadedUrls.first);
      }

      // 1. Create a lightweight off-screen video element to trigger browser metadata and buffer download
      final preloadVideo = html.VideoElement()
        ..src = cleanUrl
        ..preload = 'auto'
        ..muted = true
        ..style.display = 'none';

      // Attach listener to clean up DOM references once buffer starts
      preloadVideo.onCanPlay.first.then((_) {
        preloadVideo.remove();
      }).catchError((_) {
        preloadVideo.remove();
      });

      debugPrint('[VideoCacheWeb] ⚡ Browser precached chunk for: $cleanUrl');
    } catch (e) {
      debugPrint('[VideoCacheWeb] Precache error (non-critical): $e');
    }
  }

  Future<void> clearCache() async {
    _preloadedUrls.clear();
  }
}
