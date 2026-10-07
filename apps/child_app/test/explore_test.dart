import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/explore/explore_screen.dart';
import 'package:licurici/features/games/sort/sort_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, settleUntil, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('explorare: harta, povestea opririi, sortarea, steaua, finalul ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final episode = exploreEpisodeById('explorare-istorie')!;
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/exploreaza/${episode.id}',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          exploreRoute(),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settleUntil(tester, find.byKey(ValueKey('stop-${episode.stops.first.id}')));
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/explorare-$device.png'));

      for (final stop in episode.stops) {
        await tester.tap(find.byKey(ValueKey('stop-${stop.id}')));
        await settleUntil(tester, find.byKey(const ValueKey('stop-go')));
        await tester.tap(find.byKey(const ValueKey('stop-go')));
        await settleUntil(tester, find.byKey(const ValueKey('sort-item-0')));
        final level = tester.widget<SortScreen>(find.byType(SortScreen)).preset!;
        for (final it in level.items) {
          await tester.tap(find.byKey(ValueKey('sort-item-${it.index}')));
          await tester.pump();
          await tester.tap(find.byKey(ValueKey('sort-bin-${it.binId}')));
          await tester.pump();
        }
        for (var i = 0; i < 40 && find.byType(SortScreen).evaluate().isNotEmpty; i++) {
          await settle(tester, 1);
        }
        expect(find.byType(SortScreen), findsNothing, reason: 'înapoi pe hartă după ${stop.id}');
        if (stop != episode.stops.last) {
          expect(find.byKey(ValueKey('stop-done-${stop.id}')), findsOneWidget);
        }
      }
      await settleUntil(tester, find.byType(RewardFinish));
      expect(find.text(episode.outro), findsWidgets);
      // Fiecare lucru pus = o încercare, pe treapta episodului.
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(episode.stops.fold<int>(0, (n, s) => n + s.items.length)));
      expect(trials.every((t) => t.stepId == 'PAC-I4' && t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
