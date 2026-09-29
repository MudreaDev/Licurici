import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

/// Pornește aplicația fără voce și cu „reduce motion” (animații deterministe).
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
      ],
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true, size: Size(1280, 900)),
        child: LicuriciApp(),
      ),
    ),
  );
  // Ecranul de pornire pre-încarcă resursele, apoi dispare.
  expect(find.text('Se pregătesc jocurile…'), findsOneWidget);
  await pumpUntil(tester, find.text('Grădiniță'));
  await tester.pump(
    const Duration(milliseconds: 600),
  ); // estomparea ecranului de pornire
  expect(find.text('Se pregătesc jocurile…'), findsNothing);
}

/// Avansează timpul până apare [finder] (maxim ~10 s de timp simulat).
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets, reason: 'nu a apărut: $finder');
}

/// Închide aplicația și lasă timerele rămase (animații cu întârziere) să expire.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  // Cache-urile globale (asset-uri, SVG) păstrează promisiuni create în zona de timp simulat a
  // testului anterior; în testul următor ele nu s-ar mai finaliza. Pornim fiecare test curat.
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  testWidgets('ecranul principal arată clasele și jocurile clasei alese', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Grădiniță'), findsOneWidget);
    expect(find.text('Adunăm'), findsOneWidget); // clasa 1 implicit

    await tester.tap(find.text('Grădiniță'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Adunăm'), findsNothing); // adunarea începe din clasa 1
    expect(find.text('Numărăm'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('un joc se poate juca până la final, iar greșelile nu blochează', (
    tester,
  ) async {
    await pumpApp(tester);
    // Lista de jocuri e leneșă (ListView): derulăm până e construit cardul.
    await tester.scrollUntilVisible(
      find.text('Culori'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Culori'));
    await pumpUntil(tester, find.byKey(const ValueKey('choice-0')));

    for (
      var round = 0;
      round < 10 && find.text('Încă o dată').evaluate().isEmpty;
      round++
    ) {
      // Atinge variantele pe rând: greșelile doar se estompează, deci ajungem la corect.
      for (var i = 0; i < 5 && find.text('Bravo!').evaluate().isEmpty; i++) {
        final option = find.byKey(ValueKey('choice-$i'));
        if (option.evaluate().isEmpty) break;
        await tester.tap(option, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('Bravo!'),
        findsWidgets,
        reason: 'runda $round nu s-a rezolvat',
      );
      await tester.pump(
        const Duration(milliseconds: 1500),
      ); // trecerea la runda următoare
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(find.text('Încă o dată'), findsOneWidget);
    await tester.tap(find.text('Acasă').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Grădiniță'), findsOneWidget);
    await closeApp(tester);
  });
}
