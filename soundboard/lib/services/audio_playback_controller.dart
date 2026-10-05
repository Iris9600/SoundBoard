import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Owns the audio player, playback state, and completion subscription.
class AudioPlaybackController extends ChangeNotifier {
  final AudioPlayer _player;
  late final StreamSubscription<void> _completion;
  bool _isPlaying = false;
  bool _disposed = false;

  AudioPlaybackController({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _completion = _player.onPlayerComplete.listen((_) => _setPlaying(false));
  }

  bool get isPlaying => _isPlaying;

  Future<void> toggle(String audioData) async {
    if (_disposed) return;
    if (_isPlaying) {
      await _player.pause();
      _setPlaying(false);
    } else if (audioData.isNotEmpty) {
      final Source source = audioData.startsWith('http')
          ? UrlSource(audioData)
          : BytesSource(base64Decode(audioData));
      await _player.play(source);
      _setPlaying(true);
    }
  }

  void _setPlaying(bool value) {
    if (_disposed || _isPlaying == value) return;
    _isPlaying = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_completion.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
