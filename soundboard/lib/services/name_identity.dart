import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A library selector, not password-based authentication.
class NameIdentity {
  static const preferenceKey = 'soundboard_remembered_name';

  static String normalize(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String idFor(String name) {
    final normalized = normalize(name).toLowerCase();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError('Enter a name between 1 and 80 characters.');
    }
    return 'name_${base64Url.encode(utf8.encode(normalized)).replaceAll('=', '')}';
  }

  static Future<String?> load() async {
    final preferences = SharedPreferencesAsync();
    // Discard the old installation identifier; it no longer selects any data.
    await preferences.remove('soundboard_device_id');
    final name = await preferences.getString(preferenceKey);
    if (name != null) idFor(name);
    return name;
  }

  static Future<void> remember(String? name) async {
    final preferences = SharedPreferencesAsync();
    if (name == null) {
      await preferences.remove(preferenceKey);
    } else {
      idFor(name);
      await preferences.setString(preferenceKey, normalize(name));
    }
  }
}
