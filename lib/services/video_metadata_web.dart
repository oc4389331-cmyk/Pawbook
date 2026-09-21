import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'video_metadata_service.dart';

VideoMetadataService getVideoMetadataService() => VideoMetadataWeb();

class VideoMetadataWeb implements VideoMetadataService {
  final Map<String, html.VideoElement> _registeredElements = {};
  final Set<String> _registeredFactories = {};

  @override
  Future<VideoInfo> extractMetadata(Uint8List bytes) async {
    try {
      final blob = html.Blob([bytes], 'video/mp4');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final video = html.VideoElement()
        ..src = url
        ..preload = 'metadata'
        ..muted = true;

      final completer = Completer<VideoInfo>();

      final sub = video.onLoadedMetadata.listen((_) {
        final w = video.videoWidth;
        final h = video.videoHeight;
        final dur = video.duration.toDouble();
        if (!completer.isCompleted) {
          completer.complete(VideoInfo(
            width: w > 0 ? w : 1080,
            height: h > 0 ? h : 1920,
            durationSeconds: dur.isFinite && dur > 0 ? dur : 15.0,
            objectUrl: url,
          ));
        }
      });

      video.onError.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(VideoInfo(
            width: 1080,
            height: 1920,
            durationSeconds: 15.0,
            objectUrl: url,
          ));
        }
      });

      // 2-second safety timeout
      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => VideoInfo(
          width: 1080,
          height: 1920,
          durationSeconds: 15.0,
          objectUrl: url,
        ),
      ).whenComplete(() => sub.cancel());
    } catch (_) {
      return const VideoInfo(
        width: 1080,
        height: 1920,
        durationSeconds: 15.0,
      );
    }
  }

  @override
  Future<VideoInfo> extractMetadataFromPath(String path) async {
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
    final effectiveUrl = objectUrl ?? html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'video/mp4'));

    if (!_registeredFactories.contains(viewKey)) {
      _registeredFactories.add(viewKey);
      ui_web.platformViewRegistry.registerViewFactory(viewKey, (int viewId) {
        final videoElement = html.VideoElement()
          ..src = effectiveUrl
          ..autoplay = autoPlay
          ..loop = loop
          ..muted = muted
          ..volume = volume
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain'
          ..style.backgroundColor = 'transparent'
          ..style.pointerEvents = 'none'
          ..style.border = 'none'
          ..style.outline = 'none'
          ..setAttribute('playsinline', 'true')
          ..setAttribute('webkit-playsinline', 'true');

        _registeredElements[viewKey] = videoElement;
        return videoElement;
      });
    } else {
      final el = _registeredElements[viewKey];
      if (el != null) {
        el.muted = muted;
        el.volume = volume;
        el.style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';
      }
    }

    return HtmlElementView(
      key: ValueKey(viewKey),
      viewType: viewKey,
    );
  }
}
