import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/calm/breathing_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  testWidgets(
    'Respiră: trei cicluri ghidate, apoi „Bravo!”; folosirea se notează',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        ],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).start();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildTheme(calm: false),
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const BreathingScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('breathe-start')));
      await tester.pump();
      expect(find.text('Inspiră…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Ține…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Expiră…'), findsOneWidget);
      for (var i = 0; i < 3 * 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Bravo!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final events = container.read(sessionProvider)!.events;
      expect(events.single.kind, SessionEventKind.breathing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
