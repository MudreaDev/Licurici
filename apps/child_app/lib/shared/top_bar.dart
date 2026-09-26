import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../app/theme.dart';
import '../features/settings/settings.dart';
import 'emoji_art.dart';
import 'pressable.dart';

/// Bara de sus — identică și fixă pe fiecare ecran (principiul 5 din §2).
class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.title, this.trailing});

  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final atHome = GoRouterState.of(context).uri.path == '/';
    final compact = AppLayout.of(context).compact;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 12, 16, 4),
      child: Row(
        children: [
          BarButton(
            emoji: '🏠',
            label: 'Acasă',
            onTap: atHome ? null : () => context.go('/'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? 'Licurici',
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
          const SizedBox(width: 8),
          BarButton(
            emoji: settings.voice ? '🔊' : '⏸',
            label: settings.voice ? 'Vocea e pornită' : 'Vocea e oprită',
            onTap: notifier.toggleVoice,
          ),
          const SizedBox(width: 8),
          BarButton(
            emoji: '😌',
            label: settings.calm ? 'Modul calm e pornit' : 'Modul calm e oprit',
            active: settings.calm,
            onTap: notifier.toggleCalm,
          ),
        ],
      ),
    );
  }
}

class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.emoji,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final side = AppLayout.of(context).barButton;
    return Tooltip(
      message: label,
      child: Pressable(
        semanticLabel: label,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: active ? Tokens.goodSoft : Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.radiusS),
              boxShadow: Tokens.shadow,
              border: Border.all(
                color: active ? Tokens.good : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: EmojiArt(emoji, size: side * 0.6),
          ),
        ),
      ),
    );
  }
}
