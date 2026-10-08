import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/write/write_screen.dart';
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

  for (final game in writingGames) {
    for (final device in ['telefon-mic', 'tableta']) {
      testWidgets('${game.id}: scrie semnele trăsătură cu trăsătură, apoi finalul ($device)', (tester) async {
        tester.view.physicalSize = devices[device]!;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
        addTearDown(container.dispose);
        container.read(writeLevelProvider(game.id).notifier).setLevel(5);
        final router = GoRouter(
          initialLocation: '/s',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
            GoRoute(path: '/s', builder: (_, _) => WriteScreen(game: game, seed: 3)),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
          ),
        );
        await settle(tester, 2);
        final level = game.generate(5, seed: 3);
        final field = find.byKey(const ValueKey('write-field'));
        expect(field, findsOneWidget);
        // Fără nicio atingere 6 s: steluța arată singură trăsătura (modelul).
        expect(find.byKey(const ValueKey('write-demo')), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const ValueKey('write-demo')), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        for (final (i, g) in level.glyphs.indexed) {
          final box = tester.getRect(field);
          final paths = g.fit(box.width / box.height, height: 0.78);
          for (final (k, p) in paths.indexed) {
            Offset at(int j) => box.topLeft + Offset(p.points[j].x * box.width, p.points[j].y * box.height);
            final gesture = await tester.startGesture(at(0));
            for (var j = 1; j < p.points.length; j += 2) {
              await gesture.moveTo(at(j));
            }
            await gesture.moveTo(at(p.points.length - 1));
            await gesture.up();
            await tester.pump(const Duration(milliseconds: 50));
            if (i == 0 && k == 0 && shots) {
              await expectLater(find.byType(WriteScreen), matchesGoldenFile('shots/${game.id}-$device.png'));
            }
          }
          await tester.pump(const Duration(milliseconds: 2000));
        }
        await settle(tester, 3);
        expect(find.byType(RewardFinish), findsOneWidget);
        expect(tester.takeException(), isNull);
        final trials = container.read(sessionProvider)!.trials;
        expect(trials.length, level.glyphs.length);
        expect(trials.every((t) => t.correct), isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      });
    }
  }
}
