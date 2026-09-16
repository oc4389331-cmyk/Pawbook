import 'package:flutter/material.dart';

class AppVideoPlayerWeb extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded, size: 54, color: Colors.white70),
      ),
    );
  }
}
