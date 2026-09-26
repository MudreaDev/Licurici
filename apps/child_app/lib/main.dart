import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import 'app/theme.dart';
import 'features/games/choice/choice_game_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings.dart';

void main() => runApp(const ProviderScope(child: LicuriciApp()));

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/joc/:id',
      redirect: (context, state) => gameById(state.pathParameters['id']!) == null ? '/' : null,
      builder: (context, state) => ChoiceGameScreen(game: gameById(state.pathParameters['id']!)!),
    ),
  ],
);

class LicuriciApp extends ConsumerWidget {
  const LicuriciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calm = ref.watch(settingsProvider.select((s) => s.calm));
    return MaterialApp.router(
      title: 'Licurici',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(calm: calm),
      routerConfig: _router,
    );
  }
}
