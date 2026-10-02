import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../shared/emoji_art.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/stimulus_art.dart';
import 'choice_game_screen.dart' show wobble;

/// Desenează stimulii unei runde. Fiecare tip are animația lui semnătură (README §15.1):
/// obiectele sar pe rând la intrare, emoji-ul mare „respiră”, pata de culoare se extinde,
/// ecuația se scrie litera cu litera.
/// Factorul de scară al stimulilor, calculat din spațiul disponibil: pe tabletă ilustrațiile
/// cresc (până la 1,5×), pe telefon scad. Stimulii îl citesc cu [VisualScale.of].
class VisualScale extends InheritedWidget {
  const VisualScale({super.key, required this.scale, required super.child});

  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VisualScale>()?.scale ?? 1;

  @override
  bool updateShouldNotify(VisualScale old) => old.scale != scale;
}

class PromptVisuals extends StatelessWidget {
  const PromptVisuals({super.key, required this.visuals, required this.solved});

  final List<Visual> visuals;
  final bool solved;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final v in visuals)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: switch (v) {
            EmojiVisual() => _BigEmoji(v.emoji, solved: solved),
            ObjectsVisual() => _Objects(v, solved: solved),
            ColorVisual() => _ColorBlob(Color(v.argb)),
            TextVisual() => _BigText(v),
            SceneVisual() => _Scene(v.text),
          },
        ),
    ],
  );
}

class _BigEmoji extends ConsumerWidget {
  const _BigEmoji(this.emoji, {required this.solved});

  final String emoji;
  final bool solved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    Widget w = StimulusArt(emoji, size: 170 * VisualScale.of(context));
    if (motion.ambient) {
      w = w
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.05,
            duration: 1600.ms,
            curve: Curves.easeInOut,
          );
    }
    return Juice(enabled: motion.movement, hopTick: solved ? 1 : 0, child: w);
  }
}

/// Obiecte numărabile: intră pe rând (numărare vizuală), ușor rotite ca să pară „jucăușe”.
/// Fiecare grup stă în „cutia” lui, pe rânduri de câte 5 (ca pe o numărătoare).
/// La răspunsul corect sar toate, pe rând, ca un val.
class _Objects extends ConsumerWidget {
  const _Objects(this.visual, {required this.solved});

  final ObjectsVisual visual;
  final bool solved;

  static const _perRow = 5;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final total = visual.total;
    final size =
        (total <= 6 ? 72.0 : (total <= 12 ? 56.0 : 44.0)) *
        VisualScale.of(context);
    var k = 0;

    Widget item(String emoji) {
      final i = k++;
      final w =
          Transform.rotate(
                angle: motion.movement ? wobble(i) : 0,
                child: StimulusArt(emoji, size: size),
              )
              .animate(delay: motion.d(90 * i))
              .fadeIn(duration: motion.d(200))
              .scaleXY(
                begin: motion.movement ? 0.3 : 1,
                end: 1,
                duration: motion.d(380),
                curve: Curves.easeOutBack,
              );
      return Juice(
        enabled: motion.movement,
        hopTick: solved ? 1 : 0,
        hopDelay: Duration(milliseconds: 60 * i),
        child: w,
      );
    }

    Widget group(ObjectGroup g) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.surface2,
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: SizedBox(
        width: (size + _gap) * (g.count < _perRow ? g.count : _perRow),
        child: Wrap(
          spacing: _gap,
          runSpacing: _gap,
          alignment: WrapAlignment.center,
          children: [for (var j = 0; j < g.count; j++) item(g.emoji)],
        ),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [
        for (final (gi, g) in visual.groups.indexed) ...[
          if (gi > 0 && visual.operator != null)
            Text(
              visual.operator!,
              style: Theme.of(
                context,
              ).textTheme.displaySmall!.copyWith(color: Tokens.primary),
            ),
          group(g),
        ],
      ],
    );
  }
}

/// Pata de culoare se extinde din centru și apoi „respiră”.
class _ColorBlob extends ConsumerWidget {
  const _ColorBlob(this.color);

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    Widget w =
        Container(
          width: 180 * VisualScale.of(context),
          height: 180 * VisualScale.of(context),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(90 * VisualScale.of(context)),
            boxShadow: Tokens.shadowLg,
          ),
        ).animate().scaleXY(
          begin: motion.movement ? 0.2 : 1,
          end: 1,
          duration: motion.d(500),
          curve: Curves.easeOutBack,
        );
    if (motion.ambient) {
      w = w
          .animate(onPlay: (c) => c.repeat(reverse: true), delay: 600.ms)
          .custom(
            duration: 1800.ms,
            curve: Curves.easeInOut,
            builder: (context, v, child) => ClipRRect(
              borderRadius: BorderRadius.circular(90 - v * 30),
              child: child,
            ),
          );
    }
    return w;
  }
}

class _BigText extends ConsumerWidget {
  const _BigText(this.visual);

  final TextVisual visual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final style = Theme.of(context).textTheme.displaySmall!.copyWith(
      fontSize: (visual.isEquation ? 56 : 52) * VisualScale.of(context),
      color: visual.isEquation ? Tokens.ink : Tokens.primaryDark,
    );
    if (!motion.movement) return Text(visual.text, style: style);
    // Ecuația „se scrie singură”, caracter cu caracter.
    final chars = visual.text.characters.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, ch) in chars.indexed)
          Text(ch, style: style)
              .animate(delay: (200 + 45 * i).ms)
              .fadeIn(duration: 160.ms)
              .moveY(
                begin: 10,
                end: 0,
                duration: 220.ms,
                curve: Curves.easeOut,
              ),
      ],
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 640),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
    decoration: BoxDecoration(
      color: Tokens.surface,
      borderRadius: BorderRadius.circular(Tokens.radius),
      boxShadow: Tokens.shadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmojiArt('🧒', size: 64 * VisualScale.of(context)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              fontSize: 24 * VisualScale.of(context),
            ),
          ),
        ),
      ],
    ),
  );
}
