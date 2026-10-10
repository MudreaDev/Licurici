import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/games/rhythm/rhythm_screen.dart';
import 'package:licurici/features/games/search/search_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/nothing_to_show.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show loadFonts, settle;

void main() {
  setUpAll(loadFonts);

  Future<int> totalRounds(WidgetTester tester, AppSettings settings) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/s',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/s', builder: (_, _) => ChoiceGameScreen(game: gameById('emotii')!)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          settingsProvider.overrideWith(() => SettingsNotifier(settings)),
        ],
        child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
      ),
    );
    await settle(tester, 3);
    final total = tester.widget<ProgressDots>(find.byType(ProgressDots)).total;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    return total;
  }

  testWidgets('specialistul alege mai puține runde: tura se scurtează; fără alegere, cât dă nivelul', (tester) async {
    final normal = await totalRounds(tester, const AppSettings(levels: {'emotii': 9}));
    expect(normal, greaterThan(3));
    expect(await totalRounds(tester, const AppSettings(levels: {'emotii': 9}, rounds: {'emotii': 3})), 3);
    // Persistă la repornire.
    expect(AppSettings.fromJson(const AppSettings(rounds: {'emotii': 3}).toJson()).rounds, {'emotii': 3});
  });

  testWidgets('imaginile de evitat nu apar în joc; dacă jocul n-are altceva, ecran liniștit cu drumul acasă', (tester) async {
    // „Emoții” fără fețe furioase: rundele rămase nu le arată.
    expect(await totalRounds(tester, const AppSettings(levels: {'emotii': 3}, avoid: {'fete-furioase'})), greaterThan(0));
    final s = const AppSettings(avoid: {'caini'});
    expect(AppSettings.fromJson(s.toJson()).avoid, {'caini'});
  });

  test('alegerea de pe tabletă contează ca schimbare de plan (pleacă la sincronizare)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(settingsProvider.notifier).setAvoid('insecte', true);
    expect(c.read(settingsProvider).avoid, {'insecte'});
    expect(c.read(settingsProvider).hiddenGamesAt, isNotNull);
    c.read(settingsProvider.notifier).setAvoid('insecte', false);
    expect(c.read(settingsProvider).avoid, isEmpty);
  });

  group('imaginile de evitat în celelalte mecanici', () {
    Future<void> pump(WidgetTester tester, Widget screen, AppSettings settings) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/s', builder: (_, _) => screen),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            settingsProvider.overrideWith(() => SettingsNotifier(settings)),
          ],
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settle(tester, 3);
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }

    testWidgets('Caută nu pune pe ecran nimic de evitat', (tester) async {
      const ids = {'caini', 'pisici', 'insecte', 'animale-mari', 'baloane'};
      final avoid = avoidedEmojis(ids);
      for (final seed in [1, 2, 3]) {
        await pump(tester, SearchScreen(seed: seed), const AppSettings(avoid: ids));
        final shown = tester.widgetList<StimulusArt>(find.byType(StimulusArt)).map((a) => a.emoji).toList();
        expect(shown, isNotEmpty);
        expect(shown.where((e) => isAvoided(e, avoid)), isEmpty, reason: 'seed $seed');
        await close(tester);
      }
    });

    testWidgets('Toba magică, cu „Tobe și zgomote” de evitat: ecran liniștit, fără tobă', (tester) async {
      await pump(tester, const RhythmScreen(seed: 1), const AppSettings(avoid: {'tobe'}));
      expect(find.text('Hai la alt joc!'), findsOneWidget);
      expect(find.byType(NothingToShow), findsOneWidget);
      await close(tester);
      await pump(tester, const RhythmScreen(seed: 1), const AppSettings());
      expect(find.byType(NothingToShow), findsNothing);
      await close(tester);
    });
  });
}
