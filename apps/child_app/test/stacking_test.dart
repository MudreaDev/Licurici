import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/stacking/stacking_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 5), ('tableta', 2)]) {
    testWidgets('Turnul: nivelul $level pe $device, o greșeală la primul turn, apoi corect', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(stackingLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => const StackingScreen(seed: 2)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await settle(tester, 2);
      if (shots) await expectLater(find.byType(StackingScreen), matchesGoldenFile('shots/turnul-$device.png'));
      final l = const StackingGame().generate(level, seed: 2);
      for (final (ti, t) in l.towers.indexed) {
        if (ti == 0) {
          // Inelul cel mai mic, prea devreme: rămâne în tavă.
          await tester.tap(find.byKey(ValueKey('ring-${t.size - 1}')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(ValueKey('ring-${t.size - 1}')), findsOneWidget);
        }
        for (var rank = 0; rank < t.size; rank++) {
          await tester.tap(find.byKey(ValueKey('ring-$rank')));
          await tester.pump(const Duration(milliseconds: 150));
        }
        await settle(tester, 10);
      }
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.map((t) => t.correct), [false, true, true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
