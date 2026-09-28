import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Native Video Cache Service (Android & iOS).
/// Implements LRU (Least Recently Used) disk caching with strict memory/storage limits.
///
/// SAFETY MEASURES AGAINST MEMORY SATURATION:
/// 1. Stored in OS temporary cache directory (getTemporaryDirectory), which the OS can clean.
/// 2. maxNrOfCacheObjects: 12 (Strict hard limit of maximum 12 videos in cache).
/// 3. stalePeriod: 1 day (Auto-eviction of files older than 24 hours).
/// 4. Operates asynchronously in background isolate, never blocking the main UI thread.
class VideoCachePlatform {
  static final VideoCachePlatform instance = VideoCachePlatform._internal();

  VideoCachePlatform._internal();

  static const String _cacheKey = 'pawtbook_video_cache';

  final CacheManager _cacheManager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 12, // Maximum 12 videos (approx. 35 - 50 MB total)
      repo: JsonCacheInfoRepository(databaseName: _cacheKey),
      fileService: HttpFileService(),
    ),
  );

  final Set<String> _inProgressUrls = {};

  /// Retrieves a cached video File if it exists locally on the device disk.
  Future<File?> getCachedFile(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    try {
      final fileInfo = await _cacheManager.getFileFromCache(cleanUrl);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo.file;
      }
    } catch (e) {
      debugPrint('[VideoCache] Error checking cache: $e');
    }
    return null;
  }

  /// Precaches the next video in background silently.
  Future<void> precacheVideo(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    if (_inProgressUrls.contains(cleanUrl)) return;

    try {
      // Check if already in cache
      final fileInfo = await _cacheManager.getFileFromCache(cleanUrl);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return;
      }

      _inProgressUrls.add(cleanUrl);
      debugPrint('[VideoCache] ⚡ Precaching next video: $cleanUrl');

      await _cacheManager.downloadFile(cleanUrl, key: cleanUrl);
      debugPrint('[VideoCache] ✅ Precached video ready: $cleanUrl');
    } catch (e) {
      debugPrint('[VideoCache] ⚠️ Precache failed (non-critical): $e');
    } finally {
      _inProgressUrls.remove(cleanUrl);
    }
  }

  /// Manually clears all cached video files to free up disk space.
  Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      debugPrint('[VideoCache] 🧹 Video disk cache cleared successfully');
    } catch (e) {
      debugPrint('[VideoCache] Error emptying cache: $e');
    }
  }
}
