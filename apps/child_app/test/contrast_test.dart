import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/ui/candy.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show loadFonts, settle, shots;

BoxDecoration? _decoration(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(of: find.byKey(const ValueKey('btn')), matching: find.byType(AnimatedContainer)),
  );
  return box.decoration as BoxDecoration?;
}

void main() {
  setUpAll(loadFonts);

  test('contrastul mare se păstrează în setări', () {
    final s = AppSettings.fromJson(const AppSettings(contrast: true).toJson());
    expect(s.contrast, isTrue);
    expect(AppSettings.fromJson(const {}).contrast, isFalse);
  });

  Widget button({bool contrast = false, bool system = false}) => ProviderScope(
    key: ValueKey('$contrast-$system'),
    overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(AppSettings(contrast: contrast))),
    ],
    child: MediaQuery(
      data: MediaQueryData(highContrast: system),
      child: MaterialApp(
        home: Center(
          child: CandyPressable(
            key: const ValueKey('btn'),
            color: Tokens.primary,
            onTap: () {},
            child: const Text('Joacă'),
          ),
        ),
      ),
    ),
  );

  testWidgets('tot ce se apasă primește contur închis: ales de adult sau cerut de sistem', (tester) async {
    await tester.pumpWidget(button());
    expect(_decoration(tester)!.border, isNull);
    await tester.pumpWidget(button(contrast: true));
    expect((_decoration(tester)!.border! as Border).top.color, Tokens.contrastEdge);
    await tester.pumpWidget(button(system: true));
    expect((_decoration(tester)!.border! as Border).top.width, 3);
  });

  testWidgets('un joc în contrast mare (captură)', (tester) async {
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
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          settingsProvider.overrideWith(() => SettingsNotifier(const AppSettings(contrast: true))),
        ],
        child: MaterialApp.router(
          theme: buildTheme(calm: false, contrast: true),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester, 4);
    expect(tester.takeException(), isNull);
    if (shots) await expectLater(find.byType(Router<Object>), matchesGoldenFile('shots/contrast-tableta.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
