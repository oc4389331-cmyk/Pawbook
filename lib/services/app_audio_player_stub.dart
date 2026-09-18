import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'app_audio_player.dart';

AppAudioPlayer createAppAudioPlayer() => AppAudioPlayerNative();

class AppAudioPlayerNative implements AppAudioPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _stateController = StreamController<bool>.broadcast();
  final _completeController = StreamController<void>.broadcast();
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  AppAudioPlayerNative() {
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      final isPlaying = state == PlayerState.playing;
      _stateController.add(isPlaying);
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      _completeController.add(null);
    });
  }

  @override
  Stream<bool> get onPlayingChanged => _stateController.stream;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String url, {bool loop = false, double volume = 1.0}) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    try {
      await _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.play(UrlSource(cleanUrl));
    } catch (e) {
      debugPrint('[AppAudioPlayerNative] Play error for $cleanUrl: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('[AppAudioPlayerNative] Pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('[AppAudioPlayerNative] Stop error: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> setLoop(bool loop) async {
    try {
      await _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _completeSub?.cancel();
    _stateController.close();
    _completeController.close();
    _audioPlayer.dispose();
  }
}
