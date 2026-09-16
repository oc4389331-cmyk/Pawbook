import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';

class AppVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isCurrentPage;
  final bool isMuted;
  final bool loop;
  final BoxFit fit;
  final Future<bool> Function()? onPlayAttempt;
  final VoidCallback? onVideoTap;

  const AppVideoPlayerWidget({
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
  State<AppVideoPlayerWidget> createState() => _AppVideoPlayerWidgetState();
}

class _AppVideoPlayerWidgetState extends State<AppVideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPlayPauseOverlay = false;
  bool _isPlaying = false;
  Timer? _overlayTimer;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl.trim().isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final uri = Uri.parse(widget.videoUrl);
      _controller = VideoPlayerController.networkUrl(uri);

      await _controller!.initialize();
      await _controller!.setLooping(widget.loop);
      await _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      if (widget.isCurrentPage) {
        if (widget.onPlayAttempt != null) {
          final canPlay = await widget.onPlayAttempt!();
          if (canPlay && mounted && _controller != null) {
            await _controller!.play();
            setState(() => _isPlaying = true);
          }
        } else {
          await _controller!.play();
          setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint('[AppVideoPlayerWidget] Error initializing video (${widget.videoUrl}): $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initPlayer();
      return;
    }

    if (_controller != null && _isInitialized) {
      // Mute / Unmute
      if (oldWidget.isMuted != widget.isMuted) {
        _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      }

      // Page focus changed
      if (oldWidget.isCurrentPage != widget.isCurrentPage) {
        if (widget.isCurrentPage) {
          _handlePageBecameActive();
        } else {
          _controller!.pause();
          setState(() => _isPlaying = false);
        }
      }
    }
  }

  Future<void> _handlePageBecameActive() async {
    if (_controller == null || !_isInitialized) return;
    if (widget.onPlayAttempt != null) {
      final canPlay = await widget.onPlayAttempt!();
      if (!canPlay || !mounted) return;
    }
    await _controller!.play();
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _togglePlayPause() async {
    if (widget.onVideoTap != null) {
      widget.onVideoTap!();
    }

    if (widget.onPlayAttempt != null && !_isPlaying) {
      final canPlay = await widget.onPlayAttempt!();
      if (!canPlay) return;
    }

    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      await _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      await _controller!.play();
      setState(() => _isPlaying = true);
    }

    _triggerOverlayAnimation();
  }

  void _triggerOverlayAnimation() {
    _overlayTimer?.cancel();
    _animController.forward(from: 0.0);
    setState(() => _showPlayPauseOverlay = true);

    _overlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showPlayPauseOverlay = false);
      }
    });
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _animController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (!_isInitialized || _controller == null) {
      return _buildLoadingState();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // The Video Frame
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : (9 / 16),
              child: VideoPlayer(_controller!),
            ),
          ),

          // Animated Play / Pause Icon overlay
          if (_showPlayPauseOverlay || !_isPlaying)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showPlayPauseOverlay || !_isPlaying ? 1.0 : 0.0,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Video Progress Bar at Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppTheme.accentOrange,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryTerracotta,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Cargando video de mascota 🐾',
              style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF121214),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets_rounded, size: 48, color: AppTheme.primaryTerracotta),
            ),
            const SizedBox(height: 14),
            Text(
              'Video Pawtbook',
              style: GoogleFonts.fredoka(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Cloudflare R2 Media Player 🐾',
              style: GoogleFonts.outfit(color: AppTheme.textMutedWarm, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceWarm,
                foregroundColor: AppTheme.primaryTerracotta,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initPlayer();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Reintentar', style: GoogleFonts.fredoka(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
