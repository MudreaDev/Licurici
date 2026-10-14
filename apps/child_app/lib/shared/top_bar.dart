import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../app/nav_memory.dart';
import '../app/theme.dart';
import '../features/settings/settings.dart';
import 'ui/candy.dart';

/// Bara de sus — identică și fixă pe fiecare ecran (principiul 5 din §2). Butoane rotunde,
/// fiecare cu culoarea lui (o culoare = un sens): acasă albastru, vocea galben, calm lavandă.
class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.title, this.trailing});

  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final path = GoRouterState.of(context).uri.path;
    final atHome = path == '/';
    // Dintr-un joc, butonul duce înapoi în lista din care a pornit copilul (aceeași
    // arie, aceeași poziție); din celelalte locuri, acasă.
    final menu = ref.read(navMemoryProvider).menu;
    final back = isGameRoute(path) && menu != '/';
    final compact = AppLayout.of(context).compact;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 12, 16, 4),
      child: Row(
        children: [
          if (!atHome) ...[
            BarButton(
              key: const ValueKey('home'),
              icon: back ? Icons.arrow_back_rounded : Icons.home_rounded,
              color: Tokens.primary,
              label: back ? 'Înapoi la jocuri' : 'Acasă',
              onTap: () => context.go(back ? menu : '/'),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: atHome
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: BrandTitle(),
                    ),
                  )
                : OutlinedTitle(
                    title ?? 'Licurici',
                    style: compact ? text.titleLarge : text.headlineMedium,
                  ),
          ),
          ?trailing,
          const SizedBox(width: 10),
          BarButton(
            icon: settings.voice
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: const Color(0xFFE9B949),
            label: settings.voice ? 'Vocea e pornită' : 'Vocea e oprită',
            onTap: notifier.toggleVoice,
          ),
          const SizedBox(width: 10),
          BarButton(
            icon: Icons.spa_rounded,
            color: Tokens.lavender,
            label: settings.calm ? 'Modul calm e pornit' : 'Modul calm e oprit',
            active: settings.calm,
            onTap: notifier.toggleCalm,
          ),
        ],
      ),
    );
  }
}

/// Numele aplicației pe ecranul principal: litere rotunde, calde, cu contur.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 18 : 24,
          height: compact ? 18 : 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFFF6C8), Color(0xFFF2CF6B), Color(0x00F2CF6B)],
              stops: [0.15, 0.55, 1],
            ),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedTitle(
          'Licurici',
          color: const Color(0xFF3D5A80),
          stroke: 8,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontSize: compact ? 28 : 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => CandyIconButton(
    icon: icon,
    label: label,
    color: color,
    onTap: onTap,
    active: active,
  );
}
