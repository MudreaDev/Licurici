// Capturi cu ilustrațiile pictate încărcate (celelalte teste le arată cu rezervele: emoji și
// desenele din cod). Doar pentru inspecție vizuală:
//   flutter test --update-goldens --dart-define=SHOTS=true test/art_shots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/games/fitts/fitts_screen.dart';
import 'package:licurici/features/games/mirror/mirror_screen.dart';
import 'package:licurici/features/games/paint_by_ear/paint_by_ear_screen.dart';
import 'package:licurici/features/games/place/place_screen.dart';
import 'package:licurici/features/games/shell/shell_screen.dart';
import 'package:licurici/features/games/sound_memory/sound_memory_screen.dart';
import 'package:licurici/features/games/stacking/stacking_screen.dart';
import 'package:licurici/features/games/stop/stop_screen.dart';
import 'package:licurici/features/games/turns/turn_screen.dart';
import 'package:licurici/features/games/wait/wait_screen.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

void main() {
  setUpAll(() async {
    await loadFonts();
    await IllustrationIndex.load();
  });

  final screens = <String, Widget Function()>{
    'unde-e-ursul': () => ChoiceGameScreen(game: gameById('unde-e-ursul')!),
    'cat-de-tare': () => ChoiceGameScreen(game: gameById('cat-de-tare')!),
    'cine-e-prietenul': () => ChoiceGameScreen(game: gameById('cine-e-prietenul')!),
    'cum-se-simte': () => ChoiceGameScreen(game: gameById('cum-se-simte')!),
    'pune-ursul': () => const PlaceScreen(seed: 2),
    'turnul': () => const StackingScreen(seed: 2),
    'floarea': () => WaitScreen(game: waitGameById('floarea-creste')!, seed: 2),
    'stop': () => const StopScreen(),
    'atinge-rapid': () => const FittsScreen(),
    'pe-rand': () => const TurnScreen(),
    'cucu-bau': () => const ShellScreen(),
    'oglinda': () => const MirrorScreen(seed: 2),
    'coloreaza': () => const PaintByEarScreen(seed: 2),
    'memorie-sunete': () => const SoundMemoryScreen(seed: 2),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    testWidgets('pictat: $name', (tester) async {
      tester.view.physicalSize = devices['tableta']!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/t', builder: (_, _) => build()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
      );
      await settle(tester, 25);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/pictat-$name.png'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }, skip: !shots);
  }
}
