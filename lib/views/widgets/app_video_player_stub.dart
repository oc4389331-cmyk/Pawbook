import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';

class AppVideoPlayerWeb extends StatefulWidget {
  final String videoUrl;
  final bool isCurrentPage;
  final bool isMuted;
  final bool loop;
  final BoxFit fit;
  final Future<bool> Function()? onPlayAttempt;
  final VoidCallback? onVideoTap;

  const AppVideoPlayerWeb({
    super.key,
    required this.videoUrl,
    this.isCurrentPage = true,
    this.isMuted = false,
    this.loop = true,
    this.fit = BoxFit.contain,
    this.onPlayAttempt,
    this.onVideoTap,
  });

  @override
  State<AppVideoPlayerWeb> createState() => _AppVideoPlayerNativeState();
}

class _AppVideoPlayerNativeState extends State<AppVideoPlayerWeb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showOverlay = false;
  Timer? _overlayTimer;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _initPlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isCurrentPage && _controller != null && _isInitialized) {
        _controller?.play();
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initPlayer() async {
    final url = widget.videoUrl.trim();
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

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.addListener(_onControllerUpdate);
      await controller.setLooping(widget.loop);
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      if (widget.isCurrentPage) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error initializing native video player for $url: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayerWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl != oldWidget.videoUrl) {
      _controller?.removeListener(_onControllerUpdate);
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initPlayer();
      return;
    }

    if (_controller != null && _isInitialized) {
      if (widget.isCurrentPage != oldWidget.isCurrentPage) {
        if (widget.isCurrentPage) {
          _controller?.play();
        } else {
          _controller?.pause();
        }
      }

      if (widget.isMuted != oldWidget.isMuted) {
        _controller?.setVolume(widget.isMuted ? 0.0 : 1.0);
      }
    }
  }

  void _togglePlayPause() async {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      await _controller!.pause();
      _triggerOverlay();
    } else {
      await _controller!.play();
      _triggerOverlay();
    }

    if (widget.onVideoTap != null) {
      widget.onVideoTap!();
    }

    if (mounted) setState(() {});
  }

  void _triggerOverlay() {
    _overlayTimer?.cancel();
    if (mounted) {
      setState(() => _showOverlay = true);
      _animController.forward(from: 0.0);
      _overlayTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showOverlay = false);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayTimer?.cancel();
    _animController.dispose();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
            SizedBox(height: 8),
            Text('No se pudo reproducir el video', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandCoral),
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Native Video View
          Center(
            child: widget.fit == BoxFit.cover
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                        height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 16 / 9,
                    child: VideoPlayer(_controller!),
                  ),
          ),

          // Buffering Indicator
          if (_controller!.value.isBuffering)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandCoral),
                ),
              ),
            ),

          // Play / Pause Animation Overlay
          if (_showOverlay)
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: Icon(
                    isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
