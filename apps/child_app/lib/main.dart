import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import 'app/boot.dart';
import 'app/theme.dart';
import 'data/local_db.dart';
import 'data/session.dart';
import 'features/games/choice/choice_game_screen.dart';
import 'features/games/reaction/reaction_game_screen.dart';
import 'features/home/home_screen.dart';
import 'features/parent/parent_screen.dart';
import 'features/games/sequence/simon_screen.dart';
import 'features/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Jocul se joacă doar în landscape (și în manifestul Android / Info.plist iOS).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Ecran complet: fără bare de sistem, ca copilul să nu iasă din aplicație din greșeală.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    ProviderScope(
      // Sesiunile se păstrează pe dispozitiv (Drift, ADR-004). Pe web (doar previzualizare)
      // Drift ar cere sqlite3.wasm + worker; acolo rămân în memorie.
      overrides: [
        if (!kIsWeb)
          sessionStoreProvider.overrideWithValue(DriftSessionStore(LocalDb())),
      ],
      child: const LicuriciApp(),
    ),
  );
}

/// Routerul aparține instanței aplicației (nu e global): fiecare ProviderScope are
/// propria stare de navigare — important în teste și la repornirea aplicației.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/secventa/simon',
        builder: (context, state) => const SimonScreen(),
      ),
      GoRoute(
        path: '/reactie/:id',
        redirect: (context, state) =>
            reactionGameById(state.pathParameters['id']!) == null ? '/' : null,
        builder: (context, state) => ReactionGameScreen(
          key: ValueKey(state.pathParameters['id']),
          game: reactionGameById(state.pathParameters['id']!)!,
        ),
      ),
      GoRoute(
        path: '/parinte',
        builder: (context, state) => const ParentScreen(),
      ),
      GoRoute(
        path: '/joc/:id',
        redirect: (context, state) =>
            gameById(state.pathParameters['id']!) == null ? '/' : null,
        builder: (context, state) =>
            ChoiceGameScreen(game: gameById(state.pathParameters['id']!)!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class LicuriciApp extends ConsumerWidget {
  const LicuriciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calm = ref.watch(settingsProvider.select((s) => s.calm));
    return MaterialApp.router(
      title: 'Licurici',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(calm: calm),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          BootGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
