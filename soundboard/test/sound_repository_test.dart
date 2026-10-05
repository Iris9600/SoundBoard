import 'dart:typed_data';
import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundboard/models/selected_audio_file.dart';
import 'package:soundboard/models/sound.dart';
import 'package:soundboard/services/sound_repository.dart';

void main() {
  const firstId = '11111111111111111111111111111111';
  const secondId = '22222222222222222222222222222222';
  SelectedAudioFile file(int size) =>
      SelectedAudioFile(name: 'sound.mp3', bytes: Uint8List(size));

  test(
    'uploads register the named device and isolate its sound data',
    () async {
      final database = FakeFirebaseFirestore();
      final first = SoundRepository(
        deviceId: firstId,
        deviceName: 'SHao',
        firestore: database,
      );
      final second = SoundRepository(
        deviceId: secondId,
        deviceName: 'SHao',
        firestore: database,
      );
      await first.save(name: ' Bell ', file: file(4));
      final profile = await database.doc('devices/$firstId').get();
      expect(profile.data()?['deviceName'], 'SHao');
      expect(profile.data()?['deviceId'], firstId);
      final sounds = await database.collection('devices/$firstId/sounds').get();
      expect(sounds.docs.single.data()['deviceId'], firstId);
      expect(sounds.docs.single.data()['deviceName'], 'SHao');
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

  test('invalid upload creates neither a device nor a sound', () async {
    final database = FakeFirebaseFirestore();
    final repository = SoundRepository(
      deviceId: firstId,
      deviceName: 'SHao',
      firestore: database,
    );
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

  test('device ownership rejects invalid IDs and empty names', () {
    expect(
      () => SoundRepository(deviceId: 'SHao', deviceName: 'SHao'),
      throwsArgumentError,
    );
    expect(
      () => SoundRepository(deviceId: firstId, deviceName: ' '),
      throwsArgumentError,
    );
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
