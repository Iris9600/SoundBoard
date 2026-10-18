import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:soundboard/app.dart';
import 'package:soundboard/pages/main_page.dart';
import 'package:soundboard/pages/name_gate.dart';
import 'package:soundboard/services/name_identity.dart';
import 'package:soundboard/services/name_registry.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('registration reports database denial instead of invalid name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: NameGate(registry: _DeniedRegistry())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'New name');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Database access is blocked. The app administrator needs to update Firestore security rules.',
      ),
      findsOneWidget,
    );
    expect(find.byType(MainPage), findsNothing);
    expect(await NameIdentity.load(), isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Login blocks unknown names and does not remember them', (
    tester,
  ) async {
    final registry = NameRegistry(firestore: FakeFirebaseFirestore());
    await tester.pumpWidget(MaterialApp(home: NameGate(registry: registry)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Unknown');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid user name, try again (O.o)'), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
    expect(await NameIdentity.load(), isNull);
  });

  testWidgets('Register reports duplicate names', (tester) async {
    final registry = NameRegistry(firestore: FakeFirebaseFirestore());
    await registry.register('Alice');
    await tester.pumpWidget(MaterialApp(home: NameGate(registry: registry)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ALICE');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();
    expect(find.text('This username already exist'), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
  });

  testWidgets('Remembered names are checked before opening the library', (
    tester,
  ) async {
    await NameIdentity.remember('Deleted name');
    final registry = NameRegistry(firestore: FakeFirebaseFirestore());
    await tester.pumpWidget(MaterialApp(home: NameGate(registry: registry)));
    await tester.pumpAndSettle();
    expect(find.text('Invalid user name, try again (O.o)'), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });
  testWidgets('startup asks for a name and discards any old device ID', (
    tester,
  ) async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString('soundboard_device_id', 'old-device-id');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
    expect(find.text('Remember me'), findsOneWidget);
    expect(await preferences.getString('soundboard_device_id'), isNull);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('selecting either mode clears the name, including reselection', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    for (final mode in ['Login', 'Register', 'Register', 'Login']) {
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<bool>),
          matching: find.text(mode),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        {mode == 'Login'},
      );
    }
  });

  testWidgets('Register hides remember me and Login restores it unchecked', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Remember me'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Remember me'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });
}

class _DeniedRegistry extends NameRegistry {
  @override
  Future<void> register(String name) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}
