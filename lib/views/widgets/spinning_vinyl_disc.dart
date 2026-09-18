import 'package:flutter/material.dart';

class SpinningVinylDisc extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final String? albumArtUrl;

  const SpinningVinylDisc({
    super.key,
    this.isPlaying = true,
    this.size = 32.0,
    this.albumArtUrl,
  });

  @override
  State<SpinningVinylDisc> createState() => _SpinningVinylDiscState();
}

class _SpinningVinylDiscState extends State<SpinningVinylDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpinningVinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFF1E1E24),
              Color(0xFF0F0F12),
              Color(0xFF2B2B36),
              Color(0xFF0A0A0C),
            ],
            stops: [0.2, 0.4, 0.7, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.42,
            height: widget.size * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B6B),
              image: widget.albumArtUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.albumArtUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
