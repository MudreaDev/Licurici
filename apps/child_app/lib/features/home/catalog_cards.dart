import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/illustration.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/sfx.dart';
import '../../shared/voice.dart';
import '../../shared/ui/candy.dart';
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

/// Cardurile de pe ecranul principal și din ecranul ariei: corp crem, buză 3D în culoarea
/// ariei și o „fereastră” ilustrată sus.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.width,
    required this.color,
    required this.child,
    required this.onTap,
    required this.label,
  });

  final double width;
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => CandyPressable(
    color: const Color(0xFFFFFDF8),
    lipColor: shade(color, 0.08),
    lip: 9,
    radius: 30,
    width: width,
    padding: const EdgeInsets.all(10),
    semanticLabel: label,
    onTap: onTap,
    child: child,
  );
}

/// Fereastra ilustrată a unui card: degradeu în culoarea ariei, cu un halou cald în spate.
class _ArtWindow extends StatelessWidget {
  const _ArtWindow({
    required this.width,
    required this.height,
    required this.color,
    required this.child,
  });

  final double width;
  final double height;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.9,
          colors: [tint(color, 0.2), tint(color, 0.08), color],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    ),
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
    final layout = AppLayout.of(context);
    final compact = layout.compact;
    final color = domainColor(domain);
    // Pe tabletă cardul crește cu ecranul (mai ușor de nimerit, ilustrația se vede mai bine).
    final width = compact
        ? 210.0
        : (layout.size.height * 0.4).clamp(270.0, 380.0);
    final label = childLabel(domain);
    final thumb = compact ? 30.0 : 40.0;
    return KeyedSubtree(
      key: ValueKey('domain-${domain.code}'),
      child: _CardShell(
        width: width,
        color: color,
        label: label,
        onTap: () => context.go('/arie/${domain.code.toLowerCase()}'),
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
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineMedium)!
                      .copyWith(color: shade(color, 0.3)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compact ? 4 : 8),
            // Ce jocuri te așteaptă: mici ilustrații rotunde, ca orar vizual (fără cifre de citit).
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final g in games.take(5))
                  Container(
                    width: thumb,
                    height: thumb,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: tint(color, 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Illustration(
                      gameIllustration(g.id),
                      fallbackEmoji: g.emoji,
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 2 : 4),
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
    final layout = AppLayout.of(context);
    final compact = layout.compact;
    final color = domainColor(entry.domain);
    final width = compact
        ? 180.0
        : (layout.size.height * 0.34).clamp(230.0, 330.0);
    return KeyedSubtree(
      key: ValueKey('game-${entry.id}'),
      child: _CardShell(
        width: width,
        color: color,
        label: entry.name,
        onTap: () => openGame(context, ref, entry.route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ArtWindow(
              width: width - 20,
              height: width - 20,
              color: color,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _breathe(
                  Illustration(
                    gameIllustration(entry.id),
                    fallbackEmoji: entry.emoji,
                  ),
                  motion,
                  index,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              entry.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(color: shade(color, 0.32)),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Licurici cu un balon de vorbire — colțul din stânga al ecranelor de alegere.
class MascotCorner extends ConsumerStatefulWidget {
  const MascotCorner({
    super.key,
    required this.message,
    this.mood = MascotMood.wave,
  });

  final String message;
  final MascotMood mood;

  @override
  ConsumerState<MascotCorner> createState() => _MascotCornerState();
}

class _MascotCornerState extends ConsumerState<MascotCorner> {
  /// Copilul îl atinge pe Licurici → el se bucură și salută (o mică surpriză, fără scop).
  int _pokes = 0;

  void _poke() {
    setState(() => _pokes++);
    ref.read(sfxProvider).play(Sfx.tap);
    ref.read(voiceProvider).say(['bună']);
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return LayoutBuilder(
      builder: (context, c) {
        final bubble = SpeechBubble(
          tail: BubbleTail.bottom,
          child: Text(
            widget.message,
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
                builder: (context, m) => GestureDetector(
                  onTap: _poke,
                  child: Mascot(
                    size: m.biggest.shortestSide.clamp(60, 260),
                    mood: _pokes == 0 ? widget.mood : MascotMood.happy,
                    reaction: _pokes,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
