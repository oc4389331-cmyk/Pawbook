import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  State<AppVideoPlayerWeb> createState() => _AppVideoPlayerWebState();
}

class _AppVideoPlayerWebState extends State<AppVideoPlayerWeb>
    with SingleTickerProviderStateMixin {
  html.VideoElement? _videoElement;
  late String _viewType;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _showOverlay = false;
  bool _isBuffering = true;
  Timer? _overlayTimer;
  StreamSubscription? _playSub;
  StreamSubscription? _pauseSub;
  StreamSubscription? _canPlaySub;
  StreamSubscription? _errorSub;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  static int _viewIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _viewType = 'pawtbook_video_${DateTime.now().millisecondsSinceEpoch}_${_viewIdCounter++}';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _createAndRegisterVideoElement();
  }

  void _createAndRegisterVideoElement() {
    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) return;

    final video = html.VideoElement()
      ..src = cleanUrl
      ..autoplay = widget.isCurrentPage
      ..loop = widget.loop
      ..muted = _isMuted
      ..preload = 'auto'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain'
      ..style.backgroundColor = 'transparent'
      ..style.pointerEvents = 'none'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    _canPlaySub = video.onCanPlay.listen((_) {
      if (mounted) {
        setState(() => _isBuffering = false);
        if (widget.isCurrentPage) {
          _safePlay(video);
        }
      }
    });

    _playSub = video.onPlay.listen((_) {
      if (mounted) setState(() => _isPlaying = true);
    });

    _pauseSub = video.onPause.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });

    _errorSub = video.onError.listen((e) {
      debugPrint('[AppVideoPlayerWeb] Video load note: $e (retrying with muted)');
      // If blocked by browser autoplay or audio codec, force mute and retry
      if (mounted && video.muted != true) {
        video.muted = true;
        _safePlay(video);
      }
    });

    _videoElement = video;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return video;
    });

    if (widget.isCurrentPage) {
      _safePlay(video);
    }
  }

  void _safePlay(html.VideoElement video) {
    video.play().catchError((err) {
      debugPrint('[AppVideoPlayerWeb] Autoplay policy caught, muting to allow autoplay: $err');
      video.muted = true;
      if (mounted) setState(() => _isMuted = true);
      video.play().catchError((e) => debugPrint('[AppVideoPlayerWeb] Secondary play error: $e'));
    });
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayerWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _videoElement?.src = widget.videoUrl;
      _videoElement?.load();
      if (widget.isCurrentPage) {
        _safePlay(_videoElement!);
      }
    }

    if (_videoElement != null) {
      if (oldWidget.isMuted != widget.isMuted) {
        _isMuted = widget.isMuted;
        _videoElement!.muted = _isMuted;
      }

      if (oldWidget.isCurrentPage != widget.isCurrentPage) {
        if (widget.isCurrentPage) {
          _handlePageActive();
        } else {
          _videoElement!.pause();
          if (mounted) setState(() => _isPlaying = false);
        }
      }
    }
  }

  Future<void> _handlePageActive() async {
    if (_videoElement == null) return;
    if (widget.onPlayAttempt != null) {
      final canPlay = await widget.onPlayAttempt!();
      if (!canPlay || !mounted) {
        _videoElement?.pause();
        return;
      }
    }
    _safePlay(_videoElement!);
  }

  Future<void> _togglePlayPause() async {
    if (widget.onVideoTap != null) {
      widget.onVideoTap!();
    }

    if (widget.onPlayAttempt != null && !_isPlaying) {
      final canPlay = await widget.onPlayAttempt!();
      if (!canPlay) return;
    }

    if (_videoElement == null) return;

    if (_videoElement!.paused) {
      _safePlay(_videoElement!);
    } else {
      _videoElement!.pause();
    }

    _triggerOverlay();
  }

  void _toggleMute() {
    if (_videoElement == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoElement!.muted = _isMuted;
    });
  }

  void _triggerOverlay() {
    _overlayTimer?.cancel();
    _animController.forward(from: 0.0);
    setState(() => _showOverlay = true);

    _overlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _playSub?.cancel();
    _pauseSub?.cancel();
    _canPlaySub?.cancel();
    _errorSub?.cancel();
    _animController.dispose();
    _videoElement?.pause();
    _videoElement?.src = '';
    _videoElement?.remove();
    _videoElement = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Native HTML5 Video Element View
          Container(
            color: Colors.black,
            child: HtmlElementView(
              key: ValueKey(_viewType),
              viewType: _viewType,
            ),
          ),

          // Buffering indicator
          if (_isBuffering)
            Container(
              color: Colors.black38,
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryTerracotta,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),

          // Play / Pause animated icon overlay
          if (_showOverlay || (!_isPlaying && !_isBuffering))
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showOverlay || !_isPlaying ? 1.0 : 0.0,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // Unmute / Mute quick toggle badge (top-right under headers)
          Positioned(
            top: 70,
            right: 68,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMuted ? 'Silenciado' : 'Sonido',
                      style: GoogleFonts.fredoka(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
