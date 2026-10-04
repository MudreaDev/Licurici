import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/feed/feed_screen.dart';
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
    testWidgets('hrănește peștii: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(feedLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/h',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/h', builder: (_, _) => const FeedScreen(seed: 2)),
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
      final l = const FeedGame().generate(level, seed: 2);
      for (final (i, r) in l.rounds.indexed) {
        await tester.pump(const Duration(milliseconds: 300));
        if (shots && i == 0) {
          await expectLater(
            find.byType(FeedScreen),
            matchesGoldenFile('shots/pesti-$device.png'),
          );
        }
        final food = find.byKey(const ValueKey('feed-food'));
        if (i == 0) {
          // Lăsată în apă, departe de pești: se întoarce pe frunză.
          final from = tester.getCenter(food);
          await tester.dragFrom(from, Offset(0, -12));
          await tester.pump();
        }
        // Trage spre unde e acum peștele flămând (se mișcă puțin în timpul tragerii).
        final from = tester.getCenter(food);
        final to = tester.getCenter(find.byKey(ValueKey('feed-fish-${r.hungry}')));
        final g = await tester.startGesture(from);
        for (var k = 1; k <= 5; k++) {
          await g.moveTo(Offset.lerp(from, to, k / 5)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        final at = tester.getCenter(find.byKey(ValueKey('feed-fish-${r.hungry}')));
        await g.moveTo(at);
        await g.up();
        await tester.pump(const Duration(milliseconds: 1500));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.rounds.length));
      expect(trials.first.correct, isFalse);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
