import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'video_metadata_service.dart';

VideoMetadataService getVideoMetadataService() => VideoMetadataStub();

class VideoMetadataStub implements VideoMetadataService {
  @override
  Future<VideoInfo> extractMetadata(Uint8List bytes) async {
    File? tempFile;
    try {
      final tempDir = Directory.systemTemp;
      final filename = 'pawt_meta_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.mp4';
      tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes, flush: true);

      return await extractMetadataFromPath(tempFile.path);
    } catch (e) {
      debugPrint('[VideoMetadataStub] Error extracting metadata from bytes: $e');
      return const VideoInfo(
        width: 1080,
        height: 1920,
        durationSeconds: 15.0,
      );
    } finally {
      if (tempFile != null && tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<VideoInfo> extractMetadataFromPath(String path) async {
    VideoPlayerController? controller;
    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception('File does not exist: $path');
      }

      controller = VideoPlayerController.file(file);
      await controller.initialize().timeout(const Duration(seconds: 12));

      final durationSeconds = controller.value.duration.inMilliseconds / 1000.0;
      final size = controller.value.size;
      final width = size.width.toInt();
      final height = size.height.toInt();

      return VideoInfo(
        width: width > 0 ? width : 1080,
        height: height > 0 ? height : 1920,
        durationSeconds: durationSeconds > 0 ? durationSeconds : 15.0,
      );
    } catch (e) {
      debugPrint('[VideoMetadataStub] Error extracting metadata from path $path: $e');
      return const VideoInfo(
        width: 1080,
        height: 1920,
        durationSeconds: 15.0,
      );
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
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
    return _NativeVideoPreviewWidget(
      key: ValueKey(viewKey),
      bytes: bytes,
      autoPlay: autoPlay,
      loop: loop,
      muted: muted,
      volume: volume,
      fit: fit,
      colorMatrix: colorMatrix,
    );
  }
}

class _NativeVideoPreviewWidget extends StatefulWidget {
  final Uint8List bytes;
  final bool autoPlay;
  final bool loop;
  final bool muted;
  final double volume;
  final BoxFit fit;
  final List<double>? colorMatrix;

  const _NativeVideoPreviewWidget({
    super.key,
    required this.bytes,
    required this.autoPlay,
    required this.loop,
    required this.muted,
    required this.volume,
    required this.fit,
    this.colorMatrix,
  });

  @override
  State<_NativeVideoPreviewWidget> createState() => _NativeVideoPreviewWidgetState();
}

class _NativeVideoPreviewWidgetState extends State<_NativeVideoPreviewWidget> {
  VideoPlayerController? _controller;
  File? _tempFile;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initNativeVideo();
  }

  Future<void> _initNativeVideo() async {
    try {
      final tempDir = Directory.systemTemp;
      _tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}_${widget.bytes.length}.mp4');
      await _tempFile!.writeAsBytes(widget.bytes, flush: true);

      _controller = VideoPlayerController.file(_tempFile!);
      await _controller!.initialize();
      await _controller!.setLooping(widget.loop);
      await _controller!.setVolume(widget.muted ? 0.0 : widget.volume);

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (e) {
      debugPrint('[NativeVideoPreview] Init error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _NativeVideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _isReady) {
      if (widget.muted != oldWidget.muted || widget.volume != oldWidget.volume) {
        _controller!.setVolume(widget.muted ? 0.0 : widget.volume);
      }
      if (widget.loop != oldWidget.loop) {
        _controller!.setLooping(widget.loop);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_tempFile != null && _tempFile!.existsSync()) {
      try {
        _tempFile!.delete();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    Widget player = Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );

    if (widget.colorMatrix != null) {
      player = ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.colorMatrix!),
        child: player,
      );
    }

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: player,
          ),
        ),
      ),
    );
  }
}
