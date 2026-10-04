import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/gaze/gaze_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 6), ('tableta', 2)]) {
    testWidgets('unde se uită: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(gazeLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/g',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/g', builder: (_, _) => const GazeScreen(seed: 3)),
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
      final l = const GazeGame().generate(level, seed: 3);
      for (final (i, r) in l.rounds.indexed) {
        await tester.pump(const Duration(milliseconds: 950));
        if (shots && i == 0) {
          await expectLater(
            find.byType(GazeScreen),
            matchesGoldenFile('shots/privire-$device.png'),
          );
        }
        if (i == 0) {
          await tester.tap(find.byKey(ValueKey('gaze-object-${1 - r.side}')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.tap(find.byKey(ValueKey('gaze-object-${r.side}')));
        await tester.pump(const Duration(milliseconds: 1600));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.rounds.length));
      expect(trials.first.correct, isFalse);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(trials.first.stepId, level <= 3 ? 'ATN3' : 'ATN4');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
