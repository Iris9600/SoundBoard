import 'package:flutter/material.dart';
import '../models/sound.dart';
import '../services/sound_repository.dart';
import '../widgets/audio_player_card.dart';
import 'upload_page.dart';

class MainPage extends StatelessWidget {
  final String deviceId;
  const MainPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Board'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadPage(deviceId: deviceId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Sound>>(
        stream: SoundRepository(deviceId: deviceId).watchSounds(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sounds = snapshot.data ?? [];

          if (sounds.isEmpty) {
            return const Center(child: Text('Upload file to create'));
          }

          return ListView.builder(
            itemCount: sounds.length,
            itemBuilder: (context, index) {
              final sound = sounds[index];
              return AudioPlayerCard(
                key: ValueKey(sound.id),
                name: sound.name,
                audioData: sound.audioData,
              );
            },
          );
        },
      ),
    );
  }
}
