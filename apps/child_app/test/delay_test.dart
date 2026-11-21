import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/delay/delay_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, difficulty) in [('telefon-mic', 1), ('tableta', 1), ('telefon-mic', 13)]) {
    testWidgets('Acum sau mai mult?: așteaptă, renunță, alege acum ($device, nivel $difficulty)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(delayLevelProvider.notifier).setLevel(difficulty);
      final router = GoRouter(
        initialLocation: '/d',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/d', builder: (_, _) => const DelayScreen(seed: 1)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settle(tester, 2);
      final before = container.read(settingsProvider).stars;
      if (shots && difficulty == 1) await expectLater(find.byType(DelayScreen), matchesGoldenFile('shots/acum-sau-mai-mult-$device.png'));
      final level = const DelayGame().generate(difficulty, seed: 1);
      final now = find.byKey(const ValueKey('delay-now')), later = find.byKey(const ValueKey('delay-later'));
      // 1. Așteaptă până la capăt.
      await tester.tap(later);
      for (var t = 0; t < level.offers[0].waitMs + 400; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester, 10);
      // 2. Începe să aștepte, apoi ia steaua acum.
      await tester.tap(later);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(now);
      await settle(tester, 10);
      // 3. și 4. Acum.
      for (var i = 0; i < level.offers.length - 2; i++) {
        await tester.tap(now);
        await settle(tester, 10);
      }
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect([for (final t in trials) t.stimulusId], ['asteapta', 'a-renuntat', for (var i = 0; i < level.offers.length - 2; i++) 'acum']);
      // 3 stele pentru așteptare + 3 × 1, plus stelele de la final.
      expect(container.read(settingsProvider).stars, greaterThanOrEqualTo(before + level.offers.first.later + level.offers.length - 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
