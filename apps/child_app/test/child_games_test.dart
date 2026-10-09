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

  test('plafonul specialistului: nivelul nu urcă peste el, iar un nivel mai mare coboară la el', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = NotifierProvider<GameLevel, int>(() => GameLevel('semaforul'));
    c.read(p.notifier).setLevel(9);
    expect(c.read(settingsProvider).levels['semaforul'], 9);
    c.read(settingsProvider.notifier).applyPlan(const {}, const {}, DateTime.utc(2026, 10, 9), const {'semaforul': 6});
    expect(c.read(settingsProvider).levels['semaforul'], 6);
    expect(c.read(settingsProvider).levelOf('semaforul'), 6);
    // Jocul adaptiv încearcă să urce: rămâne la plafon.
    c.read(settingsProvider.notifier).setGameLevel('semaforul', 8);
    expect(c.read(settingsProvider).levels['semaforul'], 6);
    // Plafonul se păstrează la repornire.
    final saved = AppSettings.fromJson(c.read(settingsProvider).toJson());
    expect(saved.maxLevels, {'semaforul': 6});
    // Specialistul scoate plafonul: nivelul poate urca din nou.
    c.read(settingsProvider.notifier).applyPlan(const {}, const {}, DateTime.utc(2026, 10, 10), const {});
    c.read(settingsProvider.notifier).setGameLevel('semaforul', 8);
    expect(c.read(settingsProvider).levels['semaforul'], 8);
  });

  test('un joc deschis prima dată pornește de la nivelul transferat de la un joc frate', () {
    final step = ladders.expand((l) => l.steps).firstWhere((s) => s.games.length >= 2);
    final [a, b, ...] = step.games;
    final s = AppSettings(levels: {a: 6}, maxLevels: {b: 3});
    expect(AppSettings(levels: {a: 6}).levelOf(b), 4);
    expect(s.levelOf(b), 3); // plafonul specialistului câștigă
    expect(AppSettings(levels: {a: 6, b: 2}).levelOf(b), 2); // ce a jucat deja rămâne
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
