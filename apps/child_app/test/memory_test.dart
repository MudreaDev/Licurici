import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/memory/memory_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  for (final size in const [Size(1280, 800), Size(640, 360)]) {
    testWidgets(
      'Perechi ${size.width.toInt()}×${size.height.toInt()}: o pereche greșită se întoarce, '
      'jocul se termină cu stele',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const seed = 11;
        final level = const MemoryGame().generate(1, seed: seed);
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
              builder: (_, _) => const MemoryScreen(seed: seed),
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
              find.byKey(const ValueKey('memory-card-0')).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        Future<void> tap(int i) async {
          await tester.tap(find.byKey(ValueKey('memory-card-$i')));
          await tester.pump();
        }

        // O mutare greșită: prima carte + una cu altă față.
        final wrong = level.cards.indexWhere((c) => c != level.cards[0]);
        await tap(0);
        await tap(wrong);
        await tester.pump(
          const Duration(milliseconds: 1200),
        ); // se întorc la loc

        // Apoi toate perechile, corect.
        for (final face in level.art) {
          final a = level.cards.indexOf(face);
          await tap(a);
          await tap(level.cards.indexOf(face, a + 1));
        }
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Ai terminat! Bravo!'), findsOneWidget);
        expect(find.text('Mai departe'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final trials = container.read(sessionProvider)!.trials;
        expect(trials, hasLength(level.pairs + 1));
        expect(trials.first.correct, isFalse);
        expect(trials.where((t) => t.correct), hasLength(level.pairs));
        expect(trials.every((t) => t.stepId == 'FEX5'), isTrue);

        await tester.tap(find.text('Mai departe'));
        await tester.pump();
        expect(container.read(memoryLevelProvider), greaterThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
