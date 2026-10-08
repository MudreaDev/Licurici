import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/listen/listen_screen.dart';
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
    testWidgets('ascultă și fă: pașii în ordine; o greșeală = ajutor; se înregistrează ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(listenLevelProvider.notifier).setLevel(7); // 3 pași, 5 obiecte
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/s', builder: (_, _) => const ListenScreen(seed: 6)),
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
      await tester.pump(const Duration(milliseconds: 2500));
      final level = const InstructionGame().generate(7, seed: 6);
      for (final (i, r) in level.rounds.indexed) {
        if (i == 0) {
          // O greșeală întâi: un obiect care nu e cerut.
          final wrong = List.generate(r.table.length, (k) => k).firstWhere((k) => !r.order.contains(k));
          await tester.tap(find.byKey(ValueKey('listen-$wrong')));
          await tester.pump(const Duration(milliseconds: 300));
        }
        for (final (j, k) in r.order.indexed) {
          await tester.tap(find.byKey(ValueKey('listen-$k')));
          await tester.pump(const Duration(milliseconds: 200));
          if (i == 1 && j == 1 && shots) await expectLater(find.byType(ListenScreen), matchesGoldenFile('shots/asculta-$device.png'));
        }
        await tester.pump(const Duration(milliseconds: 1600));
      }
      await settle(tester, 3);
      expect(find.byType(RewardFinish), findsOneWidget);
      expect(tester.takeException(), isNull);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.length, level.rounds.length);
      expect(trials.first.correct, isFalse);
      expect(trials.first.promptLevel, PromptLevel.p2);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
