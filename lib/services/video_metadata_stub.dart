import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'video_metadata_service.dart';

VideoMetadataService getVideoMetadataService() => VideoMetadataStub();

class VideoMetadataStub implements VideoMetadataService {
  @override
  Future<VideoInfo> extractMetadata(Uint8List bytes) async {
    return const VideoInfo(
      width: 1080,
      height: 1920,
      durationSeconds: 15.0,
    );
  }

  @override
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
  }) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70),
      ),
    );
  }
}
