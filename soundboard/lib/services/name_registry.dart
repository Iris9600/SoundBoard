import 'package:cloud_firestore/cloud_firestore.dart';

import 'name_identity.dart';

class NameRegistryException implements Exception {
  final String message;
  const NameRegistryException(this.message);
}

/// Stores registered names alongside their existing sound libraries.
class NameRegistry {
  final FirebaseFirestore? _firestore;

  NameRegistry({FirebaseFirestore? firestore}) : _firestore = firestore;

  DocumentReference<Map<String, dynamic>> _profile(String name) =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('devices')
          .doc(NameIdentity.idFor(name));

  Future<void> login(String name) async {
    final profile = await _profile(
      name,
    ).get(const GetOptions(source: Source.server));
    if (!profile.exists) {
      throw const NameRegistryException('Invalid user name, try again (O.o)');
    }
  }

  Future<void> register(String name) async {
    final profile = _profile(name);
    final database = _firestore ?? FirebaseFirestore.instance;
    await database.runTransaction((transaction) async {
      final existing = await transaction.get(profile);
      if (existing.exists) {
        throw const NameRegistryException('This username already exist');
      }
      transaction.set(profile, {
        'libraryId': NameIdentity.idFor(name),
        'userName': NameIdentity.normalize(name),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
