import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/coloring/drawings_store.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/home/home_screen.dart';
import 'package:licurici/features/aquarium/aquarium_screen.dart';
import 'package:licurici/features/games/listen/listen_screen.dart';
import 'package:licurici/features/games/memory/memory_screen.dart';
import 'package:licurici/features/map/lantern_map_screen.dart';
import 'package:licurici/features/parent/child_games_screen.dart';
import 'package:licurici/features/parent/parent_screen.dart';
import 'package:licurici/features/parent/first_steps_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show loadFonts, settle;

/// Accesibilitatea (README §19): ținte de atingere destul de mari, etichete pe tot ce se apasă,
/// contrastul textului. Pe tabletă, în modul obișnuit.
void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  final screens = <String, Widget Function()>{
    'acasă': () => const HomeScreen(),
    'joc cu alegere': () => ChoiceGameScreen(game: gameById('emotii')!),
    'jocurile copilului': () => const ChildGamesScreen(),
    'primii pași': () => const FirstStepsScreen(),
    'pentru părinți': () => const ParentScreen(),
    'acvariul': () => const AquariumScreen(),
    'harta': () => const LanternMapScreen(),
    'ascultă și fă': () => const ListenScreen(seed: 1),
    'perechi': () => const MemoryScreen(seed: 1),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    testWidgets('$name: ținte, etichete, contrast', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/s', builder: (_, _) => build()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            drawingStoreProvider.overrideWithValue(MemoryDrawingStore()),
          ],
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      await settle(tester, 4);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
