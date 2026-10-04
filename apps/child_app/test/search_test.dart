import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/search/search_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 14), ('tableta', 6)]) {
    testWidgets('caută: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(searchLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/c',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/c', builder: (_, _) => const SearchScreen(seed: 8)),
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
      final l = const SearchGame().generate(level, seed: 8);
      if (shots) {
        await expectLater(
          find.byType(SearchScreen),
          matchesGoldenFile('shots/cauta-$device.png'),
        );
      }
      for (final (ri, r) in l.rounds.indexed) {
        final target = r.items.firstWhere((i) => i.object.emoji == r.target.emoji);
        if (ri == 0) {
          final other = r.items.firstWhere((i) => i != target);
          await tester.tap(find.byKey(ValueKey('search-item-${other.index}')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        // Toate obiectele trebuie să fie în ecran și atingibile.
        for (final it in r.items) {
          final rect = tester.getRect(find.byKey(ValueKey('search-item-${it.index}')));
          expect(rect.shortestSide, greaterThanOrEqualTo(36));
          expect(tester.view.physicalSize.width, greaterThanOrEqualTo(rect.right - 1));
        }
        await tester.tap(find.byKey(ValueKey('search-item-${target.index}')));
        await tester.pump(const Duration(milliseconds: 1500));
        await settle(tester, 2);
      }
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(l.rounds.length));
      expect(trials.first.correct, isFalse);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
