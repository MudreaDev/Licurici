import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/build/build_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 8), ('tableta', 4)]) {
    testWidgets('construiește la fel: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(buildLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/b',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/b', builder: (_, _) => const BuildScreen(seed: 2)),
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
      final l = const BuildGame().generate(level, seed: 2);
      if (shots) {
        await expectLater(
          find.byType(BuildScreen),
          matchesGoldenFile('shots/construieste-$device.png'),
        );
      }
      for (final (ri, r) in l.rounds.indexed) {
        if (l.axes.hideModelMs != null) {
          await tester.pump(Duration(milliseconds: l.axes.hideModelMs! + 100));
          if (ri == 0) {
            await tester.tap(find.byKey(const ValueKey('build-peek')));
            await tester.pump();
          }
        }
        for (var c = 0; c < r.model.length; c++) {
          final good = r.palette.indexOf(r.model[c]);
          if (ri == 0 && c == 0) {
            final bad = r.palette.indexWhere((p) => p != r.model[c]);
            await tester.tap(find.byKey(ValueKey('build-palette-$bad')));
            await tester.pump();
            await tester.tap(find.byKey(ValueKey('build-cell-$c')));
            await tester.pump();
          }
          await tester.tap(find.byKey(ValueKey('build-palette-$good')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('build-cell-$c')));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 1700));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(3));
      expect(trials.first.attempts, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
