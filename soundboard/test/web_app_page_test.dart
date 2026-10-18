import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundboard/models/sound.dart';
import 'package:soundboard/pages/web_app_page.dart';
import 'package:soundboard/pages/upload_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('browser workspace fits width $width and opens upload', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: WebAppPage(userName: 'Alice', sounds: Stream.value(<Sound>[])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SoundBoard · Web App'), findsOneWidget);
      expect(
        find.text('Your workspace'),
        width >= 900 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Your library is empty. Upload your first sound.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('No sounds match your search.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Upload sound'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
