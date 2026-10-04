import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/rules/switch_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 8), ('tableta', 3)]) {
    testWidgets('regula se schimbă: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(switchLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/r',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/r', builder: (_, _) => const SwitchScreen(seed: 6)),
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
      final l = const SwitchGame().generate(level, seed: 6);
      await tester.pump(const Duration(milliseconds: 1800));
      if (shots) {
        await expectLater(
          find.byType(SwitchScreen),
          matchesGoldenFile('shots/regula-$device.png'),
        );
      }
      final switches = l.switches.toSet();
      for (final it in l.items) {
        // Anunțul unei reguli noi (doar la blocuri).
        if (switches.contains(it.index) && !l.axes.mixed) {
          await tester.pump(const Duration(milliseconds: 1800));
        }
        // Primul cartonaș după fiecare schimbare: greșeală de perseverare, apoi corect.
        if (switches.contains(it.index)) {
          await tester.tap(find.byKey(ValueKey('switch-box-${it.otherRuleAnswer}')));
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (it.index == 0) {
          // Prin tragere, ca să verificăm și calea asta.
          final from = tester.getCenter(find.byKey(const ValueKey('switch-card')));
          final to = tester.getCenter(find.byKey(ValueKey('switch-box-${it.answer}')));
          await tester.dragFrom(from, to - from);
        } else {
          await tester.tap(find.byKey(ValueKey('switch-box-${it.answer}')));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.items.length));
      expect(trials.where((t) => !t.correct), hasLength(switches.length));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
