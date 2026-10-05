import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundboard/models/selected_audio_file.dart';
import 'package:soundboard/models/sound.dart';
import 'package:soundboard/services/sound_repository.dart';

void main() {
  SelectedAudioFile file(int size) =>
      SelectedAudioFile(name: 'sound.mp3', bytes: Uint8List(size));

  test('upload requires a name and nonempty audio', () {
    expect(
      SoundRepository.validateUpload('  ', file(1)),
      'Please enter a name',
    );
    expect(
      SoundRepository.validateUpload('Sound', null),
      'Please select an audio file',
    );
    expect(
      SoundRepository.validateUpload('Sound', file(0)),
      'Please select an audio file',
    );
  });

  test('upload accepts the size boundary and rejects larger files', () {
    expect(
      SoundRepository.validateUpload(
        'Sound',
        file(SoundRepository.maxAudioBytes),
      ),
      isNull,
    );
    expect(
      SoundRepository.validateUpload(
        'Sound',
        file(SoundRepository.maxAudioBytes + 1),
      ),
      'Please select a file smaller than 700 KB',
    );
  });

  test('sound reads existing Firestore fields and missing-field defaults', () {
    final sound = Sound.fromMap('one', {'name': 'Bell', 'url': 'encoded'});
    expect(sound.id, 'one');
    expect(sound.name, 'Bell');
    expect(sound.audioData, 'encoded');
    final empty = Sound.fromMap('two', {});
    expect(empty.name, 'Unknown');
    expect(empty.audioData, isEmpty);
  });
}
