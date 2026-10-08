import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/parent/child_games_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show loadFonts, shots;

void main() {
  setUpAll(loadFonts);

  test('jocurile scoase se păstrează în setări; cel puțin un joc rămâne', () {
    final s = const AppSettings().copyWith(hiddenGames: {'pescarul', 'simon'});
    final back = AppSettings.fromJson(s.toJson());
    expect(back.hiddenGames, {'pescarul', 'simon'});
    expect(back.visibleGames.contains('pescarul'), isFalse);
    expect(back.visibleGames.length, catalog.length - 2);
    // Setările vechi (fără câmp) = toate jocurile.
    expect(AppSettings.fromJson(const {}).visibleGames.length, catalog.length);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(settingsProvider.notifier);
    n.setGamesVisible(catalog.map((e) => e.id), false);
    expect(container.read(settingsProvider).visibleGames, isNotEmpty);
  });

  test('nivelul fiecărui joc se păstrează: data viitoare copilul pornește de unde a rămas', () {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    final p = NotifierProvider<GameLevel, int>(() => GameLevel('semaforul'));
    expect(c1.read(p), 1);
    c1.read(p.notifier).setLevel(4);
    final saved = AppSettings.fromJson(c1.read(settingsProvider).toJson());
    expect(saved.levels['semaforul'], 4);
    // O pornire nouă a aplicației, cu setările salvate.
    final c2 = ProviderContainer(overrides: [settingsProvider.overrideWith(() => SettingsNotifier(saved))]);
    addTearDown(c2.dispose);
    expect(c2.read(p), 4);
    // Planul de pe server poate fixa nivelul de pornire.
    c2.read(settingsProvider.notifier).applyPlan(const {}, const {'semaforul': 2}, DateTime.utc(2026, 10, 9));
    expect(c2.read(settingsProvider).levels['semaforul'], 2);
  });

  testWidgets('adultul scoate o arie și un joc; copilul nu le mai vede', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(calm: false), home: const ChildGamesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('domain-switch-ATN')));
    await tester.pumpAndSettle();
    final atn = catalogByDomain()[Domain.atn]!;
    expect(container.read(settingsProvider).hiddenGames, containsAll(atn.map((g) => g.id)));
    expect(catalogByDomain(only: container.read(settingsProvider).visibleGames).containsKey(Domain.atn), isFalse);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('game-pescarul')), 300);
    await tester.tap(find.byKey(const ValueKey('game-pescarul')));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).visibleGames.contains('pescarul'), isFalse);
    if (shots) await expectLater(find.byType(ChildGamesScreen), matchesGoldenFile('shots/jocurile-copilului.png'));

    // Și înapoi: aria pornită din nou.
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('domain-switch-ATN')));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).visibleGames, containsAll(atn.map((g) => g.id)));
  });
}
