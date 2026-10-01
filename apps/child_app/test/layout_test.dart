import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

/// Dimensiuni reale în LANDSCAPE (dp). Orice depășire de layout (RenderFlex overflow)
/// face testul să pice — aplicația trebuie să încapă pe cel mai mic telefon suportat.
const devices = {
  'telefon-mic': Size(640, 360),
  'telefon': Size(844, 390),
  'telefon-lat': Size(915, 412),
  'tableta': Size(1280, 800),
};

/// Capturi PNG pentru inspecție vizuală: `flutter test --update-goldens --dart-define=SHOTS=true`.
const shots = bool.fromEnvironment('SHOTS');

Future<void> loadFonts() async {
  final loader = FontLoader('packages/$contentPackage/$fontFamily');
  for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(
      File(
        '../../packages/game_content/fonts/Nunito-$w.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
}

Future<void> settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> settleUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await settle(tester, 1);
  }
  expect(finder, findsWidgets, reason: 'nu a apărut: $finder');
  await settle(tester, 4); // animațiile de intrare
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final MapEntry(key: name, value: size) in devices.entries) {
    testWidgets(
      'layout în landscape: $name ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              voiceProvider.overrideWithValue(const SilentSpeaker()),
              voiceManifestProvider.overrideWith(
                (ref) => VoiceManifest(const {}),
              ),
            ],
            child: const LicuriciApp(),
          ),
        );
        await settle(tester, 1); // ecranul de pornire e încă vizibil
        if (shots) {
          await expectLater(
            find.byType(LicuriciApp),
            matchesGoldenFile('shots/$name-0-pornire.png'),
          );
        }

        await settleUntil(tester, find.text('Clasa 1'));
        if (shots) {
          await expectLater(
            find.byType(LicuriciApp),
            matchesGoldenFile('shots/$name-1-acasa.png'),
          );
        }

        // Lista de jocuri e orizontală și leneșă: cardurile se construiesc doar la derulare.
        await tester.scrollUntilVisible(
          find.text('Adunăm'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await settle(tester, 2);
        await tester.tap(find.text('Adunăm'));
        // Primul joc din sesiune: „Cum te simți?” (trebuie să încapă și pe telefonul mic).
        await settleUntil(tester, find.byKey(const ValueKey('mood-bucuros')));
        if (shots) {
          await expectLater(
            find.byType(LicuriciApp),
            matchesGoldenFile('shots/$name-2-dispozitie.png'),
          );
        }
        await tester.tap(find.byKey(const ValueKey('mood-bucuros')));
        await settleUntil(tester, find.byKey(const ValueKey('choice-0')));
        if (shots) {
          await expectLater(
            find.byType(LicuriciApp),
            matchesGoldenFile('shots/$name-3-joc.png'),
          );
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
    );
  }

  // Nativ, aplicația e blocată în landscape; pe web un telefon poate fi ținut în portret.
  testWidgets('telefon ținut în portret: cere rotirea', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
        ],
        child: const LicuriciApp(),
      ),
    );
    await settle(tester, 3);
    expect(find.text('Întoarce telefonul'), findsOneWidget);
    if (shots) {
      await expectLater(
        find.byType(LicuriciApp),
        matchesGoldenFile('shots/portret.png'),
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
