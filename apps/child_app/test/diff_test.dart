import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/diff/diff_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 10), ('tableta', 5)]) {
    testWidgets('diferențe: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(diffLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/d',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/d', builder: (_, _) => const DiffScreen(seed: 4)),
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
      await settle(tester, 2);
      final l = const SpotDiffGame().generate(level, seed: 4);
      if (shots) {
        await expectLater(
          find.byType(DiffScreen),
          matchesGoldenFile('shots/diferente-$device.png'),
        );
      }
      for (final (i, s) in l.scenes.indexed) {
        if (i == 0) {
          final same = [for (var c = 0; c < s.cols * s.rows; c++) c]
              .firstWhere((c) => !s.differences.containsKey(c));
          for (var k = 0; k < 3; k++) {
            await tester.tap(find.byKey(ValueKey('diff-cell-$same')));
            await tester.pump();
          }
        }
        for (final c in s.differences.keys) {
          await tester.tap(find.byKey(ValueKey('diff-cell-$c')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump(const Duration(milliseconds: 1900));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(3));
      expect(trials.first.offTargetTaps, 3);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
