import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/shell/shell_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';
import 'praise_finders.dart';

void main() {
  for (final (size, levelNo) in const [
    (Size(1280, 800), 6),
    (Size(640, 360), 12),
  ]) {
    testWidgets(
      'Cucu-bau ${size.width.toInt()}×${size.height.toInt()} nivel $levelNo: '
      'paharele se mută, copilul alege, finalul',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const seed = 3;
        final level = const ShellGame().generate(levelNo, seed: seed);
        final container = ProviderContainer(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            sessionStoreProvider.overrideWithValue(MemorySessionStore()),
          ],
        );
        addTearDown(container.dispose);
        container.read(shellLevelProvider.notifier).setLevel(levelNo);
        container.read(sessionProvider.notifier).start();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: buildTheme(calm: true),
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const ShellScreen(seed: seed),
                  ),
                ],
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 20 && find.byKey(const ValueKey('cup-0')).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (var r = 0; r < level.rounds.length; r++) {
          final round = level.rounds[r];
          // Arătare + acoperire + mutări (fiecare mutare = swapMs + o pauză scurtă).
          await tester.pump(const Duration(milliseconds: 2300));
          for (var k = 0; k < round.swaps.length; k++) {
            await tester.pump(Duration(milliseconds: level.axes.swapMs + 10));
            await tester.pump(const Duration(milliseconds: 130));
          }
          await tester.pump();
          // Prima rundă greșit, restul corect: paharul de pe locul răspunsului.
          // Id-ul paharului = locul lui la început; îl urmărim prin mutări.
          final slots = List.generate(level.axes.cups, (i) => i);
          for (final (a, b) in round.swaps) {
            final ca = slots.indexOf(a), cb = slots.indexOf(b);
            slots[ca] = b;
            slots[cb] = a;
          }
          final target = r == 0
              ? (round.answer + 1) % level.axes.cups
              : round.answer;
          await tester.tap(
            find.byKey(ValueKey('cup-${slots.indexOf(target)}')),
          );
          await tester.pump(const Duration(milliseconds: 2000));
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(findFinish(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final trials = container.read(sessionProvider)!.trials;
        expect(trials, hasLength(level.rounds.length));
        expect(trials.first.correct, isFalse);
        expect(trials.skip(1).every((t) => t.correct), isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
