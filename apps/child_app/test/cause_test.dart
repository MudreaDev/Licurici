import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/cause/cause_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 6), ('tableta', 1)]) {
    testWidgets('atinge și vezi: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(causeLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/a', builder: (_, _) => const CauseScreen(seed: 4)),
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
      final l = const CauseGame().generate(level, seed: 4);
      // O atingere pe lângă (colțul de sus), apoi 10 pe obiecte, pe rând.
      final field = tester.getRect(find.byKey(const ValueKey('cause-field')));
      await tester.tapAt(field.topLeft + const Offset(4, 4));
      for (var k = 0; k < 10; k++) {
        await tester.tap(find.byKey(ValueKey('cause-object-${k % l.objects.length}')));
        await tester.pump(const Duration(milliseconds: 400));
        if (shots && k == 0) {
          await expectLater(
            find.byType(CauseScreen),
            matchesGoldenFile('shots/atinge-$device.png'),
          );
        }
        await tester.pump(const Duration(milliseconds: 1100));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(10));
      expect(trials.first.offTargetTaps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
