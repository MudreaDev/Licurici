import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/sort/sort_screen.dart';
import 'package:licurici/shared/drawn_face.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';
import 'praise_finders.dart';

void main() {
  // Jocurile „frate” (aceeași mecanică, alt material): la nivelul cel mai încărcat (4 × 4),
  // pe telefonul mic, fără depășiri; fețele desenate apar.
  for (final game in sortGames) {
    testWidgets('${game.id} la nivelul maxim, pe telefonul mic', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        ],
      );
      addTearDown(container.dispose);
      container.read(sortLevelProvider(game.id).notifier).setLevel(12);
      final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => SortScreen(game: game, seed: 3))]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildTheme(calm: true),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(game.categories.where((b) => find.text(b.name).evaluate().isNotEmpty), isNotEmpty);
      if (game.id == 'sortam-emotiile') expect(find.byType(DrawnFace), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in const [Size(1280, 800), Size(640, 360)]) {
    testWidgets(
      'Sortăm ${size.width.toInt()}×${size.height.toInt()}: trage greșit (rămâne), '
      'trage corect, atinge-atinge, apoi finalul',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const seed = 5;
        final level = const SortGame().generate(1, seed: seed);
        final container = ProviderContainer(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            sessionStoreProvider.overrideWithValue(MemorySessionStore()),
          ],
        );
        addTearDown(container.dispose);
        container.read(sessionProvider.notifier).start();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SortScreen(seed: seed),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: buildTheme(calm: true),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 10 &&
              find.byKey(const ValueKey('sort-item-0')).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        Finder item(int i) => find.byKey(ValueKey('sort-item-$i'));
        Finder bin(String id) => find.byKey(ValueKey('sort-bin-$id'));
        Future<void> drag(int i, String binId) async {
          await tester.drag(
            item(i),
            tester.getCenter(bin(binId)) - tester.getCenter(item(i)),
          );
          await tester.pump();
        }

        final first = level.items.first;
        final wrongBin = level.bins.firstWhere((b) => b.id != first.binId).id;
        await drag(0, wrongBin);
        expect(item(0), findsOneWidget); // a rămas pe masă
        await drag(0, first.binId);
        expect(item(0), findsNothing); // e în cutie

        // Atinge-atinge pentru restul (alternativa fără tragere).
        for (final it in level.items.skip(1)) {
          await tester.tap(item(it.index));
          await tester.pump();
          await tester.tap(bin(it.binId));
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 1));
        expect(findFinish(), findsOneWidget);
        expect(tester.takeException(), isNull);

        final trials = container.read(sessionProvider)!.trials;
        expect(trials, hasLength(level.items.length));
        expect(trials.first.correct, isFalse);
        expect(trials.first.chosenId, wrongBin);
        expect(trials.skip(1).every((t) => t.correct), isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
