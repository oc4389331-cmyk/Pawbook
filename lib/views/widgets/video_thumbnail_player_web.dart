import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Lightweight HTML5 video thumbnail player for Flutter Web.
/// Extracts and displays the first frame (#t=0.1) without heavy VideoPlayerController
/// overhead, preventing browser decoder exhaustion and timeout errors in grids.
class VideoThumbnailPlayerPlatform extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;

  const VideoThumbnailPlayerPlatform({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailPlayerPlatform> createState() => _VideoThumbnailPlayerPlatformWebState();
}

class _VideoThumbnailPlayerPlatformWebState extends State<VideoThumbnailPlayerPlatform> {
  late String _viewType;
  html.VideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _initWebVideo();
  }

  void _initWebVideo() {
    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) return;

    _viewType = 'paw_thumb_${cleanUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';

    // The #t=0.1 fragment instructs browsers to seek to 0.1s for the poster frame
    final urlWithTime = cleanUrl.contains('#') ? cleanUrl : '$cleanUrl#t=0.1';

    final video = html.VideoElement()
      ..src = urlWithTime
      ..preload = 'metadata'
      ..muted = true
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain'
      ..style.backgroundColor = 'transparent'
      ..style.pointerEvents = 'none'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    // Ensure first frame is displayed once metadata is available
    video.onLoadedMetadata.listen((_) {
      try {
        if (video.currentTime == 0) {
          video.currentTime = 0.1;
        }
      } catch (_) {}
    });

    _videoElement = video;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return video;
    });
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailPlayerPlatform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      final cleanUrl = widget.videoUrl.trim();
      final urlWithTime = cleanUrl.contains('#') ? cleanUrl : '$cleanUrl#t=0.1';
      _videoElement?.src = urlWithTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return HtmlElementView(viewType: _viewType);
  }
}
