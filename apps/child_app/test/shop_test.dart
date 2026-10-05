import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/shop/shop_screen.dart';
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
    testWidgets('la magazin: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(shopLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/m',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/m', builder: (_, _) => const ShopScreen(seed: 6)),
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
      final l = const ShopGame().generate(level, seed: 6);
      if (shots) {
        await expectLater(
          find.byType(ShopScreen),
          matchesGoldenFile('shots/magazin-$device.png'),
        );
      }
      for (final (ri, r) in l.rounds.indexed) {
        if (ri == 0) {
          final other = r.shelf.firstWhere((o) => !r.list.contains(o));
          await tester.tap(find.byKey(ValueKey('shop-item-${other.emoji}')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        for (final o in r.list) {
          await tester.tap(find.byKey(ValueKey('shop-item-${o.emoji}')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump(const Duration(milliseconds: 1800));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(3));
      expect(trials.first.offTargetTaps, 1);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
