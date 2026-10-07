import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/ui/candy.dart' show shade;
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
            FlankerVisual() => _Flanker(v),
            ClockVisual() => _Clock(v),
            MoneyVisual() => _Money(v),
            SilhouetteVisual() => _BigEmoji(
              v.emoji,
              solved: solved,
              silhouette: !solved,
            ),
            ObjectsVisual() => _Objects(v, solved: solved),
            ColorVisual() => _ColorBlob(Color(v.argb)),
            TextVisual() => _BigText(v),
            SceneVisual() => _Scene(v.text),
            PatternVisual() => _Pattern(v, solved: solved),
          },
        ),
    ],
  );
}

class _BigEmoji extends ConsumerWidget {
  const _BigEmoji(this.emoji, {required this.solved, this.silhouette = false});

  final String emoji;
  final bool solved;

  /// Arătat ca umbră; la răspunsul corect se colorează (estompare încrucișată).
  final bool silhouette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final size = 170 * VisualScale.of(context);
    Widget w = AnimatedSwitcher(
      duration: motion.d(450),
      child: silhouette
          ? Silhouette(
              key: const ValueKey('umbra'),
              child: StimulusArt(emoji, size: size),
            )
          : StimulusArt(emoji, key: const ValueKey('color'), size: size),
    );
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
            // Pata „respiră” între cerc și pătrat rotunjit (raza scalată ca pata).
            builder: (context, v, child) => ClipRRect(
              borderRadius: BorderRadius.circular(
                (90 - v * 30) * VisualScale.of(context),
              ),
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

/// Șirul „ce urmează?”: imaginile intră pe rând (ca un ritm), iar locul gol de la capăt
/// pulsează; la răspunsul corect se umple cu imaginea care lipsea.
class _Pattern extends ConsumerWidget {
  const _Pattern(this.visual, {required this.solved});

  final PatternVisual visual;
  final bool solved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final n = visual.items.length + 1;
    final size =
        (n <= 5 ? 92.0 : (n <= 7 ? 76.0 : 64.0)) * VisualScale.of(context);
    Widget slot(Widget child, {bool empty = false}) => Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: empty ? Tokens.sun.withValues(alpha: 0.18) : Tokens.surface2,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: empty ? Tokens.sun : const Color(0xFFE6EEEC),
          width: empty ? 3 : 2,
        ),
      ),
      child: Center(child: child),
    );
    Widget enter(Widget w, int i) => !motion.feedback
        ? w
        : w
              .animate(delay: motion.d(120 * i))
              .fadeIn(duration: motion.d(200))
              .moveY(
                begin: motion.movement ? 12 : 0,
                end: 0,
                curve: Curves.easeOut,
              );
    final last = solved
        ? Juice(
            enabled: motion.movement,
            popTick: 1,
            child: slot(StimulusArt(visual.answer, size: size * 0.8)),
          )
        : slot(
            Text(
              '?',
              style: Theme.of(context).textTheme.displaySmall!.copyWith(
                fontSize: size * 0.5,
                color: _questionInk,
              ),
            ),
            empty: true,
          );
    // Un singur rând, ca ritmul să se citească; FittedBox-ul scenei îl micșorează la nevoie.
    final gap = SizedBox(width: size * 0.12);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, e) in visual.items.indexed) ...[
            enter(slot(StimulusArt(e, size: size * 0.8)), i),
            gap,
          ],
          enter(
            !motion.ambient || solved
                ? last
                : last
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.06, duration: 900.ms),
            visual.items.length,
          ),
        ],
      ),
    );
  }
}

/// Galbenul mai închis al semnului întrebării (contrast pe fundal deschis).
const _questionInk = Color(0xFFC79A1E);

class _Scene extends StatelessWidget {
  const _Scene(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 640),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDF8),
      borderRadius: BorderRadius.circular(Tokens.radius),
      border: Border.all(color: const Color(0xFFEDE3D2), width: 2),
      boxShadow: Tokens.shadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StimulusArt('🧒', size: 96 * VisualScale.of(context)),
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

/// Umbra unui obiect: aceeași formă, plină, gri-albăstrui închis.
class Silhouette extends StatelessWidget {
  const Silhouette({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.mode(Color(0xFF3E4A63), BlendMode.srcIn),
    child: child,
  );
}

/// Rândul de pești (Flanker): fiecare privește în direcția în care înoată; cel din mijloc e
/// încercuit la nivelurile mici, ca să fie clar care contează.
class _Flanker extends StatelessWidget {
  const _Flanker(this.visual);

  final FlankerVisual visual;

