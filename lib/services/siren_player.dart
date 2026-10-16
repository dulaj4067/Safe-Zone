import 'package:audioplayers/audioplayers.dart';

/// Plays the looping emergency siren while the critical-alert screen is up.
///
/// Behind an interface so widget tests (which have no audio device) can swap
/// in a fake, and so a device without audio output never breaks the screen.
abstract class SirenPlayer {
  Future<void> start();
  Future<void> setMuted(bool muted);
  Future<void> stop();
}

/// Loops `assets/sounds/siren.wav` on the alarm audio stream, so it follows
/// the alarm volume rather than the (often silenced) media volume.
class AudioSirenPlayer implements SirenPlayer {
  AudioPlayer? _player;

  @override
  Future<void> start() async {
    try {
      final player = AudioPlayer();
      _player = player;
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/siren.wav'));
    } catch (_) {
      // No audio output (or the plugin is missing): the screen, vibration
      // and notification still carry the warning.
      _player = null;
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    try {
      await _player?.setVolume(muted ? 0 : 1);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    final player = _player;
    _player = null;
    try {
      await player?.stop();
      await player?.dispose();
    } catch (_) {}
  }
}
