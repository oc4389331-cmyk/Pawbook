import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Native (Android / iOS / macOS / Windows) video thumbnail player.
class VideoThumbnailPlayerPlatform extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;

  const VideoThumbnailPlayerPlatform({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailPlayerPlatform> createState() => _VideoThumbnailPlayerPlatformNativeState();
}

class _VideoThumbnailPlayerPlatformNativeState extends State<VideoThumbnailPlayerPlatform> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initNativeVideo();
  }

  Future<void> _initNativeVideo() async {
    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) return;

    try {
      final uri = Uri.parse(cleanUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 6));
      await controller.setVolume(0.0);
      await controller.pause();
      if (controller.value.duration > Duration.zero) {
        await controller.seekTo(const Duration(milliseconds: 150));
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('[VideoThumbnailNative] Error buffering thumbnail: $e');
    }
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailPlayerPlatform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _initNativeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null && _controller!.value.isInitialized) {
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
    return const SizedBox.shrink();
  }
}
