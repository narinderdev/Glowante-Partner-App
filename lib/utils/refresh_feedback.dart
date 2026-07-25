import 'dart:async';

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

  // For RefreshIndicator.onRefresh: don't await `action` directly, or the
  // native pull-to-refresh spinner stays on screen for the entire duration
  // of the real work, overlapping with the app's own "Loading...please
  // wait" overlay. Instead let the native spinner finish its own short
  // release/dismiss animation and disappear first, while `action` keeps
  // running in the background and drives that overlay itself.
  static Future<void> playAndDetach(Future<void> Function() action) async {
    await play();
    unawaited(action());
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // Some "refreshes" only re-read local storage (SharedPreferences, cached
  // session data) and finish in a few milliseconds — too fast for the big
  // loading overlay to ever actually be visible on screen, even though the
  // loading flag technically flips true then false. Call this right before
  // clearing that flag so every refresh looks and feels consistent,
  // regardless of how fast the underlying work actually was.
  static Future<void> ensureMinDuration(
    DateTime startedAt, {
    Duration min = const Duration(milliseconds: 500),
  }) async {
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < min) {
      await Future.delayed(min - elapsed);
    }
  }
}
