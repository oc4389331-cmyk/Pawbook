import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'video_thumbnail_player_stub.dart'
    if (dart.library.html) 'video_thumbnail_player_web.dart';

/// A high-performance thumbnail widget that renders either an image, a custom
/// cover image, or the initial frame of a video URL for profile grids, search lists,
/// and analytics cards.
class VideoThumbnailWidget extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;
  final String? customCoverUrl;
  final String? fallbackImageUrl;
  final BoxFit fit;

  const VideoThumbnailWidget({
    super.key,
    required this.mediaUrl,
    this.mediaType = 'video',
    this.customCoverUrl,
    this.fallbackImageUrl,
    this.fit = BoxFit.cover,
  });

  bool get _isVideo {
    if (mediaType.toLowerCase() == 'video') return true;
    final path = Uri.tryParse(mediaUrl)?.path.toLowerCase() ?? mediaUrl.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.m4v') ||
        path.endsWith('.3gp');
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E24),
            Color(0xFF2B2830),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white70,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    if (fallbackImageUrl != null && fallbackImageUrl!.isNotEmpty) {
      return Image.network(
        fallbackImageUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackPaw(),
      );
    }
    return _buildFallbackPaw();
  }

  Widget _buildFallbackPaw() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.pastelPeach.withValues(alpha: 0.6),
            AppTheme.pastelLavender.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.pets_rounded, color: AppTheme.primaryTerracotta, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. If an explicit custom cover was provided, render it directly
    final effectiveCover = (customCoverUrl != null && customCoverUrl!.isNotEmpty)
        ? customCoverUrl!
        : null;

    if (effectiveCover != null) {
      return Image.network(
        effectiveCover,
        fit: fit,
        errorBuilder: (_, __, ___) => _isVideo ? _buildVideoPlaceholder() : _buildImageFallback(),
      );
    }

    // 2. If it's a video, render initial frame via platform thumbnail player
    if (_isVideo) {
      if (mediaUrl.trim().isEmpty) return _buildVideoPlaceholder();

      return Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoPlaceholder(),
          VideoThumbnailPlayerPlatform(
            videoUrl: mediaUrl,
            fit: fit,
          ),
        ],
      );
    }

    // 3. For images, render network image
    if (mediaUrl.trim().isEmpty) return _buildImageFallback();

    return Image.network(
      mediaUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildImageFallback(),
    );
  }
}
