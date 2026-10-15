import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/sound_memory/sound_memory_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 2), ('tableta', 5), ('telefon-mic', 7)]) {
    testWidgets('Memorie cu sunete: nivelul $level pe $device, o pereche greșită, apoi toate', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(soundMemoryLevelProvider.notifier).setLevel(level);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => const SoundMemoryScreen(seed: 3)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await settle(tester, 2);
      if (shots) await expectLater(find.byType(SoundMemoryScreen), matchesGoldenFile('shots/memorie-sunete-$device-$level.png'));
      final l = const SoundMemoryGame().generate(level, seed: 3);
      final cards = l.cards;
      final s0 = cards.indexWhere((c) => c.isSound);
      final wrong = cards.indexWhere((c) => !c.isSound && !c.matches(cards[s0]));
      await tester.tap(find.byKey(ValueKey('sound-card-$s0')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ValueKey('sound-card-$wrong')));
      await tester.pump(const Duration(milliseconds: 2000));
      for (var i = 0; i < cards.length; i++) {
        if (!cards[i].isSound) continue;
        await tester.tap(find.byKey(ValueKey('sound-card-$i')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        if (shots && i == s0) await expectLater(find.byType(SoundMemoryScreen), matchesGoldenFile('shots/memorie-sunete-intoarsa-$device-$level.png'));
        await tester.tap(find.byKey(ValueKey('sound-card-${cards.indexWhere((c) => c.matches(cards[i]))}')));
        await tester.pump(const Duration(milliseconds: 600));
      }
      await settle(tester, 10);
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.map((t) => t.correct), [false, for (var k = 0; k < l.pairs; k++) true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
