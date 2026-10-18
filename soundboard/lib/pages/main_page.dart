import 'package:flutter/material.dart';
import '../models/sound.dart';
import '../services/sound_repository.dart';
import '../widgets/audio_player_card.dart';
import 'upload_page.dart';

class MainPage extends StatelessWidget {
  final String userName;
  final VoidCallback? onSwitchName;
  const MainPage({super.key, required this.userName, this.onSwitchName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sound Board · $userName'),
        backgroundColor: Colors.blueGrey,
        actions: [
          if (onSwitchName != null)
            IconButton(
              tooltip: 'Switch name',
              onPressed: onSwitchName,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'Library details',
            icon: const Icon(Icons.devices),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Your library'),
                content: SelectableText(
                  '$userName\n\nUse this name on another device to open the same sounds.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadPage(userName: userName),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Sound>>(
        stream: SoundRepository(userName: userName).watchSounds(),
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
