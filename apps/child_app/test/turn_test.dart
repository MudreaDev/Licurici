import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/turns/turn_screen.dart';
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

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('pe rând: așteaptă, pune cubul, dă rândul; atingerea în rândul lui Licurici se numără ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(turnLevelProvider.notifier).setLevel(5); // începe Licurici; copilul dă rândul
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/s', builder: (_, _) => const TurnScreen(seed: 2)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      final level = const TurnGame().generate(5, seed: 2);
      expect(level.axes.childFirst, isFalse);
      expect(level.axes.passTurn, isTrue);
      final tray = find.byKey(const ValueKey('turn-tray'));
      await tester.pump(const Duration(milliseconds: 3300)); // introducerea
      var cycle = 0;
      for (var t = 0; t < level.axes.towers; t++) {
        for (var b = 0; b < level.axes.blocks; b += 2) {
          // Rândul lui Licurici: în primul ciclu, copilul atinge prea devreme.
          if (cycle == 0) {
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(tray);
          }
          await tester.pump(Duration(milliseconds: level.axes.waitMs + 500));
          await tester.pump(const Duration(milliseconds: 500));
          if (cycle == 2 && shots) await expectLater(find.byType(TurnScreen), matchesGoldenFile('shots/pe-rand-$device.png'));
          // Rândul copilului: pune cubul.
          await tester.tap(tray);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 100));
          if (b + 2 < level.axes.blocks) {
            expect(find.byKey(const ValueKey('turn-pass')), findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('turn-pass')));
          }
          await tester.pump(const Duration(milliseconds: 600));
          cycle++;
        }
        // Turnul gata: sărbătoare, apoi turnul următor începe cu rândul lui Licurici.
        await tester.pump(const Duration(milliseconds: 3600));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      expect(tester.takeException(), isNull);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.length, cycle);
      expect(trials.first.offTargetTaps, 1);
      expect(trials.first.correct, isFalse);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
