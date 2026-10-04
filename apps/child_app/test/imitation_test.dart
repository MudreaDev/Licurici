import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/imitation/imitation_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

Future<ProviderContainer> _open(WidgetTester tester, Size size, int level) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
  );
  addTearDown(container.dispose);
  container.read(imitationLevelProvider.notifier).setLevel(level);
  final router = GoRouter(
    initialLocation: '/i',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
      GoRoute(path: '/i', builder: (_, _) => const ImitationScreen(seed: 4)),
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
  return container;
}

/// Așteaptă până e rândul copilului.
Future<void> _waitTurn(WidgetTester tester) async {
  for (var i = 0; i < 80 && find.text('Rândul tău').evaluate().isEmpty; i++) {
    await settle(tester, 1);
  }
  expect(find.text('Rândul tău'), findsOneWidget);
}

Future<void> _do(WidgetTester tester, ImitationAction a) async {
  final obj = find.byKey(ValueKey('imitation-object-${a.target}'));
  if (a.kind == ImitationKind.tap) {
    await tester.tap(obj);
  } else {
    final from = tester.getCenter(obj);
    final to = tester.getCenter(find.byKey(const ValueKey('imitation-basket')));
    await tester.dragFrom(from, to - from);
  }
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 9), ('tableta', 4)]) {
    testWidgets('fă ca Licurici: nivelul $level pe $device', (tester) async {
      final container = await _open(tester, devices[device]!, level);
      final l = const ImitationGame().generate(level, seed: 4);
      for (final (ri, round) in l.rounds.indexed) {
        await _waitTurn(tester);
        if (shots && ri == 0) {
          await expectLater(
            find.byType(ImitationScreen),
            matchesGoldenFile('shots/imitatie-$device.png'),
          );
        }
        // Prima rundă: întâi o greșeală (alt obiect), apoi corect.
        if (ri == 0) {
          final wrong = (round.actions.first.target + 1) % round.objects.length;
          await tester.tap(find.byKey(ValueKey('imitation-object-$wrong')));
          await tester.pump(const Duration(milliseconds: 200));
        }
        for (final a in round.actions) {
          await _do(tester, a);
        }
        await settle(tester, 10);
      }
      await settle(tester, 4);
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(4));
      expect(trials.first.correct, isFalse);
      expect(trials.skip(1).every((t) => t.correct), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
