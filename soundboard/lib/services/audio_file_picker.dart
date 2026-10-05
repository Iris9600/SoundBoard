import 'package:file_picker/file_picker.dart';
import '../models/selected_audio_file.dart';

class AudioFilePicker {
  Future<SelectedAudioFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    final file = result.files.single;
    return SelectedAudioFile(name: file.name, bytes: file.bytes!);
  }
}
