import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/paint_by_ear/paint_by_ear_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 7), ('tableta', 1), ('telefon-mic', 4)]) {
    testWidgets('Colorează ce auzi: nivelul $level pe $device, o greșeală la prima cerere, apoi corect', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(paintByEarLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => const PaintByEarScreen(seed: 3)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await settle(tester, 2);
      if (shots) await expectLater(find.byType(PaintByEarScreen), matchesGoldenFile('shots/coloreaza-$device.png'));
      final l = const PaintGame().generate(level, seed: 3);
      await tester.tap(find.byKey(const ValueKey('paint-repeat')));
      for (final (i, r) in l.rounds.indexed) {
        if (i == 0) {
          // O culoare greșită: obiectul rămâne necolorat.
          final t = r.tasks.first;
          final wrong = r.palette.firstWhere((c) => c != t.color);
          await tester.tap(find.byKey(ValueKey('pot-${wrong.name}')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('paint-slot-${t.slot}')));
          await tester.pump(const Duration(milliseconds: 300));
        }
        for (final t in r.tasks) {
          await tester.tap(find.byKey(ValueKey('pot-${t.color.name}')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('paint-slot-${t.slot}')));
          await tester.pump(const Duration(milliseconds: 150));
        }
        if (shots && i == 0) {
          await tester.pump(const Duration(milliseconds: 500));
          await expectLater(find.byType(PaintByEarScreen), matchesGoldenFile('shots/coloreaza-colorat-$device-$level.png'));
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
