import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web Video Precache Service (Flutter Web).
/// Preloads video initial chunks using browser HTTP Cache and HTML5 Video Preload.
class VideoCachePlatform {
  static final VideoCachePlatform instance = VideoCachePlatform._internal();

  VideoCachePlatform._internal();

  final Set<String> _preloadedUrls = {};
  final List<html.VideoElement> _activePreloadPool = [];

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
      if (_preloadedUrls.length > 20) {
        _preloadedUrls.remove(_preloadedUrls.first);
      }

      // Create an off-screen HTML5 video element attached to the document so the browser network scheduler allocates bandwidth to preload
      final preloadVideo = html.VideoElement()
        ..src = cleanUrl
        ..preload = 'auto'
        ..muted = true
        ..style.position = 'fixed'
        ..style.left = '-9999px'
        ..style.top = '-9999px'
        ..style.width = '1px'
        ..style.height = '1px'
        ..style.opacity = '0'
        ..style.pointerEvents = 'none';

      html.document.body?.append(preloadVideo);
      preloadVideo.load();

      // Keep in pool so garbage collection doesn't abort HTTP download
      _activePreloadPool.add(preloadVideo);
      if (_activePreloadPool.length > 6) {
        final oldest = _activePreloadPool.removeAt(0);
        oldest.remove();
      }

      preloadVideo.onCanPlay.first.then((_) {
        debugPrint('[VideoCacheWeb] ⚡ Browser canplay reached for: $cleanUrl');
      }).catchError((_) {});

      debugPrint('[VideoCacheWeb] ⚡ Browser precaching chunk for: $cleanUrl');
    } catch (e) {
      debugPrint('[VideoCacheWeb] Precache error (non-critical): $e');
    }
  }

  Future<void> clearCache() async {
    _preloadedUrls.clear();
    for (final el in _activePreloadPool) {
      el.remove();
    }
    _activePreloadPool.clear();
  }
}
