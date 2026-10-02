import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:soundboard/device_identity.dart';
import 'package:soundboard/main.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('device identity persists across loads', () async {
    final first = await DeviceIdentity.loadOrCreate();
    expect(await DeviceIdentity.loadOrCreate(), first);
    expect(first, matches(RegExp(r'^[a-f0-9]{32}$')));
  });

  test('separate installations use separate sound collections', () async {
    final first = await DeviceIdentity.loadOrCreate();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final second = await DeviceIdentity.loadOrCreate();
    expect(
      DeviceIdentity.soundsPath(first),
      isNot(DeviceIdentity.soundsPath(second)),
    );
  });

  test('invalid saved identity fails without replacing ownership', () async {
    await SharedPreferencesAsync().setString(
      DeviceIdentity.preferenceKey,
      'invalid/id',
    );
    await expectLater(DeviceIdentity.loadOrCreate(), throwsStateError);
    expect(() => DeviceIdentity.soundsPath('invalid/id'), throwsArgumentError);
  });

  testWidgets('identity failure blocks the board and provides retry', (
    tester,
  ) async {
    await SharedPreferencesAsync().setString(
      DeviceIdentity.preferenceKey,
      'invalid',
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to identify this device. Please retry.'),
      findsOneWidget,
    );
    expect(find.byType(MainPage), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });
}
