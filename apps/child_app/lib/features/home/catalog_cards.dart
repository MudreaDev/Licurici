import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/emoji_art.dart';
import '../../shared/illustration.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/pressable.dart';
import '../session/mood_check.dart';

/// Ilustrația unui card „respiră” ușor (doar la motion `full`), decalat după poziție.
Widget _breathe(Widget child, MotionPolicy motion, int index) => !motion.ambient
    ? child
    : child
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: (index * 280).ms,
          )
          .scaleXY(
            begin: 1,
            end: 1.035,
            duration: 2200.ms,
            curve: Curves.easeInOut,
          );

/// Intrarea cardurilor: apar pe rând, alunecând puțin (fără mișcare în modul calm).
Widget enterCard(Widget child, MotionPolicy motion, int index) => child
    .animate()
    .fadeIn(duration: motion.d(320), delay: motion.d(70 * index))
    .slideX(
      begin: motion.movement ? 0.08 : 0,
      end: 0,
      curve: Curves.easeOutBack,
    );

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.width,
    required this.color,
    required this.child,
  });

  final double width;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Tokens.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(30),
      boxShadow: Tokens.shadowLg,
      border: Border(bottom: BorderSide(color: color, width: 7)),
    ),
    child: child,
  );
}

/// Cardul mare al unei arii de dezvoltare: scena ariei, numele pentru copil și jocurile ei.
class DomainCard extends ConsumerWidget {
  const DomainCard({
    super.key,
    required this.domain,
    required this.games,
    this.index = 0,
  });

  final Domain domain;
  final List<CatalogEntry> games;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    final color = domainColor(domain);
    final width = compact ? 210.0 : 290.0;
    final label = childLabel(domain);
    return Pressable(
      key: ValueKey('domain-${domain.code}'),
      semanticLabel: label,
      onTap: () => context.go('/arie/${domain.code.toLowerCase()}'),
      child: _CardShell(
        width: width,
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: width - 20,
                height: (width - 20) * 0.75,
                color: color.withValues(alpha: 0.22),
                child: _breathe(
                  Illustration(
                    domainIllustration(domain),
                    fallbackEmoji: domainEmoji(domain),
                    fit: BoxFit.cover,
                  ),
                  motion,
                  index,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              label,
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compact ? 4 : 8),
            // Ce jocuri te așteaptă: iconițe mici, ca orar vizual (fără cifre de citit).
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final g in games.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: EmojiArt(g.emoji, size: compact ? 22 : 30),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cardul unui joc din ecranul ariei.
class GameCard extends ConsumerWidget {
  const GameCard({super.key, required this.entry, this.index = 0});

  final CatalogEntry entry;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    final color = domainColor(entry.domain);
    final width = compact ? 180.0 : 240.0;
    return Pressable(
      key: ValueKey('game-${entry.id}'),
      semanticLabel: entry.name,
      onTap: () => openGame(context, ref, entry.route),
      child: _CardShell(
        width: width,
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width - 20,
              height: width - 20,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(8),
              child: _breathe(
                Illustration(
                  gameIllustration(entry.id),
                  fallbackEmoji: entry.emoji,
                ),
                motion,
                index,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              entry.name,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              entry.description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Licurici cu un balon de vorbire — colțul din stânga al ecranelor de alegere.
class MascotCorner extends StatelessWidget {
  const MascotCorner({
    super.key,
    required this.message,
    this.mood = MascotMood.wave,
  });

  final String message;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return LayoutBuilder(
      builder: (context, c) {
        final bubble = Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: Tokens.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: Tokens.shadow,
          ),
          child: Text(
            message,
            style: compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            bubble,
            SizedBox(height: compact ? 4 : 10),
            Flexible(
              child: LayoutBuilder(
                builder: (context, m) => Mascot(
                  size: m.biggest.shortestSide.clamp(60, 260),
                  mood: mood,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
