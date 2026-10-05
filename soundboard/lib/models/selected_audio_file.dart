import 'dart:typed_data';

/// The name and bytes returned by the audio file picker.
class SelectedAudioFile {
  final String name;
  final Uint8List bytes;

  const SelectedAudioFile({required this.name, required this.bytes});
}
