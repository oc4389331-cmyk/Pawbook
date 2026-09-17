import 'dart:async';
import 'dart:html' as html;
import 'app_audio_player.dart';

AppAudioPlayer createAppAudioPlayer() => AppAudioPlayerWeb();

class AppAudioPlayerWeb implements AppAudioPlayer {
  html.AudioElement? _audio;
  final _stateController = StreamController<bool>.broadcast();
  final _completeController = StreamController<void>.broadcast();
  StreamSubscription? _gestureSub;
  String? _pendingUrl;
  bool _pendingLoop = false;
  double _pendingVolume = 1.0;

  void _ensureAudio() {
    if (_audio == null) {
      _audio = html.AudioElement();
      _audio!.preload = 'auto';
      _audio!.onPlay.listen((_) => _stateController.add(true));
      _audio!.onPause.listen((_) => _stateController.add(false));
      _audio!.onEnded.listen((_) {
        _stateController.add(false);
        _completeController.add(null);
      });
      _audio!.onError.listen((e) {
        _stateController.add(false);
      });
    }
  }

  void _setupGestureUnlock() {
    _gestureSub?.cancel();
    _gestureSub = html.window.onClick.listen((_) => _handleUserGesture());
  }

  void _handleUserGesture() {
    _gestureSub?.cancel();
    _gestureSub = null;
    if (_pendingUrl != null && _audio != null) {
      final url = _pendingUrl!;
      final loop = _pendingLoop;
      final vol = _pendingVolume;
      _pendingUrl = null;
      play(url, loop: loop, volume: vol);
    }
  }

  String? _currentLoadedUrl;

  @override
  Stream<bool> get onPlayingChanged => _stateController.stream;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String url, {bool loop = false, double volume = 1.0}) async {
    try {
      _ensureAudio();
      _pendingUrl = url;
      _pendingLoop = loop;
      _pendingVolume = volume;

      final normalizedUrl = url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:')
          ? url
          : (url.startsWith('/') ? url : '/$url');

      if (_currentLoadedUrl != normalizedUrl) {
        _currentLoadedUrl = normalizedUrl;
        _audio!.src = normalizedUrl;
        _audio!.load();
      }
      _audio!.loop = loop;
      _audio!.volume = volume.clamp(0.0, 1.0);

      final playPromise = _audio!.play();
      if (playPromise != null) {
        await playPromise.catchError((err) {
          // Browser Autoplay blocked: wait for first user gesture
          _setupGestureUnlock();
        });
      }
    } catch (_) {
      _setupGestureUnlock();
    }
  }

  @override
  Future<void> pause() async {
    try {
      _pendingUrl = null;
      _gestureSub?.cancel();
      _gestureSub = null;
      _audio?.pause();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      _pendingUrl = null;
      _gestureSub?.cancel();
      _gestureSub = null;
      if (_audio != null) {
        _audio!.pause();
        _audio!.currentTime = 0;
      }
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _audio?.volume = volume.clamp(0.0, 1.0);
    } catch (_) {}
  }

  @override
  Future<void> setLoop(bool loop) async {
    try {
      _audio?.loop = loop;
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _pendingUrl = null;
      _gestureSub?.cancel();
      _gestureSub = null;
      _audio?.pause();
      _audio?.src = '';
      _audio = null;
      _stateController.close();
      _completeController.close();
    } catch (_) {}
  }
}
