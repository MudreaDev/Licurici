import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/layout.dart';
import 'illustration.dart';
import 'mascot.dart';
import 'motion.dart';
import 'ui/candy.dart';

/// O acțiune de la finalul unui joc.
class FinishAction {
  const FinishAction(this.label, this.icon, this.color, this.onTap, {this.key});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Key? key;
}

/// Finalul comun al jocurilor (stratul 7 din §15.1): stelele intră una câte una, Licurici
/// sărbătorește, apoi apar butoanele. Recompensăm și efortul: cel puțin o stea.
class RewardFinish extends ConsumerWidget {
  const RewardFinish({
    super.key,
    required this.stars,
    required this.actions,
    this.title = 'Ai terminat! Bravo!',
    this.subtitle,
    this.sticker,
  });

  /// 1..3
  final int stars;
  final String title;
  final String? subtitle;
  final List<FinishAction> actions;

  /// Abțibildul câștigat (id din `stickerIds`): se lipește lângă stele, după ele.
  final String? sticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final compact = layout.compact;
    final starSize = compact ? 64.0 : 104.0;
    final text = Theme.of(context).textTheme;

    final starsRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            // Steaua din mijloc e puțin mai sus, ca pe un podium.
            padding: EdgeInsets.fromLTRB(6, 0, 6, i == 1 ? starSize * 0.25 : 0),
            child:
                _Star(
                  size: i == 1 ? starSize * 1.15 : starSize,
                  earned: i < stars,
                ).animateIf(
                  motion.feedback,
                  (w) => w
                      .animate(delay: motion.d(300 + 320 * i))
                      .fadeIn(duration: motion.d(200))
                      .scaleXY(
                        begin: motion.movement ? 0.2 : 1,
                        end: 1,
                        duration: motion.d(600),
                        curve: Curves.elasticOut,
                      )
                      .rotate(begin: motion.movement ? -0.12 : 0, end: 0),
                ),
          ),
      ],
    );

    final panel = CandyPanel(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 36,
        compact ? 14 : 26,
        compact ? 20 : 36,
        compact ? 16 : 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: (compact ? text.headlineMedium : text.displaySmall)!
                .copyWith(color: const Color(0xFF3D5A80)),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: text.bodyLarge, textAlign: TextAlign.center),
          ],
          SizedBox(height: compact ? 8 : 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              starsRow,
              if (sticker case final id?) ...[
                SizedBox(width: compact ? 14 : 28),
                _NewSticker(id: id, size: starSize * 1.2).animateIf(
                  motion.feedback,
                  (w) => w
                      .animate(delay: motion.d(1350))
                      .fadeIn(duration: motion.d(200))
                      .scaleXY(
                        begin: motion.movement ? 1.8 : 1,
                        end: 1,
                        duration: motion.d(450),
                        curve: Curves.easeOutBack,
                      )
                      .rotate(begin: motion.movement ? 0.2 : 0, end: -0.05),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 12 : 26),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final a in actions)
                CandyButton(
                  key: a.key,
                  label: a.label,
                  icon: a.icon,
                  color: a.color,
                  onTap: a.onTap,
                  minWidth: compact ? 170 : 210,
                ),
            ],
          ).animateIf(
            motion.feedback,
            (w) => w
                .animate(delay: motion.d(sticker == null ? 1300 : 1800))
                .fadeIn(duration: motion.d(300)),
          ),
        ],
      ),
    );

    final mascot =
        Mascot(
          size: compact ? 130 : 220,
          mood: MascotMood.celebrate,
          reaction: 1,
        ).animateIf(
          motion.feedback,
          (w) => w
              .animate(delay: motion.d(150))
              .fadeIn(duration: motion.d(250))
              .slideY(
                begin: motion.movement ? 0.2 : 0,
                end: 0,
                curve: Curves.easeOutBack,
              ),
        );

    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 20),
      // Pe orice ecran încape întreg, fără derulare: se micșorează proporțional.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: layout.twoPane
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [mascot, const SizedBox(width: 12), panel],
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [mascot, panel]),
      ),
    );
  }
}

/// Abțibildul nou: „lipit” ușor înclinat, cu o etichetă mică dedesubt.
class _NewSticker extends StatelessWidget {
  const _NewSticker({required this.id, required this.size});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: size,
        child: Illustration(
          illustration('rewards/sticker_$id'),
          fallbackEmoji: '🎁',
          semanticLabel: 'Abțibild nou',
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF0B9A0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Nou!',
          style: Theme.of(
            context,
          ).textTheme.titleMedium!.copyWith(color: Colors.white),
        ),
      ),
    ],
  );
}

/// Steaua de recompensă: ilustrația pictată (sau ⭐), ștearsă dacă nu e câștigată.
class _Star extends StatelessWidget {
  const _Star({required this.size, required this.earned});

  final double size;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final star = SizedBox.square(
      dimension: size,
      child: Illustration(illustration('rewards/star'), fallbackEmoji: '⭐'),
    );
    if (earned) return star;
    return Opacity(
      opacity: 0.35,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.33, 0.33, 0.33, 0, 20, //
          0.33, 0.33, 0.33, 0, 20,
          0.33, 0.33, 0.33, 0, 30,
          0, 0, 0, 1, 0,
        ]),
        child: star,
      ),
    );
  }
}

extension on Widget {
  /// Fără mișcare (`MotionLevel.off`) nu creăm deloc animația: nici timere, nici cadre.
  Widget animateIf(bool on, Widget Function(Widget) build) =>
      on ? build(this) : this;
}
