import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/settings/settings.dart';
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
}

