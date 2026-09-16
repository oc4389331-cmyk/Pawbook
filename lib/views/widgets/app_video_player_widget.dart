import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_video_player_stub.dart'
    if (dart.library.html) 'app_video_player_web.dart';

class AppVideoPlayerWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return AppVideoPlayerWeb(
        videoUrl: videoUrl,
        isCurrentPage: isCurrentPage,
        isMuted: isMuted,
        loop: loop,
        fit: fit,
        onPlayAttempt: onPlayAttempt,
        onVideoTap: onVideoTap,
      );
    }

    return AppVideoPlayerWeb(
      videoUrl: videoUrl,
      isCurrentPage: isCurrentPage,
      isMuted: isMuted,
      loop: loop,
      fit: fit,
      onPlayAttempt: onPlayAttempt,
      onVideoTap: onVideoTap,
    );
  }
}
