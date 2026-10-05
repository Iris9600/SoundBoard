import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/selected_audio_file.dart';
import '../models/sound.dart';
import 'device_identity.dart';

/// Owns persistence and upload rules for one device's sounds.
class SoundRepository {
  // Base64 increases size by a third; leave room for Firestore metadata.
  static const maxAudioBytes = 700 * 1024;

  final String deviceId;
  final FirebaseFirestore? _firestore;

  SoundRepository({required this.deviceId, FirebaseFirestore? firestore})
    : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _sounds =>
      (_firestore ?? FirebaseFirestore.instance).collection(
        DeviceIdentity.soundsPath(deviceId),
      );

  Stream<List<Sound>> watchSounds() => _sounds.snapshots().map(
    (snapshot) => snapshot.docs
        .map((document) => Sound.fromMap(document.id, document.data()))
        .toList(),
  );

  static String? validateUpload(String name, SelectedAudioFile? file) {
    if (name.trim().isEmpty) return 'Please enter a name';
    if (file == null || file.bytes.isEmpty) {
      return 'Please select an audio file';
    }
    if (file.bytes.length > maxAudioBytes) {
      return 'Please select a file smaller than 700 KB';
    }
    return null;
  }

  Future<void> save({
    required String name,
    required SelectedAudioFile file,
  }) async {
    final error = validateUpload(name, file);
    if (error != null) throw ArgumentError(error);
    await _sounds.add({
      'deviceId': deviceId,
      'name': name.trim(),
      'url': base64Encode(file.bytes),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
