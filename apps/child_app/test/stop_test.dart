import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/stop/stop_screen.dart';
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
    testWidgets('Stop!: atinge la verde, se oprește la roșu ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/s', builder: (_, _) => const StopScreen(seed: 3)),
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
      await tester.tap(find.byKey(const ValueKey('stop-ready')));
      await tester.pump();
      final level = const StopSignalGame().generate(1, seed: 3);
      final lantern = find.byKey(const ValueKey('stop-lantern'));
      String label() => tester.getSemantics(lantern).label;
      final handle = tester.ensureSemantics();
      for (var i = 0; i < level.stops.length; i++) {
        // Așteaptă aprinderea.
        for (var k = 0; k < 40 && label().contains('stins'); k++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (shots && i == 0) await expectLater(find.byType(StopScreen), matchesGoldenFile('shots/stop-$device.png'));
        if (level.stops[i]) {
          // Încercare cu oprire: așteaptă roșul și nu atinge.
          await tester.pump(Duration(milliseconds: level.axes.windowMs + 50));
        } else {
          await tester.pump(const Duration(milliseconds: 150));
          await tester.tap(find.byKey(const ValueKey('stop-field')));
          await tester.pump();
        }
      }
      handle.dispose();
      await settle(tester, 4);
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials, hasLength(level.stops.length));
      expect(trials.every((t) => t.correct), isTrue, reason: 'a atins doar la verde');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
