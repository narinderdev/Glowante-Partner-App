import 'package:audioplayers/audioplayers.dart';

class RefreshFeedback {
  RefreshFeedback._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/Fahhh.mp3'));
    } catch (_) {
      // Ignore audio failures during refresh.
    }
  }

  static Future<T> playAndRun<T>(Future<T> Function() action) async {
    await play();
    return action();
  }
}
