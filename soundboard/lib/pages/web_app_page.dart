import 'package:flutter/material.dart';
import '../models/sound.dart';
import '../services/sound_repository.dart';
import '../widgets/audio_player_card.dart';
import 'upload_page.dart';

/// Browser workspace; mobile installations retain MainPage.
class WebAppPage extends StatefulWidget {
  final String userName;
  final Stream<List<Sound>>? sounds;
  final VoidCallback? onSwitchName;

  const WebAppPage({
    super.key,
    required this.userName,
    this.sounds,
    this.onSwitchName,
  });

  @override
  State<WebAppPage> createState() => _WebAppPageState();
}

class _WebAppPageState extends State<WebAppPage> {
  late final Stream<List<Sound>> _sounds =
      widget.sounds ?? SoundRepository(userName: widget.userName).watchSounds();
  String _query = '';

  void _upload() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UploadPage(userName: widget.userName),
      ),
    );
  }

  void _details() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your library'),
        content: SelectableText(
          '${widget.userName}\n\n'
          'Use this name on another device to open the same sounds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FA),
      appBar: AppBar(
        title: const Text('SoundBoard · Web App'),
        actions: [
          if (widget.onSwitchName != null)
            IconButton(
              tooltip: 'Switch name',
              onPressed: widget.onSwitchName,
              icon: const Icon(Icons.logout),
            ),
          IconButton(
            tooltip: 'Library details',
            onPressed: _details,
            icon: const Icon(Icons.devices),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (wide)
                SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.graphic_eq,
                          size: 40,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your workspace',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        const ListTile(
                          leading: Icon(Icons.library_music),
                          title: Text('Sound library'),
                          selected: true,
                        ),
                        const Spacer(),
                        Text(widget.userName),
                        const SizedBox(height: 8),
                        const Text(
                          'Your sounds, ready to play in your browser.',
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 32 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sound library',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload a sound, then press play to hear it.',
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: wide ? 360 : constraints.maxWidth - 32,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search sounds',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (value) => setState(
                                    () => _query = value.trim().toLowerCase(),
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _upload,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload sound'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: StreamBuilder<List<Sound>>(
                              stream: _sounds,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      'Unable to load sounds. Check your connection and Firebase access.',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final sounds = snapshot.data!
                                    .where(
                                      (sound) => sound.name
                                          .toLowerCase()
                                          .contains(_query),
                                    )
                                    .toList();
                                if (sounds.isEmpty) {
                                  return Center(
                                    child: Text(
                                      _query.isEmpty
                                          ? 'Your library is empty. Upload your first sound.'
                                          : 'No sounds match your search.',
                                    ),
                                  );
                                }
                                return LayoutBuilder(
                                  builder: (context, grid) {
                                    return GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: grid.maxWidth >= 650
                                                ? 2
                                                : 1,
                                            mainAxisExtent: 112,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                          ),
                                      itemCount: sounds.length,
                                      itemBuilder: (context, index) =>
                                          AudioPlayerCard(
                                            key: ValueKey(sounds[index].id),
                                            name: sounds[index].name,
                                            audioData: sounds[index].audioData,
                                          ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
