import 'package:flutter/material.dart';
import '../models/selected_audio_file.dart';
import '../services/audio_file_picker.dart';
import '../services/sound_repository.dart';

class UploadPage extends StatefulWidget {
  final String deviceId;
  const UploadPage({super.key, required this.deviceId});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _nameController = TextEditingController();

  final AudioFilePicker _filePicker = AudioFilePicker();
  SelectedAudioFile? _selectedFile;

  String? get _selectedFileName => _selectedFile?.name;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await _filePicker.pick();

      if (file != null) {
        if (!mounted) return;
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
      }
    }
  }

  Future<void> _uploadAndSave() async {
    final name = _nameController.text.trim();
    if (_isUploading) return;

    final validationError = SoundRepository.validateUpload(name, _selectedFile);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _isUploading = true);

    try {
      await SoundRepository(
        deviceId: widget.deviceId,
      ).save(name: name, file: _selectedFile!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Success')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                label: Text(
                  _selectedFileName == null
                      ? 'Select Local File (Max 700 KB)'
                      : 'Selected: $_selectedFileName',
                ),
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
