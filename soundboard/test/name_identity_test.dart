import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:soundboard/models/selected_audio_file.dart';
import 'package:soundboard/services/name_identity.dart';
import 'package:soundboard/services/sound_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('remember me persists a name and opting out removes it', () async {
    expect(await NameIdentity.load(), isNull);
    await NameIdentity.remember('  Alice   Smith ');
    expect(await NameIdentity.load(), 'Alice Smith');
    await NameIdentity.remember(null);
    expect(await NameIdentity.load(), isNull);
  });

  test('names are stable across installations and safe for document paths', () {
    expect(
      NameIdentity.idFor(' Alice   Smith '),
      NameIdentity.idFor('alice smith'),
    );
    expect(NameIdentity.idFor('Alice'), isNot(NameIdentity.idFor('Bob')));
    expect(NameIdentity.idFor('张 / 三'), isNot(contains('/')));
    expect(() => NameIdentity.idFor('  '), throwsArgumentError);
    expect(() => NameIdentity.idFor('a' * 81), throwsArgumentError);
  });

  test(
    'same name shares sounds across installations; other names are separate',
    () async {
      final database = FakeFirebaseFirestore();
      SoundRepository library(String name) =>
          SoundRepository(userName: name, firestore: database);
      await library('Alice').save(
        name: 'Bell',
        file: SelectedAudioFile(
          name: 'bell.wav',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      expect(await library(' alice ').watchSounds().first, hasLength(1));
      expect(await library('Bob').watchSounds().first, isEmpty);
    },
  );
}
