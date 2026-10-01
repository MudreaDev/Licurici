import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/emoji_art.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import '../../shared/top_bar.dart';
import '../../data/session.dart';
import '../parent/parent_gate.dart';
import '../session/mood_check.dart';
import '../settings/settings.dart';
import 'today_path.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final groups = gamesForGrade(settings.grade);
    final reactionSection = _SubjectSection(
      subject: Subject.emotii,
      games: const [],
      reaction: reactionGames,
      title: 'Atenție și autocontrol',
      sequence: true,
      horizontal: layout.twoPane,
    );

    Widget section(int i, Subject subject, List<GameSpec> games) =>
        _SubjectSection(
              subject: subject,
              games: games,
              horizontal: layout.twoPane,
            )
            .animate(key: ValueKey('${settings.grade}-$subject'))
            .fadeIn(duration: motion.d(350), delay: motion.d(80 * i))
            .slideX(
              begin: layout.twoPane && motion.movement ? 0.06 : 0,
              end: 0,
              curve: Curves.easeOut,
            )
            .slideY(
              begin: !layout.twoPane && motion.movement ? 0.08 : 0,
              end: 0,
              curve: Curves.easeOut,
            );

    // LANDSCAPE (telefon și tabletă): clasele sus, jocurile într-un rând care se derulează
    // orizontal, grupate pe materii — totul încape pe ecran fără derulare verticală.
    if (layout.twoPane) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const _HomeBar(),
              Padding(
                padding: EdgeInsets.fromLTRB(16, layout.compact ? 0 : 8, 16, 0),
                child: Row(
                  children: [
                    Mascot(size: layout.compact ? 52 : 80),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradePicker(
                        selected: settings.grade,
                        scrollable: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    layout.compact ? 6 : 16,
                    16,
                    layout.compact ? 8 : 20,
                  ),
                  children: [
                    const TodayPath(compact: true),
                    SizedBox(width: layout.compact ? 20 : 32),
                    for (final (i, e) in groups.entries.indexed) ...[
                      if (i > 0) SizedBox(width: layout.compact ? 20 : 32),
                      section(i, e.key, e.value),
                    ],
                    const SizedBox(width: 24),
                    reactionSection,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _HomeBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const _Greeting(),
                  const SizedBox(height: 20),
                  _GradePicker(selected: settings.grade),
                  const SizedBox(height: 12),
                  const TodayPath(),
                  const SizedBox(height: 12),
                  for (final (i, e) in groups.entries.indexed)
                    section(i, e.key, e.value),
                  reactionSection,
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
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return Row(
      children: [
        Mascot(size: compact ? 64 : 104),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 22,
              vertical: compact ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.radius),
              boxShadow: Tokens.shadow,
            ),
            child: Text(
              'Bună! Hai să ne jucăm și să învățăm!',
              style: compact
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradePicker extends ConsumerWidget {
  const _GradePicker({required this.selected, this.scrollable = false});

  final Grade selected;

  /// Un singur rând derulabil orizontal (landscape), în loc de rânduri care se rup.
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    final chips = [
      for (final g in Grade.values)
        Pressable(
          semanticLabel: g.label,
          onTap: () => ref.read(settingsProvider.notifier).setGrade(g),
          child: AnimatedContainer(
            duration: motion.d(220),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 20,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: g == selected ? Tokens.primary : Tokens.surface,
              borderRadius: BorderRadius.circular(40),
              boxShadow: g == selected ? Tokens.shadow : null,
              border: Border.all(
                color: g == selected ? Tokens.primary : Tokens.line,
                width: 2,
              ),
            ),
            child: Text(
              g.label,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: g == selected ? Colors.white : Tokens.ink,
              ),
            ),
          ),
        ),
    ];
    if (!scrollable) return Wrap(spacing: 10, runSpacing: 10, children: chips);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, chip) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            chip,
          ],
        ],
      ),
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({
    required this.subject,
    required this.games,
    this.horizontal = false,
    this.reaction = const [],
    this.sequence = false,
    this.title,
  });

  final Subject subject;
  final List<GameSpec> games;
  final List<ReactionGame> reaction;
  final bool sequence;
  final String? title;

  /// Landscape: titlul deasupra, cardurile pe un rând (lista părinte derulează orizontal).
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.color);
    final tiles = <Widget>[
      if (sequence) GameTile.sequence(color: color),
      for (final (i, g) in games.indexed)
        GameTile(game: g, color: color, index: i),
      for (final (i, g) in reaction.indexed)
        GameTile.reaction(game: g, color: color, index: i),
    ];
    final compact = AppLayout.of(context).compact;
    return Padding(
      padding: EdgeInsets.only(top: horizontal ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title ?? subject.label,
                style: compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 12),
          if (horizontal)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, tile) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(width: 14),
                    // Pe telefoanele mici cardul se micșorează proporțional ca să încapă pe înălțime.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: tile,
                    ),
                  ],
                ],
              ),
            )
          else
            Wrap(spacing: 16, runSpacing: 16, children: tiles),
        ],
      ),
    );
  }
}

/// Card mare de joc: ilustrația „respiră” ușor (stratul 2, doar la motion `full`).
class GameTile extends ConsumerWidget {
  GameTile({
    super.key,
    required GameSpec game,
    required this.color,
    this.index = 0,
  }) : name = game.name,
       emoji = game.emoji,
       description = game.description,
       route = '/joc/${game.id}';

  GameTile.reaction({
    super.key,
    required ReactionGame game,
    required this.color,
    this.index = 0,
  }) : name = game.name,
       emoji = game.emoji,
       description = game.description,
       route = '/reactie/${game.id}';

  final String name, emoji, description, route;
  const GameTile.sequence({super.key, required this.color, this.index = 0})
    : name = 'Felinarele',
      emoji = '💡',
      description = 'Ține minte ordinea luminilor',
      route = '/secventa/simon';
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    Widget art = EmojiArt(emoji, size: compact ? 52 : 72);
    if (motion.ambient) {
      art = art
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: (index * 300).ms,
          )
          .scaleXY(
            begin: 1,
            end: 1.06,
            duration: 1800.ms,
            curve: Curves.easeInOut,
          );
    }
    return Pressable(
      semanticLabel: name,
      onTap: () => openGame(context, ref, route),
      child: Container(
        width: compact ? 150 : 190,
        padding: EdgeInsets.all(compact ? 12 : 18),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radius),
          boxShadow: Tokens.shadow,
          border: Border(bottom: BorderSide(color: color, width: 6)),
        ),
        child: Column(
          children: [
            Container(
              width: compact ? 76 : 110,
              height: compact ? 76 : 110,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: art,
            ),
            SizedBox(height: compact ? 6 : 12),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bara de sus a ecranului principal: după ce copilul a jucat, apare „Gata pe azi”
/// (dispoziția de final + salvarea sesiunii).
class _HomeBar extends ConsumerWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider);
    final played = ref.read(sessionProvider.notifier).hasPlayed;
    return TopBar(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (played) ...[
            BarButton(
              key: const ValueKey('finish-session'),
              emoji: '👋',
              label: 'Gata pe azi',
              onTap: () => finishSession(context, ref),
            ),
            const SizedBox(width: 8),
          ],
          BarButton(
            key: const ValueKey('parent-corner'),
            emoji: '📋',
            label: 'Pentru părinți',
            onTap: () async {
              if (await askParentGate(context) && context.mounted) {
                context.go('/parinte');
              }
            },
          ),
        ],
      ),
    );
  }
}
