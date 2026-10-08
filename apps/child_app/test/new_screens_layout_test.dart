import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/coloring/color_play_screen.dart';
import 'package:licurici/features/coloring/drawings_store.dart';
import 'package:licurici/features/games/listen/listen_screen.dart';
import 'package:licurici/features/games/sequence/simon_screen.dart';
import 'package:licurici/features/games/turns/turn_screen.dart';
import 'package:licurici/features/games/write/write_screen.dart';
import 'package:licurici/features/map/lantern_map_screen.dart';
import 'package:licurici/features/parent/child_games_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle;

/// Ecranele noi (sesiunea a noua), pe toate dimensiunile de ecran: nicio depășire de layout.
void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  final screens = <String, Widget Function()>{
    'scriem-cifrele': () => const WriteScreen(game: writeDigits, seed: 1),
    'scriem-literele': () => const WriteScreen(game: writeLetters, seed: 1),
    'asculta-si-fa': () => const ListenScreen(seed: 1),
    'pe-rand': () => const TurnScreen(seed: 1),
    'licuricii': () => const SimonScreen(game: SpatialSpanGame(), initialLevel: 12),
    'coloram': () => const ColorPlayScreen(),
    'harta': () => const LanternMapScreen(),
    'jocurile-copilului': () => const ChildGamesScreen(),
  };

  for (final MapEntry(key: device, value: size) in devices.entries) {
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets('$name pe $device: fără depășiri', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer(
          overrides: [
            voiceProvider.overrideWithValue(const SilentSpeaker()),
            drawingStoreProvider.overrideWithValue(MemoryDrawingStore()),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/s',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
            GoRoute(path: '/s', builder: (_, _) => build()),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
          ),
        );
        await settle(tester, 4);
        await tester.pump(const Duration(seconds: 4)); // primele runde / cuburi
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      });
    }
  }
}
