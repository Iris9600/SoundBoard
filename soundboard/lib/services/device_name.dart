import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A display name only; ownership always uses the persisted installation ID.
class DeviceName {
  static Future<String> load() async {
    if (kIsWeb) return 'Web browser';
    final info = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return (await info.windowsInfo).computerName;
      case TargetPlatform.macOS:
        return (await info.macOsInfo).computerName;
      case TargetPlatform.linux:
        return (await info.linuxInfo).prettyName;
      case TargetPlatform.iOS:
        return (await info.iosInfo).name;
      case TargetPlatform.android:
        final name = await const MethodChannel(
          'soundboard/device_name',
        ).invokeMethod<String>('getDeviceName');
        if (name != null && name.trim().isNotEmpty) return name.trim();
        return (await info.androidInfo).model;
      case TargetPlatform.fuchsia:
        return 'Fuchsia device';
    }
  }
}
