// Capturi reale pentru pagina de prezentare, fără date personale.
// flutter test --no-pub --update-goldens --dart-define=SHOTS=true test/landing_shots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/games/stacking/stacking_screen.dart';
import 'package:licurici/features/games/mirror/mirror_screen.dart';
import 'package:licurici/features/games/paint_by_ear/paint_by_ear_screen.dart';
import 'package:licurici/shared/mascot_layers.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';
import 'layout_test.dart' show loadFonts, settle, settleUntil, shots;

void main() {
  setUpAll(() async {
    await loadFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await IllustrationIndex.load();
    // Resolve the asset probe outside the widget test's fake async zone.
    // Otherwise an early failed probe can cache the fallback mascot.
    expect(await MascotRig.available(), isTrue);
  });
  final screens = <String, Widget Function()>{
    'emotions': () => ChoiceGameScreen(game: gameById('cum-se-simte')!),
    'language': () => ChoiceGameScreen(game: gameById('unde-e-ursul')!),
    'tower': () => const StackingScreen(seed: 2),
    'mirror': () => const MirrorScreen(seed: 2),
    'painting': () => const PaintByEarScreen(seed: 2),
  };
  for (final entry in screens.entries) {
    testWidgets('landing ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/t', builder: (_, _) => entry.value()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(calm: false),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester, 25);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/landing-${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }, skip: !shots);
  }
  testWidgets('landing home', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceProvider.overrideWithValue(const SilentSpeaker()),
          voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
        ],
        child: const LicuriciApp(),
      ),
    );
    await settleUntil(tester, find.byKey(const ValueKey('domain-ATN')));
    await settle(tester, 25);
    expect(
      find.byType(LayeredMascot),
      findsWidgets,
      reason: 'Captura trebuie să conțină mascota pictată, nu rezerva veche.',
    );
    await expectLater(
      find.byType(LicuriciApp),
      matchesGoldenFile('shots/landing-home.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }, skip: !shots);
}
