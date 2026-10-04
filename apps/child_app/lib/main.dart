import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import 'app/boot.dart';
import 'app/theme.dart';
import 'data/local_db.dart';
import 'data/session.dart';
import 'features/domain/domain_screen.dart';
import 'features/games/calm/breathing_screen.dart';
import 'features/games/choice/choice_game_screen.dart';
import 'features/games/memory/memory_screen.dart';
import 'features/games/shell/shell_screen.dart';
import 'features/games/aac/aac_screen.dart';
import 'features/games/feed/feed_screen.dart';
import 'features/games/gaze/gaze_screen.dart';
import 'features/games/imitation/imitation_screen.dart';
import 'features/games/order/order_screen.dart';
import 'features/games/rhythm/rhythm_screen.dart';
import 'features/games/rules/switch_screen.dart';
import 'features/games/search/search_screen.dart';
import 'features/games/sort/sort_screen.dart';
import 'features/games/trace/trace_screen.dart';
import 'features/games/wait/wait_screen.dart';
import 'features/games/reaction/reaction_game_screen.dart';
import 'features/album/album_screen.dart';
import 'features/home/home_screen.dart';
import 'features/parent/parent_screen.dart';
import 'features/games/sequence/simon_screen.dart';
import 'features/settings/settings.dart';

/// Cheia setărilor copilului în tabela `meta`.
const settingsKey = 'settings';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Jocul se joacă doar în landscape (și în manifestul Android / Info.plist iOS).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Ecran complet: fără bare de sistem, ca copilul să nu iasă din aplicație din greșeală.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Sesiunile și setările se păstrează pe dispozitiv (Drift, ADR-004). Pe web (doar
  // previzualizare) Drift ar cere sqlite3.wasm + worker; acolo rămân în memorie.
  final db = kIsWeb ? null : LocalDb();
  var settings = const AppSettings();
  try {
    final raw = await db?.readMeta(settingsKey);
    if (raw != null) {
      settings = AppSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    }
  } on Object {
    // Setări ilizibile → pornim cu cele implicite; copilul nu trebuie să vadă o eroare.
  }
  runApp(
    ProviderScope(
      overrides: [
        if (db != null) ...[
          sessionStoreProvider.overrideWithValue(DriftSessionStore(db)),
          settingsProvider.overrideWith(
            () => SettingsNotifier(
              settings,
              (s) => db.writeMeta(settingsKey, jsonEncode(s.toJson())),
            ),
          ),
        ],
      ],
      child: const LicuriciApp(),
    ),
  );
}

Domain? _domainOf(String code) {
  for (final d in catalogByDomain().keys) {
    if (d.code.toLowerCase() == code.toLowerCase()) return d;
  }
  return null;
}

/// Trecerea între ecrane: o estompare scurtă cu o mică apropiere, fără glisări bruște.
/// Fără animații (reduce motion) — schimbare instantanee.
Page<void> _fade(BuildContext context, GoRouterState state, Widget child) {
  final off = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: off ? Duration.zero : const Duration(milliseconds: 320),
    reverseTransitionDuration: off
        ? Duration.zero
        : const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Routerul aparține instanței aplicației (nu e global): fiecare ProviderScope are
/// propria stare de navigare — important în teste și la repornirea aplicației.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fade(context, state, const HomeScreen()),
      ),
      GoRoute(
        path: '/album',
        pageBuilder: (context, state) =>
            _fade(context, state, const AlbumScreen()),
      ),
      GoRoute(
        path: '/arie/:code',
        redirect: (context, state) =>
            _domainOf(state.pathParameters['code']!) == null ? '/' : null,
        pageBuilder: (context, state) => _fade(
          context,
          state,
          DomainScreen(domain: _domainOf(state.pathParameters['code']!)!),
        ),
      ),
      GoRoute(
        path: '/secventa/simon',
        pageBuilder: (context, state) =>
            _fade(context, state, const SimonScreen()),
      ),
      GoRoute(
        path: '/reactie/:id',
        redirect: (context, state) =>
            reactionGameById(state.pathParameters['id']!) == null ? '/' : null,
        pageBuilder: (context, state) => _fade(
          context,
          state,
          ReactionGameScreen(
            key: ValueKey(state.pathParameters['id']),
            game: reactionGameById(state.pathParameters['id']!)!,
          ),
        ),
      ),
      GoRoute(
        path: '/cucu-bau',
        pageBuilder: (context, state) =>
            _fade(context, state, const ShellScreen()),
      ),
      GoRoute(
        path: '/respira',
        pageBuilder: (context, state) =>
            _fade(context, state, const BreathingScreen()),
      ),
      GoRoute(
        path: '/sortam',
        pageBuilder: (context, state) =>
            _fade(context, state, const SortScreen()),
      ),
      GoRoute(
        path: '/ordine/:id',
        redirect: (context, state) =>
            orderGameById(state.pathParameters['id']!) == null ? '/' : null,
        pageBuilder: (context, state) => _fade(
          context,
          state,
          OrderScreen(
            key: ValueKey(state.pathParameters['id']),
            game: orderGameById(state.pathParameters['id']!)!,
          ),
        ),
      ),
      GoRoute(
        path: '/fa-ca-licuriciul',
        pageBuilder: (context, state) =>
            _fade(context, state, const ImitationScreen()),
      ),
      GoRoute(
        path: '/regula-se-schimba',
        pageBuilder: (context, state) =>
            _fade(context, state, const SwitchScreen()),
      ),
      GoRoute(
        path: '/unde-se-uita',
        pageBuilder: (context, state) =>
            _fade(context, state, const GazeScreen()),
      ),
      GoRoute(
        path: '/hraneste-pestii',
        pageBuilder: (context, state) =>
            _fade(context, state, const FeedScreen()),
      ),
      GoRoute(
        path: '/toba-magica',
        pageBuilder: (context, state) =>
            _fade(context, state, const RhythmScreen()),
      ),
      GoRoute(
        path: '/vorbeste',
        pageBuilder: (context, state) =>
            _fade(context, state, const AacScreen()),
      ),
      GoRoute(
        path: '/cauta',
        pageBuilder: (context, state) =>
            _fade(context, state, const SearchScreen()),
      ),
      GoRoute(
        path: '/semaforul',
        pageBuilder: (context, state) =>
            _fade(context, state, const WaitScreen()),
      ),
      GoRoute(
        path: '/traseaza',
        pageBuilder: (context, state) =>
            _fade(context, state, const TraceScreen()),
      ),
      GoRoute(
        path: '/perechi',
        pageBuilder: (context, state) =>
            _fade(context, state, const MemoryScreen()),
      ),
      GoRoute(
        path: '/parinte',
        pageBuilder: (context, state) =>
            _fade(context, state, const ParentScreen()),
      ),
      GoRoute(
        path: '/joc/:id',
        redirect: (context, state) =>
            gameById(state.pathParameters['id']!) == null ? '/' : null,
        pageBuilder: (context, state) => _fade(
          context,
          state,
          ChoiceGameScreen(game: gameById(state.pathParameters['id']!)!),
        ),
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
      // Listele se derulează și trăgând cu mouse-ul / trackpad-ul (web, Chromebook),
      // nu doar cu degetul.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          BootGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
