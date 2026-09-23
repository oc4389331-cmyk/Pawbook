import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';

/// A high-performance thumbnail widget that renders either an image or the
/// first frame of a video URL (acting as a cover/poster) for profile grids,
/// search lists, and analytics dashboards.
class VideoThumbnailWidget extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fallbackImageUrl;
  final BoxFit fit;

  const VideoThumbnailWidget({
    super.key,
    required this.mediaUrl,
    this.mediaType = 'video',
    this.fallbackImageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  bool get _isVideo {
    if (widget.mediaType.toLowerCase() == 'video') return true;
    final path = Uri.tryParse(widget.mediaUrl)?.path.toLowerCase() ?? widget.mediaUrl.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.m4v') ||
        path.endsWith('.3gp');
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl || oldWidget.mediaType != widget.mediaType) {
      _disposeController();
      _isInitialized = false;
      _hasError = false;
      if (_isVideo) {
        _initVideo();
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _initVideo() async {
    final url = widget.mediaUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize().timeout(const Duration(seconds: 8));

      if (!mounted) {
        controller.dispose();
        return;
      }

      await controller.setVolume(0.0);
      await controller.pause();
      if (controller.value.duration > Duration.zero) {
        // Seek to the first frame or 100ms in case 0.0 is a black keyframe
        await controller.seekTo(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('[VideoThumbnailWidget] Error buffering video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Widget _buildPlaceholder() {
    if (widget.fallbackImageUrl != null && widget.fallbackImageUrl!.isNotEmpty) {
      return Image.network(
        widget.fallbackImageUrl!,
        fit: widget.fit,
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
    if (!_isVideo) {
      if (widget.mediaUrl.isEmpty) return _buildPlaceholder();
      return Image.network(
        widget.mediaUrl,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    if (!_hasError && _isInitialized && _controller != null && _controller!.value.isInitialized) {
      final size = _controller!.value.size;
      final width = size.width > 0 ? size.width : 16.0;
      final height = size.height > 0 ? size.height : 9.0;

      return SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    return _buildPlaceholder();
  }
}
