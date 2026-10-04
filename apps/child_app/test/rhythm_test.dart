import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/rhythm/rhythm_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

/// Așteaptă rândul copilului (după demonstrație).
Future<void> _waitTurn(WidgetTester tester) async {
  for (var i = 0; i < 120 && find.text('Rândul tău').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Rândul tău'), findsOneWidget);
}

Future<void> _beat(
  WidgetTester tester,
  RhythmPattern p, {
  bool even = false,
}) async {
  var last = 0;
  for (final (i, b) in p.beats.indexed) {
    final at = even ? i * RhythmGame.step : b.atMs;
    await tester.pump(Duration(milliseconds: at - last));
    last = at;
    await tester.tap(find.byKey(ValueKey('rhythm-drum-${b.drum}')));
  }
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 8), ('tableta', 5)]) {
    testWidgets('toba magică: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(rhythmLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Acasă')),
          ),
          GoRoute(path: '/t', builder: (_, _) => const RhythmScreen(seed: 9)),
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
      final l = const RhythmGame().generate(level, seed: 9);
      for (final (i, p) in l.patterns.indexed) {
        await _waitTurn(tester);
        if (shots && i == 0) {
          await expectLater(
            find.byType(RhythmScreen),
            matchesGoldenFile('shots/toba-$device.png'),
          );
        }
        if (i == 0) {
          // Prima dată: bătut egal (forma ritmului inegal se pierde) → Licurici îl reia.
          await _beat(tester, p, even: true);
          await tester.pump(const Duration(milliseconds: 1300));
          expect(find.text('Ascultă'), findsOneWidget);
          await _waitTurn(tester);
        }
        await _beat(tester, p);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 1500));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.patterns.length));
      expect(trials.every((t) => t.correct), isTrue);
      expect(trials.first.promptLevel, PromptLevel.p4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
