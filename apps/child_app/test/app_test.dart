import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

/// Pornește aplicația fără voce și cu „reduce motion” (animații deterministe).
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true, size: Size(1280, 900)),
        child: LicuriciApp(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Închide aplicația și lasă timerele rămase (animații cu întârziere) să expire.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('ecranul principal arată clasele și jocurile clasei alese', (tester) async {
    await pumpApp(tester);
    expect(find.text('Grădiniță'), findsOneWidget);
    expect(find.text('Adunăm'), findsOneWidget); // clasa 1 implicit

    await tester.tap(find.text('Grădiniță'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Adunăm'), findsNothing); // adunarea începe din clasa 1
    expect(find.text('Numărăm'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('un joc se poate juca până la final, iar greșelile nu blochează', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Culori'));
    await tester.pump(const Duration(milliseconds: 600));

    for (var round = 0; round < 10 && find.text('Încă o dată').evaluate().isEmpty; round++) {
      // Atinge variantele pe rând: greșelile doar se estompează, deci ajungem la corect.
      for (var i = 0; i < 5 && find.text('Bravo!').evaluate().isEmpty; i++) {
        final option = find.byKey(ValueKey('choice-$i'));
        if (option.evaluate().isEmpty) break;
        await tester.tap(option, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Bravo!'), findsWidgets, reason: 'runda $round nu s-a rezolvat');
      await tester.pump(const Duration(milliseconds: 1500)); // trecerea la runda următoare
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.text('Încă o dată'), findsOneWidget);
    await tester.tap(find.text('Acasă').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Grădiniță'), findsOneWidget);
    await closeApp(tester);
  });
}
