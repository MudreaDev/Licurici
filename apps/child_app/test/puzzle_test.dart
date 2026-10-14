import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/puzzle/puzzle_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 11), ('tableta', 8)]) {
    testWidgets('puzzle: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(puzzleLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/p',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/p', builder: (_, _) => const PuzzleScreen(seed: 3)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildTheme(calm: false),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester, 3);
      final l = const PuzzleGame().generate(level, seed: 3);
      if (shots) {
        await expectLater(
          find.byType(PuzzleScreen),
          matchesGoldenFile('shots/puzzle-$device.png'),
        );
      }
      for (final (ri, r) in l.rounds.indexed) {
        for (final (k, p) in r.tray.indexed) {
          final piece = find.byKey(ValueKey('puzzle-piece-${p.index}'));
          if (ri == 0 && k == 0) {
            // Greșit: atinge piesa, apoi alt loc → piesa rămâne în tavă.
            await tester.tap(piece);
            await tester.pump();
            await tester.tap(find.byKey(ValueKey('puzzle-slot-${(p.index + 1) % r.pieces}')));
            await tester.pump(const Duration(milliseconds: 300));
            expect(piece, findsOneWidget);
          }
          if (k.isEven) {
            // Prin tragere.
            final from = tester.getCenter(piece);
            final to = tester.getCenter(find.byKey(ValueKey('puzzle-slot-${p.index}')));
            await tester.dragFrom(from, to - from);
          } else {
            // Prin atingere: piesa, apoi locul.
            await tester.tap(piece);
            await tester.pump();
            await tester.tap(find.byKey(ValueKey('puzzle-slot-${p.index}')));
          }
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump(const Duration(milliseconds: 1900));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.rounds.length));
      expect(trials.first.attempts, 2);
      expect(trials.skip(1).every((t) => t.attempts == 1), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