  @override
  Widget build(BuildContext context) {
    final n = visual.directions.length;
    final base =
        (n == 1 ? 150.0 : (n == 3 ? 110.0 : 86.0)) * VisualScale.of(context);
    // Încap toți peștii pe lățimea panoului (margini, spațiu, chenarul încercuirii: ~26 dp pe pește).
    return LayoutBuilder(
      builder: (context, box) => _row(
        box.maxWidth.isFinite ? math.min(base, box.maxWidth / n - 26) : base,
      ),
    );
  }

  Widget _row(double size) {
    final n = visual.directions.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, d) in visual.directions.indexed)
          Container(
            key: ValueKey('flanker-$i'),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(6),
            decoration: i == visual.center && visual.highlight && n > 1
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: Tokens.sun.withValues(alpha: 0.25),
                    border: Border.all(color: Tokens.sun, width: 3),
                  )
                : null,
            child: StimulusArt(visual.emoji, size: size, flip: d < 0),
          ),
      ],
    );
  }
}

/// Banii: bancnote desenate din cod, fiecare valoare cu culoarea ei (ca bancnotele
/// adevărate: copilul învață și după culoare), valoarea mare în colț și în mijloc.
class _Money extends StatelessWidget {
  const _Money(this.visual);

  final MoneyVisual visual;

  static const _colors = {
    1: Color(0xFF9CC5A1),
    2: Color(0xFFA9CBE3),
    5: Color(0xFFB9A3D6),
    10: Color(0xFFE79BA8),
    20: Color(0xFFF2B880),
    50: Color(0xFFF2CF6B),
  };

  @override
  Widget build(BuildContext context) {
    final k = VisualScale.of(context);
    final w = 132 * k, h = 66 * k;
    final text = Theme.of(context).textTheme.titleLarge!;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: (w + 10) * 3),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, v) in visual.notes.indexed)
            SizedBox(
              key: ValueKey('note-$i-$v'),
              width: w,
              height: h,
              child: CustomPaint(
                painter: _NotePainter(v, _colors[v] ?? Tokens.sun, text),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotePainter extends CustomPainter {
  _NotePainter(this.value, this.color, this.style);

  final int value;
  final Color color;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height * 0.14));
    canvas.drawRRect(r.shift(const Offset(0, 3)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(r, Paint()..color = color);
    // Chenarul și fâșia de siguranță, ca pe o bancnotă.
    canvas.drawRRect(
      r.deflate(size.height * 0.08),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.03
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.66, 0, size.width * 0.05, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Medalionul din stânga (în locul portretului).
    final c = Offset(size.width * 0.28, size.height / 2);
    canvas.drawCircle(c, size.height * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawCircle(
      c,
      size.height * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.03
        ..color = shade(color, 0.3),
    );
    void label(String t, double fontSize, Offset center) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: style.copyWith(fontSize: fontSize, color: shade(color, 0.55), height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    label('$value', size.height * 0.38, c);
    label('$value', size.height * 0.34, Offset(size.width * 0.84, size.height * 0.38));
    label('lei', size.height * 0.2, Offset(size.width * 0.84, size.height * 0.72));
  }

  @override
  bool shouldRepaint(_NotePainter old) => old.value != value || old.color != color;
}

/// Ceasul: cadran crem cu cifre, acul mic (ora) gros și scurt, acul mare (minutele) subțire.
class _Clock extends StatelessWidget {
  const _Clock(this.visual);

  final ClockVisual visual;

  @override
  Widget build(BuildContext context) {
    final size = 190 * VisualScale.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ClockPainter(
          visual.hour,
          visual.minute,
          Theme.of(context).textTheme.titleLarge!,
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.hour, this.minute, this.style);

  final int hour;
  final int minute;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFFBF0));
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Tokens.primary,
    );
    for (var i = 1; i <= 12; i++) {
      final a = i / 12 * 2 * math.pi - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: style.copyWith(fontSize: r * 0.2, color: Tokens.ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.74;
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    void hand(double angle, double len, double width, Color color) {
      final a = angle - math.pi / 2;
      canvas.drawLine(
        c,
        c + Offset(math.cos(a), math.sin(a)) * len,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    // Acul mic merge și el puțin între ore (la și jumătate e la mijloc).
    hand(
      (hour % 12 + minute / 60) / 12 * 2 * math.pi,
      r * 0.45,
      r * 0.09,
      Tokens.ink,
    );
    hand(
      minute / 60 * 2 * math.pi,
      r * 0.68,
      r * 0.045,
      const Color(0xFFE06B6B),
    );
    canvas.drawCircle(c, r * 0.06, Paint()..color = Tokens.ink);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}
