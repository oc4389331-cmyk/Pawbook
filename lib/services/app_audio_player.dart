import 'dart:async';
import 'app_audio_player_stub.dart'
    if (dart.library.html) 'app_audio_player_web.dart';

abstract class AppAudioPlayer {
  factory AppAudioPlayer() => createAppAudioPlayer();

  Stream<bool> get onPlayingChanged;
  Stream<void> get onComplete;

  Future<void> play(String url, {bool loop = false, double volume = 1.0});
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> setLoop(bool loop);
  void dispose();
}
