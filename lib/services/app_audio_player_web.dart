import 'dart:async';
import 'dart:html' as html;
import 'app_audio_player.dart';

AppAudioPlayer createAppAudioPlayer() => AppAudioPlayerWeb();

class AppAudioPlayerWeb implements AppAudioPlayer {
  html.AudioElement? _audio;
  final _stateController = StreamController<bool>.broadcast();
  final _completeController = StreamController<void>.broadcast();

  void _ensureAudio() {
    if (_audio == null) {
      _audio = html.AudioElement();
      _audio!.onPlay.listen((_) => _stateController.add(true));
      _audio!.onPause.listen((_) => _stateController.add(false));
      _audio!.onEnded.listen((_) {
        _stateController.add(false);
        _completeController.add(null);
      });
      _audio!.onError.listen((_) => _stateController.add(false));
    }
  }

  @override
  Stream<bool> get onPlayingChanged => _stateController.stream;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String url, {bool loop = false, double volume = 1.0}) async {
    try {
      _ensureAudio();
      _audio!.src = url;
      _audio!.loop = loop;
      _audio!.volume = volume.clamp(0.0, 1.0);
      await _audio!.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      _audio?.pause();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
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
      _audio?.pause();
      _audio?.src = '';
      _audio = null;
      _stateController.close();
      _completeController.close();
    } catch (_) {}
  }
}
