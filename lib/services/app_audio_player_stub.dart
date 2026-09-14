import 'dart:async';
import 'app_audio_player.dart';

AppAudioPlayer createAppAudioPlayer() => AppAudioPlayerStub();

class AppAudioPlayerStub implements AppAudioPlayer {
  final _stateController = StreamController<bool>.broadcast();
  final _completeController = StreamController<void>.broadcast();

  @override
  Stream<bool> get onPlayingChanged => _stateController.stream;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String url, {bool loop = false, double volume = 1.0}) async {
    _stateController.add(true);
  }

  @override
  Future<void> pause() async {
    _stateController.add(false);
  }

  @override
  Future<void> stop() async {
    _stateController.add(false);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLoop(bool loop) async {}

  @override
  void dispose() {
    _stateController.close();
    _completeController.close();
  }
}
