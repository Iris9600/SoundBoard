import 'package:flutter/material.dart';
import '../services/audio_playback_controller.dart';

class AudioPlayerCard extends StatefulWidget {
  final String name;
  final String audioData;

  const AudioPlayerCard({
    super.key,
    required this.name,
    required this.audioData,
  });

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final AudioPlaybackController _playback = AudioPlaybackController();

  @override
  void initState() {
    super.initState();
    _playback.addListener(_onPlaybackChanged);
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  bool get isPlaying => _playback.isPlaying;

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    _playback.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      await _playback.toggle(widget.audioData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          isPlaying ? Icons.volume_up : Icons.volume_mute,
          color: Colors.deepPurple,
        ),
        title: Text(
          widget.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Click to play'),
        trailing: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
          ),
          iconSize: 36,
          color: Colors.deepPurple,
          onPressed: _togglePlay,
        ),
      ),
    );
  }
}
