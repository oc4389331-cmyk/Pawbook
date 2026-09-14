import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'video_metadata_stub.dart'
    if (dart.library.html) 'video_metadata_web.dart';

class VideoInfo {
  final int width;
  final int height;
  final double durationSeconds;
  final String? objectUrl;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.durationSeconds,
    this.objectUrl,
  });

  bool get isLandscape => width > height;
  bool get isPortrait => height > width;
  bool get isSquare => width == height && width > 0;
  double get aspectRatio => (height > 0 && width > 0) ? width / height : 9 / 16;
  String get dimensionLabel => '${width > 0 ? width : 1080} × ${height > 0 ? height : 1920} px (${isLandscape ? "16:9" : isSquare ? "1:1" : "9:16"})';
  String get formatName => isLandscape ? '🖥️ Horizontal (16:9)' : isSquare ? '⏹️ Cuadrado (1:1)' : '📱 Vertical (9:16)';
}

abstract class VideoMetadataService {
  static final VideoMetadataService instance = getVideoMetadataService();

  Future<VideoInfo> extractMetadata(Uint8List bytes);
  Widget buildVideoPlayerView({
    required Uint8List bytes,
    required String viewKey,
    String? objectUrl,
    bool autoPlay = true,
    bool loop = true,
    bool muted = false,
    double volume = 1.0,
    BoxFit fit = BoxFit.contain,
    List<double>? colorMatrix,
  });
}
