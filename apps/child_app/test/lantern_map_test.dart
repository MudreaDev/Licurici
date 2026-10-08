import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/map/lantern_map_screen.dart';
import 'package:licurici/features/settings/settings.dart';
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
    testWidgets('harta: felinarele treptelor stăpânite ard, iar unul nou se sărbătorește o singură dată ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Două trepte stăpânite (două sesiuni la rând, independent, pe două seturi de stimuli)
      // și una doar începută.
      final store = MemorySessionStore();
      Trial t(String step, String game, int i, DateTime at) => Trial(
        stepId: step,
        gameId: game,
        correct: true,
        promptLevel: PromptLevel.p0,
        at: at,
        stimulusId: 's$i',
        stimulusSet: i.isEven ? 'a' : 'b',
      );
      for (var d = 0; d < 2; d++) {
        final start = DateTime(2026, 10, 1 + d, 10);
        await store.save(
          SessionRecord(
            id: 's$d',
            childId: 'c',
            start: start,
            end: start.add(const Duration(minutes: 15)),
            trials: [
              for (var i = 0; i < 12; i++) t('POT1', 'potriveste', i, start),
              for (var i = 0; i < 12; i++) t('EMO1', 'emotii', i, start),
              if (d == 1) t('ATN1', 'prinde-licuriciul', 0, start),
            ],
          ),
        );
      }
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          sessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/harta',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/harta', builder: (_, _) => const LanternMapScreen()),
          GoRoute(path: '/arie/:code', builder: (_, s) => Scaffold(body: Text('Aria ${s.pathParameters['code']}'))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settle(tester, 3);
      final stations = container.read(mapStationsProvider).value!;
      final lit = [for (final s in stations) ...s.lanterns.where((l) => l.$2 == LanternState.lit)];
      expect(lit, isNotEmpty);
      expect(stations.expand((s) => s.lanterns).any((l) => l.$2 == LanternState.glowing), isTrue);
      // Felinarele aprinse s-au „văzut” — data viitoare nu se mai sărbătoresc.
      expect(container.read(settingsProvider).lanternsSeen, lit.length);
      expect(tester.takeException(), isNull);
      // Harta s-a derulat singură la felinarul nou.
      await settle(tester, 6);
      final scroll = tester.widget<SingleChildScrollView>(find.byKey(const ValueKey('map-scroll')));
      expect(scroll.controller!.offset, greaterThan(100));
      if (shots) await expectLater(find.byType(LanternMapScreen), matchesGoldenFile('shots/harta-$device.png'));
      // O stație deschide jocurile ariei.
      final first = stations.first.domain.code;
      await tester.drag(find.byKey(const ValueKey('map-scroll')), const Offset(3000, 0));
      await settle(tester, 1);
      await tester.tap(find.byKey(ValueKey('map-station-$first')));
      await settle(tester, 1);
      expect(find.text('Aria ${first.toLowerCase()}'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
