import 'dart:typed_data';
import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundboard/models/selected_audio_file.dart';
import 'package:soundboard/models/sound.dart';
import 'package:soundboard/services/sound_repository.dart';
import 'package:soundboard/services/name_identity.dart';

void main() {
  final firstId = NameIdentity.idFor('SHao');
  SelectedAudioFile file(int size) =>
      SelectedAudioFile(name: 'sound.mp3', bytes: Uint8List(size));

  test(
    'uploads record only a name-based library and isolate other names',
    () async {
      final database = FakeFirebaseFirestore();
      final first = SoundRepository(userName: 'SHao', firestore: database);
      final second = SoundRepository(userName: 'Alice', firestore: database);
      await first.save(name: ' Bell ', file: file(4));
      final profile = await database.doc('devices/$firstId').get();
      expect(profile.data()?['userName'], 'SHao');
      expect(profile.data()?['libraryId'], firstId);
      expect(profile.data(), isNot(contains('deviceId')));
      expect(profile.data(), isNot(contains('deviceName')));
      final sounds = await database.collection('devices/$firstId/sounds').get();
      expect(sounds.docs.single.data()['libraryId'], firstId);
      expect(sounds.docs.single.data()['userName'], 'SHao');
      expect(sounds.docs.single.data(), isNot(contains('deviceId')));
      expect(sounds.docs.single.data(), isNot(contains('deviceName')));
      expect(sounds.docs.single.data()['name'], 'Bell');
      expect(
        base64Decode(sounds.docs.single.data()['url'] as String),
        file(4).bytes,
      );
      expect(await first.watchSounds().first, hasLength(1));
      expect(await second.watchSounds().first, isEmpty);
      expect((await database.collection('Sound').get()).docs, isEmpty);
    },
  );

  test('invalid upload creates neither a library nor a sound', () async {
    final database = FakeFirebaseFirestore();
    final repository = SoundRepository(userName: 'SHao', firestore: database);
    await expectLater(
      repository.save(name: '', file: file(1)),
      throwsArgumentError,
    );
    expect((await database.collection('devices').get()).docs, isEmpty);
    expect(
      (await database.collection('devices/$firstId/sounds').get()).docs,
      isEmpty,
    );
  });

  test('library requires a valid name', () {
    expect(() => SoundRepository(userName: ' '), throwsArgumentError);
  });

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
