import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/parent/child_games_screen.dart';
import 'package:licurici/features/settings/settings.dart';

import 'layout_test.dart' show devices, loadFonts;

void main() {
  setUpAll(loadFonts);

  testWidgets('„Primii pași”: „Încă nu” la litere ascunde jocurile grele, „Da” ridică pornirea', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Copilul a ajuns deja mai sus la „emotii”: propunerea nu îl coboară.
    container.read(settingsProvider.notifier).setGameLevel('emotii', 6);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(calm: false), home: const ChildGamesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('first-steps')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('first-step-emo')), 200);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('first-step-answer-emo')), matching: find.text('Da, singur')));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('first-step-pacl')), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('first-step-answer-pacl')), matching: find.text('Încă nu')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('first-steps-apply')));
    await tester.pumpAndSettle();
    final s = container.read(settingsProvider);
    expect(s.hiddenGames, contains('ortografie'));
    expect(s.hiddenGames, isNot(contains('alfabetul')));
    expect(s.levels['emotii'], 6);
    expect(find.text('Jocurile copilului'), findsOneWidget);
  });

  for (final MapEntry(key: device, value: size) in devices.entries) {
    testWidgets('„Primii pași” pe $device: fără depășiri', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(theme: buildTheme(calm: false), home: const ChildGamesScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('first-steps')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
