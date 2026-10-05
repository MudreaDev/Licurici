import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/maze/maze_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 9), ('tableta', 4)]) {
    testWidgets('labirint: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(mazeLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/l',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/l', builder: (_, _) => const MazeScreen(seed: 2)),
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
      final l = const MazeGame().generate(level, seed: 2);
      if (shots) {
        await expectLater(
          find.byType(MazeScreen),
          matchesGoldenFile('shots/labirint-$device.png'),
        );
      }
      for (final m in l.mazes) {
        final rect = tester.getRect(find.byKey(const ValueKey('maze-field')));
        final cell = rect.width / m.cols;
        Offset at(int i) {
          final (c, r) = m.cell(i);
          return rect.topLeft + Offset((c + 0.5) * cell, (r + 0.5) * cell);
        }

        final route = m.path(0, m.cols * m.rows - 1);
        final g = await tester.startGesture(at(0));
        for (final i in route.skip(1)) {
          await g.moveTo(at(i));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pump(const Duration(milliseconds: 1500));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(3));
      expect(trials.every((t) => t.correct && t.offTargetTaps == 0), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
