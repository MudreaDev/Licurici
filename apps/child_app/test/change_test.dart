import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/change/change_screen.dart';
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

  for (final (device, level) in [('telefon-mic', 12), ('tableta', 7)]) {
    testWidgets('ce s-a schimbat: nivelul $level pe $device', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      container.read(changeLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/c',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/c', builder: (_, _) => const ChangeScreen(seed: 5)),
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
      final l = const ChangeGame().generate(level, seed: 5);
      for (final (i, r) in l.rounds.indexed) {
        if (shots && i == 0) {
          await tester.pump(const Duration(milliseconds: 500));
          await expectLater(
            find.byType(ChangeScreen),
            matchesGoldenFile('shots/schimbat-$device-privire.png'),
          );
          await tester.pump(Duration(milliseconds: l.axes.lookMs - 500));
        } else {
          await tester.pump(Duration(milliseconds: l.axes.lookMs));
        }
        await tester.pump(const Duration(milliseconds: ChangeLevel.coverMs + 50));
        final disappear = r.kind == ChangeKind.disappear;
        String key(ObjectWord o) =>
            disappear ? 'change-option-${o.emoji}' : 'change-item-${o.emoji}';
        if (i == 0) {
          // O greșeală: un obiect care nu s-a schimbat.
          final wrong = disappear
              ? r.options.firstWhere((o) => o != r.target)
              : r.after.firstWhere((it) => it.object != r.target).object;
          await tester.tap(find.byKey(ValueKey(key(wrong))));
          await tester.pump(const Duration(milliseconds: 200));
        }
        if (shots && disappear) {
          await expectLater(
            find.byType(ChangeScreen),
            matchesGoldenFile('shots/schimbat-$device-disparut.png'),
          );
        }
        await tester.tap(find.byKey(ValueKey(key(r.target))));
        await tester.pump(const Duration(milliseconds: 1600));
      }
      await settle(tester, 3);
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
