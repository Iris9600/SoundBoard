import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundboard/services/name_identity.dart';
import 'package:soundboard/services/name_registry.dart';

void main() {
  late FakeFirebaseFirestore database;
  late NameRegistry registry;
  setUp(() {
    database = FakeFirebaseFirestore();
    registry = NameRegistry(firestore: database);
  });

  test(
    'login rejects unknown names without creating database records',
    () async {
      await expectLater(
        registry.login('Alice'),
        throwsA(isA<NameRegistryException>()),
      );
      expect((await database.collection('devices').get()).docs, isEmpty);
    },
  );

  test(
    'register persists name immediately and allows normalized login',
    () async {
      await registry.register(' Alice   Smith ');
      final profile = await database
          .doc('devices/${NameIdentity.idFor('Alice Smith')}')
          .get();
      expect(profile.data()?['userName'], 'Alice Smith');
      expect(profile.data()?['createdAt'], isNotNull);
      await registry.login('alice smith');
      expect(
        (await profile.reference.collection('sounds').get()).docs,
        isEmpty,
      );
    },
  );

  test(
    'duplicate registration preserves existing profile and sounds',
    () async {
      await registry.register('Alice');
      final profile = database.doc('devices/${NameIdentity.idFor('Alice')}');
      await profile.collection('sounds').doc('bell').set({'name': 'Bell'});
      final original = (await profile.get()).data();
      await expectLater(
        registry.register(' ALICE '),
        throwsA(
          isA<NameRegistryException>().having(
            (error) => error.message,
            'message',
            'This username already exist',
          ),
        ),
      );
      expect((await profile.get()).data(), original);
      expect((await profile.collection('sounds').get()).docs, hasLength(1));
    },
  );
}
