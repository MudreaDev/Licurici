import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/wait/wait_screen.dart';
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

  for (final game in waitGames) {
    for (final device in ['telefon-mic', 'tableta']) {
      testWidgets(
        '${game.id}: prea devreme se numără, la semnal e corect ($device)',
        (tester) async {
          tester.view.physicalSize = devices[device]!;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final container = ProviderContainer(
            overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
          );
          addTearDown(container.dispose);
          container.read(waitLevelProvider(game.id).notifier).setLevel(5);
          final router = GoRouter(
            initialLocation: '/s',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Acasă')),
              ),
              GoRoute(
                path: '/s',
                builder: (_, _) => WaitScreen(game: game, seed: 2),
              ),
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
          final level = game.generate(5, seed: 2);
          final field = find.byKey(const ValueKey('wait-field'));
          // Instrucțiunea, apoi prima încercare.
          await tester.pump(const Duration(milliseconds: 2600));
          for (final (i, t) in level.trials.indexed) {
            if (i == 0) {
              await tester.pump(const Duration(milliseconds: 200));
              await tester.tap(field); // prea devreme
              await tester.pump(Duration(milliseconds: t.waitMs - 200 + 50));
            } else {
              await tester.pump(Duration(milliseconds: t.waitMs + 50));
            }
            expect(find.text('Acum!'), findsOneWidget);
            if (shots && i == 0) {
              await expectLater(
                find.byType(WaitScreen),
                matchesGoldenFile('shots/${game.id}-$device.png'),
              );
            }
            await tester.tap(field);
            await tester.pump(const Duration(milliseconds: 900));
            await tester.pump(const Duration(milliseconds: 900));
          }
          await settle(tester, 3);
          expect(find.byType(RewardFinish), findsOneWidget);
          final trials = container.read(sessionProvider)!.trials;
          expect(trials, hasLength(level.trials.length));
          expect(trials.first.offTargetTaps, 1);
          expect(trials.first.correct, isFalse);
          expect(trials.skip(1).every((t) => t.correct), isTrue);
          expect(
            trials.every((t) => t.gameId == game.id && t.stepId == 'FEX1'),
            isTrue,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 10));
        },
      );
    }
  }
}
