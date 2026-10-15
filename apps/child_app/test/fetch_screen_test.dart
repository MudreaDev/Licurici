import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/fetch/fetch_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 6), ('tableta', 2)]) {
    testWidgets('Adu-mi: nivelul $level pe $device, o greșeală la prima cerere, apoi corect', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(fetchLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => const FetchScreen(seed: 3)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await settle(tester, 2);
      if (shots) await expectLater(find.byType(FetchScreen), matchesGoldenFile('shots/adu-mi-$device.png'));
      final l = const FetchGame().generate(level, seed: 3);
      expect(find.byKey(const ValueKey('fetch-basket')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fetch-repeat')));
      for (final (i, r) in l.rounds.indexed) {
        if (i == 0) {
          // Un obiect care nu a fost cerut: se clatină și rămâne pe masă.
          final wrong = r.table.firstWhere((o) => !r.wanted.contains(o));
          await tester.tap(find.byKey(ValueKey('fetch-${wrong.word}')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(ValueKey('fetch-${wrong.word}')), findsOneWidget);
        }
        for (final w in r.wanted) {
          await tester.tap(find.byKey(ValueKey('fetch-${w.word}')));
          await tester.pump(const Duration(milliseconds: 150));
        }
        await settle(tester, 10);
      }
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.map((t) => t.correct), [false, true, true, true, true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
