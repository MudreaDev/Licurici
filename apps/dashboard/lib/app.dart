import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_content/game_content.dart' as content;
import 'package:go_router/go_router.dart';
import 'account_page.dart';
import 'api.dart';
import 'email_pages.dart';
import 'import_dialog.dart';
import 'live.dart';
import 'login_page.dart';
import 'parent.dart';
import 'specialist.dart';

GoRouter createRouter({String? initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const RolePage()),
    GoRoute(path: '/autentificare', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/cont', builder: (_, _) => const AccountPage()),
    // Legăturile din e-mailuri (ADR-032).
    GoRoute(
      path: '/confirmare',
      builder: (_, s) => ConfirmEmailPage(key: ValueKey(s.uri), token: s.uri.queryParameters['token'] ?? ''),
    ),
    GoRoute(
      path: '/parola-noua',
      builder: (_, s) => ResetPasswordPage(key: ValueKey(s.uri), token: s.uri.queryParameters['token'] ?? ''),
    ),
    GoRoute(path: '/parinte', builder: (_, _) => const ParentPage()),
    GoRoute(path: '/specialist', builder: (_, _) => const SpecialistPage()),
    GoRoute(
      path: '/specialist/copil/:id',
      builder: (_, s) => SpecialistPage(childId: s.pathParameters['id']),
    ),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Pagina nu există. Înapoi la început'),
      ),
    ),
  ),
);

class DashboardApp extends StatefulWidget {
  const DashboardApp({super.key, this.router});
  final GoRouter? router;
  @override
  State<DashboardApp> createState() => _DashboardAppState();
}

class _DashboardAppState extends State<DashboardApp> {
  late final GoRouter router = widget.router ?? createRouter();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  @override
  void dispose() {
    if (widget.router == null) router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Licurici · Împreună, pas cu pas',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    scaffoldMessengerKey: _messenger,
    // Vestile live (sesiune nouă sincronizată) apar ca notificare pe orice pagină.
    builder: (context, child) => Consumer(
      builder: (context, ref, _) {
        ref.listen(liveNoticeProvider, (_, notice) {
          if (notice == null) return;
          _messenger.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(key: const ValueKey('live-notice'), content: Text(notice.text)));
        });
        return child ?? const SizedBox.shrink();
      },
    ),
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'packages/${content.contentPackage}/${content.fontFamily}',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF466F6B),
        primary: const Color(0xFF466F6B),
        surface: const Color(0xFFFFFDF8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F3ED),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F3ED),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E5DE)),
        ),
      ),
    ),
  );
}

class RolePage extends StatelessWidget {
  const RolePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Licurici'),
      actions: const [ImportButton(), SignInButton()],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Împreună, pas cu pas.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'Un loc pentru a înțelege progresul și a însoți fiecare copil în ritmul lui.',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, c) {
                  final cards = [
                    const _RoleCard(
                      'Sunt părinte',
                      'Momentele de azi, pașii mici și idei pentru acasă.',
                      Icons.favorite_border,
                      '/parinte',
                    ),
                    const _RoleCard(
                      'Sunt specialist',
                      'Observații, sesiuni și progres pe obiective.',
                      Icons.insights,
                      '/specialist',
                    ),
                  ];
                  return c.maxWidth < 600
                      ? Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 20),
                            cards[1],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 24),
                            Expanded(child: cards[1]),
                          ],
                        );
                },
              ),
              const SizedBox(height: 24),
              const Text('Demo cu date inventate · Fără autentificare'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard(this.title, this.description, this.icon, this.route);
  final String title, description, route;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 24),
            const Icon(Icons.arrow_forward),
          ],
        ),
      ),
    ),
  );
}

/// „Conectează-te” (mod demo) sau „Ieși” (după autentificare).
class SignInButton extends ConsumerWidget {
  const SignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn =
        ref.watch(serverChildrenProvider).isNotEmpty ||
        ref.read(apiClientProvider).signedIn;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: signedIn
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const ValueKey('account'),
                  onPressed: () => context.go('/cont'),
                  child: const Text('Contul meu'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(serverChildrenProvider.notifier).signOut(),
                  child: const Text('Ieși'),
                ),
              ],
            )
          : TextButton(
              key: const ValueKey('sign-in'),
              onPressed: () => context.go('/autentificare'),
              child: Text(MediaQuery.sizeOf(context).width < 600 ? 'Conectează-te' : 'Conectează-te · DEMO'),
            ),
    );
  }
}
