import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../shared/emoji_art.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import '../../shared/top_bar.dart';
import '../settings/settings.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final motion = MotionPolicy.of(context, ref);
    final groups = gamesForGrade(settings.grade);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const _Greeting(),
                  const SizedBox(height: 20),
                  _GradePicker(selected: settings.grade),
                  const SizedBox(height: 12),
                  for (final (i, entry) in groups.entries.indexed)
                    _SubjectSection(subject: entry.key, games: entry.value)
                        .animate(key: ValueKey('${settings.grade}-${entry.key}'))
                        .fadeIn(duration: motion.d(350), delay: motion.d(80 * i))
                        .slideY(begin: motion.movement ? 0.08 : 0, end: 0, curve: Curves.easeOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Mascot(size: 104),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: Tokens.surface,
                borderRadius: BorderRadius.circular(Tokens.radius),
                boxShadow: Tokens.shadow,
              ),
              child: Text('Bună! Hai să ne jucăm și să învățăm!',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ],
      );
}

class _GradePicker extends ConsumerWidget {
  const _GradePicker({required this.selected});

  final Grade selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final g in Grade.values)
          Pressable(
            semanticLabel: g.label,
            onTap: () => ref.read(settingsProvider.notifier).setGrade(g),
            child: AnimatedContainer(
              duration: motion.d(220),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: g == selected ? Tokens.primary : Tokens.surface,
                borderRadius: BorderRadius.circular(40),
                boxShadow: g == selected ? Tokens.shadow : null,
                border: Border.all(color: g == selected ? Tokens.primary : Tokens.line, width: 2),
              ),
              child: Text(
                g.label,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: g == selected ? Colors.white : Tokens.ink,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({required this.subject, required this.games});

  final Subject subject;
  final List<GameSpec> games;

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.color);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 12,
              height: 28,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 10),
            Text(subject.label, style: Theme.of(context).textTheme.headlineMedium),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (i, g) in games.indexed) GameTile(game: g, color: color, index: i),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card mare de joc: ilustrația „respiră” ușor (stratul 2, doar la motion `full`).
class GameTile extends ConsumerWidget {
  const GameTile({super.key, required this.game, required this.color, this.index = 0});

  final GameSpec game;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    Widget art = EmojiArt(game.emoji, size: 72);
    if (motion.ambient) {
      art = art
          .animate(onPlay: (c) => c.repeat(reverse: true), delay: (index * 300).ms)
          .scaleXY(begin: 1, end: 1.06, duration: 1800.ms, curve: Curves.easeInOut);
    }
    return Pressable(
      semanticLabel: game.name,
      onTap: () => context.go('/joc/${game.id}'),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radius),
          boxShadow: Tokens.shadow,
          border: Border(bottom: BorderSide(color: color, width: 6)),
        ),
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: art,
            ),
            const SizedBox(height: 12),
            Text(game.name, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(game.description,
                style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
