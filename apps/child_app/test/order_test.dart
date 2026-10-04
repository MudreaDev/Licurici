import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/order/order_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

Future<ProviderContainer> _open(
  WidgetTester tester,
  Size size,
  OrderGame game, {
  int level = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
  );
  addTearDown(container.dispose);
  container.read(orderLevelProvider(game.id).notifier).setLevel(level);
  final router = GoRouter(
    initialLocation: '/o',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
      GoRoute(path: '/o', builder: (_, _) => OrderScreen(game: game, seed: 5)),
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
  await settle(tester, 4);
  return container;
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final game in orderGames) {
    for (final (device, level) in [('telefon-mic', 9), ('tableta', 3)]) {
      testWidgets('${game.id}: nivelul $level pe $device, cu o greșeală', (
        tester,
      ) async {
        final container = await _open(
          tester,
          devices[device]!,
          game,
          level: level,
        );
        final l = game.generate(level, seed: 5);
        if (shots) {
          await expectLater(
            find.byType(OrderScreen),
            matchesGoldenFile('shots/ordine-${game.id}-$device.png'),
          );
        }
        for (final (ri, round) in l.rounds.indexed) {
          // În prima rundă: întâi o greșeală (ultimul pas), apoi în ordine.
          if (ri == 0) {
            await tester.tap(
              find.byKey(ValueKey('order-card-${round.steps.length - 1}')),
            );
            await tester.pump();
          }
          for (var i = 0; i < round.steps.length; i++) {
            await tester.tap(find.byKey(ValueKey('order-card-$i')));
            await tester.pump(const Duration(milliseconds: 300));
          }
          if (shots && ri == 0) {
            await expectLater(
              find.byType(OrderScreen),
              matchesGoldenFile('shots/ordine-${game.id}-$device-gata.png'),
            );
          }
          await settle(tester, 14);
        }
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
}
