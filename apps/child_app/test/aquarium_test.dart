import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici_core/licurici_core.dart' show fishSpecies;
import 'package:licurici/features/aquarium/aquarium_screen.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/coloring_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici/shared/voice.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil, shots;

void main() {
  setUpAll(loadFonts);

  test('pușculița: stelele se adună, se cheltuie, se păstrează', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    n.addStars(2);
    expect(c.read(settingsProvider).stars, AppSettings.startStars + 2);
    expect(n.spendStars(10), isFalse);
    expect(n.spendStars(4), isTrue);
    final s = c.read(settingsProvider);
    expect(AppSettings.fromJson(s.toJson()).stars, s.stars);
    // Setările vechi (fără stele) pornesc cu stelele de început.
    expect(AppSettings.fromJson(const {}).stars, AppSettings.startStars);
  });
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('acvariul: colorez un pește și intră în apă ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryAquariumStore();
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          aquariumStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/acvariu',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(
            path: '/acvariu',
            builder: (_, s) => AquariumScreen(newFishId: s.uri.queryParameters['nou']),
          ),
          GoRoute(path: '/acvariu/coloreaza', builder: (_, _) => const ColoringScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );

      // Prima vizită: peștele dăruit de Licurici.
      await settleUntil(tester, find.byKey(const ValueKey('feed')));
      await tester.runAsync(() => container.read(aquariumProvider.future));
      await settle(tester, 2);
      expect(container.read(aquariumProvider).value, hasLength(1));
      expect(container.read(aquariumProvider).value!.single.entry.gift, isTrue);
      if (shots) await expectLater(find.byType(AquariumScreen), matchesGoldenFile('shots/acvariu-$device.png'));

      // Fără nicio atingere câteva secunde: mânuța arată „ține degetul pe apă”.
      final hand = find.byWidgetPredicate((w) => w is StimulusArt && w.emoji == '👆');
      expect(hand, findsNothing);
      for (var i = 0; i < 40 && hand.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(hand, findsOneWidget);
      if (shots) await expectLater(find.byType(AquariumScreen), matchesGoldenFile('shots/acvariu-indiciu-$device.png'));

      // Noaptea: apa se întunecă, degetul ținut e lanterna; apoi iar zi.
      await tester.tap(find.byKey(const ValueKey('night')));
      await settle(tester, 10);
      await tester.startGesture(tester.getCenter(find.byType(AquariumScreen))).then((g) async {
        await tester.pump(const Duration(milliseconds: 700));
        if (shots) await expectLater(find.byType(AquariumScreen), matchesGoldenFile('shots/acvariu-noapte-$device.png'));
        await g.up();
      });
      await tester.tap(find.byKey(const ValueKey('night')));
      await settle(tester, 2);

      // Atingere, apăsare lungă și mâncare: nimic nu se strică.
      final tank = tester.getCenter(find.byType(AquariumScreen));
      await tester.tapAt(tank);
      await tester.longPressAt(tank);
      // Mâncarea costă o stea; fără stele nu cade nimic.
      expect(container.read(settingsProvider).stars, AppSettings.startStars);
      for (var i = 0; i < AppSettings.startStars + 1; i++) {
        await tester.tap(find.byKey(const ValueKey('feed')));
        await settle(tester, 1);
      }
      expect(container.read(settingsProvider).stars, 0);
      await settle(tester, 2);

      // Colorez: aleg peștele-chirurg și umplu fiecare zonă cu găleata, altă culoare.
      await tester.tap(find.byKey(const ValueKey('color-fish')));
      await settleUntil(tester, find.byKey(const ValueKey('species-chirurg')));
      // Toate modelele încap pe ecran.
      for (final s in fishSpecies) {
        final r = tester.getRect(find.byKey(ValueKey('species-${s.id}')));
        expect(r.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
        expect(r.right, lessThanOrEqualTo(tester.view.physicalSize.width));
      }
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/coloreaza-alege-$device.png'));
      await tester.tap(find.byKey(const ValueKey('species-chirurg')));
      await settleUntil(tester, find.byKey(const ValueKey('sheet')));
      await tester.tap(find.byKey(const ValueKey('fill')));
      final sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
      Offset at(double x, double y) => sheet.topLeft + Offset(x, y) * (sheet.width / 1000);
      for (final (color, x, y) in [(6, 560.0, 300.0), (2, 140.0, 300.0), (10, 560.0, 110.0), (7, 560.0, 488.0)]) {
        await tester.tap(find.byKey(ValueKey('color-$color')));
        await settle(tester, 1);
        await tester.tapAt(at(x, y));
        await settle(tester, 3);
      }
      if (shots) await expectLater(find.byType(ColoringScreen), matchesGoldenFile('shots/coloreaza-$device.png'));
      await tester.tap(find.byKey(const ValueKey('done')));
      await settleUntil(tester, find.byKey(const ValueKey('feed')));

      final fish = container.read(aquariumProvider).value!;
      expect(fish, hasLength(2));
      expect(fish.last.species.id, 'chirurg');
      expect((await store.load()).length, 2);
      await settle(tester, 12);
      if (shots) await expectLater(find.byType(AquariumScreen), matchesGoldenFile('shots/acvariu-nou-$device.png'));
    });
  }
}
