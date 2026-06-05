import 'dart:convert'; // 用于 Base64 编码
import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 初始化 Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const MainPage(),
    );
  }
}

//  MainPage
class MainPage extends StatelessWidget {
  const MainPage({super.key});

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
                MaterialPageRoute(builder: (context) => const UploadPage()),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Sound').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Upload file to create'));
          }
  
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return AudioPlayerCard(
                name: data['name'] ?? 'Unknown',
                audioData: data['url'] ?? '', 
              );
            },
          );
        },
      ),
    );
  }
}

class AudioPlayerCard extends StatefulWidget {
  final String name;
  final String audioData; 

  const AudioPlayerCard({super.key, required this.name, required this.audioData});

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose(); 
    super.dispose();
  }

  void _togglePlay() async {
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      if (widget.audioData.isNotEmpty) {
        try {

          if (!widget.audioData.startsWith('http') && !widget.audioData.startsWith('https')) {

            Uint8List audioBytes = base64Decode(widget.audioData);
            await _audioPlayer.play(BytesSource(audioBytes));
          } else {

            await _audioPlayer.play(UrlSource(widget.audioData));
          }
          setState(() => isPlaying = true);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('播放失败: $e')));
        }
      }
    }

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => isPlaying = false);
    });
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
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Click to play'),
        trailing: IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
          iconSize: 36,
          color: Colors.deepPurple,
          onPressed: _togglePlay,
        ),
      ),
    );
  }
}

// Upload Page
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController(); 
  
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio, 
        withData: true,      
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFileBytes = result.files.single.bytes;
          _selectedFileName = result.files.single.name;
          _urlController.clear(); 
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
    }
  }

  Future<void> _uploadAndSave() async {
    final name = _nameController.text.trim();
    final manualUrl = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String finalAudioData = '';
      if (_selectedFileBytes != null) {
        finalAudioData = base64Encode(_selectedFileBytes!);
      }

      await FirebaseFirestore.instance.collection('Sound').add({
        'name': name,
        'url': finalAudioData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Success')));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload to Firestore')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Sound Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              // 选项一：直接选本地音频转成 Base64
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickFile,
                icon: const Icon(Icons.audio_file),
                label: Text(_selectedFileName == null ? 'Select Local File (Max 1MB)' : 'Selected: $_selectedFileName'),
              ),
              
              const SizedBox(height: 20),
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _uploadAndSave,
                      child: const Text('Upload'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}