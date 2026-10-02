import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identifies this app installation without collecting hardware identifiers.
class DeviceIdentity {
  static const preferenceKey = 'soundboard_device_id';
  static final _validId = RegExp(r'^[a-f0-9]{32}$');

  static Future<String> loadOrCreate() async {
    final preferences = SharedPreferencesAsync();
    final savedId = await preferences.getString(preferenceKey);
    if (savedId != null) {
      if (!_validId.hasMatch(savedId)) {
        throw StateError('The saved device ID is invalid.');
      }
      return savedId;
    }

    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await preferences.setString(preferenceKey, id);
    if (await preferences.getString(preferenceKey) != id) {
      throw StateError('Unable to save the device ID.');
    }
    return id;
  }

  static String soundsPath(String deviceId) {
    if (!_validId.hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Invalid device ID');
    }
    return 'devices/$deviceId/sounds';
  }
}
