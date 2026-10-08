/// Forma ascunsă (POT9, catalog pe arii #13 `forma-ascunsa`): un desen din linii care se
/// încrucișează; în el e ascunsă o formă (cerc, pătrat, triunghi, stea, inimă, romb).
/// Copilul alege forma. Paradigma figurilor încastrate (*embedded figures*) — adesea un
/// punct forte al copiilor cu TSA, de valorificat.
///
/// Desenul e generat din seed: forma țintă + linii „de umplutură” care trec peste ea (linii
/// drepte, dreptunghiuri alungite, valuri, zig-zaguri — niciuna nu e o formă din variante).
/// Tier 1: o linie peste formă; tier 3: trei; tier 6: cinci; tier 10+: opt, iar forma e mai
/// mică și rotită.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';

/// Formele care se pot ascunde (aceleași cuvinte și imagini ca la „Forme”).
const hiddenShapes = [('cerc', '🔵'), ('pătrat', '🟦'), ('triunghi', '🔺'), ('stea', '⭐'), ('inimă', '❤️'), ('romb', '🔷')];

/// Conturul unei forme cu centrul [c], mărimea [s] (cât caseta ei) și rotirea [rot] (radiani).
List<Point<double>> shapeOutline(String shape, Point<double> c, double s, double rot) {
  Point<double> at(double x, double y) =>
      Point(c.x + (x * cos(rot) - y * sin(rot)) * s, c.y + (x * sin(rot) + y * cos(rot)) * s);
  final pts = <Point<double>>[];
  switch (shape) {
    case 'cerc':
      for (var i = 0; i <= 48; i++) {
        pts.add(at(0.5 * cos(i / 48 * 2 * pi), 0.5 * sin(i / 48 * 2 * pi)));
      }
    case 'pătrat':
      pts.addAll([at(-0.45, -0.45), at(0.45, -0.45), at(0.45, 0.45), at(-0.45, 0.45), at(-0.45, -0.45)]);
    case 'triunghi':
      pts.addAll([at(0, -0.5), at(0.5, 0.4), at(-0.5, 0.4), at(0, -0.5)]);
    case 'romb':
      pts.addAll([at(0, -0.55), at(0.36, 0), at(0, 0.55), at(-0.36, 0), at(0, -0.55)]);
    case 'stea':
      for (var i = 0; i <= 10; i++) {
        final a = -pi / 2 + i * pi / 5, r = i.isEven ? 0.52 : 0.21;
        pts.add(at(r * cos(a), r * sin(a)));
      }
    default: // inimă
      for (var i = 0; i <= 48; i++) {
        final t = i / 48 * 2 * pi;
        final x = 16 * pow(sin(t), 3), y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t));
        pts.add(at(x / 34, y / 34 + 0.06));
      }
  }
  return pts;
}

class FormaAscunsaGame extends ChoiceGame {
  const FormaAscunsaGame()
      : super(
          id: 'forma-ascunsa',
          name: 'Forma ascunsă',
          emoji: '🔍',
          description: 'Găsește forma din desen',
          subject: Subject.forme,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    return Lesson(
      title: name,
      instruction: 'Ce formă e ascunsă în desen?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, tier)],
    );
  }

  ChoiceRound _round(GameContext ctx, int tier) {
    final (word, art) = ctx.pick(hiddenShapes);
    final fillers = tier <= 1 ? 1 : (tier <= 3 ? 3 : (tier <= 6 ? 5 : 8));
    final small = tier >= 10;
    final s = small ? 0.3 + ctx.random.nextDouble() * 0.08 : 0.4 + ctx.random.nextDouble() * 0.12;
    final c = Point(0.35 + ctx.random.nextDouble() * 0.3, 0.35 + ctx.random.nextDouble() * 0.3);
    final rot = tier >= 6 ? (ctx.random.nextDouble() - 0.5) * 0.7 : 0.0;
    final lines = <List<Point<double>>>[];
    for (var i = 0; i < fillers; i++) {
      lines.add(_filler(ctx.random, c, s, i));
    }
    // Forma țintă printre umplutură (nu mereu prima sau ultima desenată).
    final target = ctx.random.nextInt(lines.length + 1);
    lines.insert(target, shapeOutline(word, c, s, rot));
    final others = ctx.sample([for (final h in hiddenShapes) if (h.$1 != word) h], 5);
    return ChoiceRound(
      prompt: 'Ce formă e ascunsă în desen?',
      speak: const ['Ce formă e ascunsă în desen?'],
      hint: 'Uite: e $word.',
      stimulusId: word,
      visuals: [HiddenShapeVisual(lines, target: target)],
      choices: [
        for (final (w, a) in [(word, art), ...others]..shuffle(ctx.random))
          Choice(art: a, id: w, speak: w, correct: w == word),
      ],
    );
  }

  /// O linie de umplutură care trece peste forma țintă (centrul [c], mărimea [s]).
  List<Point<double>> _filler(Random r, Point<double> c, double s, int i) {
    Point<double> near() => Point(c.x + (r.nextDouble() - 0.5) * s * 1.2, c.y + (r.nextDouble() - 0.5) * s * 1.2);
    Point<double> clampP(Point<double> p) => Point(p.x.clamp(0.02, 0.98), p.y.clamp(0.02, 0.98));
    switch (i % 4) {
      case 0: // linie dreaptă de la o margine la alta, prin zona formei
        final a = r.nextDouble() * pi, p = near();
        return [
          clampP(Point(p.x - cos(a) * 0.8, p.y - sin(a) * 0.8)),
          clampP(Point(p.x + cos(a) * 0.8, p.y + sin(a) * 0.8)),
        ];
      case 1: // dreptunghi alungit (nu pătrat)
        final p = near(), w = 0.2 + r.nextDouble() * 0.35, h = w / (1.8 + r.nextDouble());
        final vertical = r.nextBool();
        final (hw, hh) = vertical ? (h / 2, w / 2) : (w / 2, h / 2);
        return [
          for (final (dx, dy) in [(-1, -1), (1, -1), (1, 1), (-1, 1), (-1, -1)]) clampP(Point(p.x + dx * hw, p.y + dy * hh)),
        ];
      case 2: // val (nu arc: un arc ar semăna cu cercul din variante)
        final p = near(), len = 0.5 + r.nextDouble() * 0.3, a = r.nextDouble() * pi, amp = 0.05 + r.nextDouble() * 0.04;
        return [
          for (var k = 0; k <= 24; k++)
            clampP(Point(
              p.x + cos(a) * (k / 24 - 0.5) * len - sin(a) * sin(k / 24 * 4 * pi) * amp,
              p.y + sin(a) * (k / 24 - 0.5) * len + cos(a) * sin(k / 24 * 4 * pi) * amp,
            )),
        ];
      default: // zig-zag
        final p = near(), len = 0.4 + r.nextDouble() * 0.3, a = r.nextDouble() * pi;
        final n = 5;
        return [
          for (var k = 0; k <= n; k++)
            clampP(Point(
              p.x + cos(a) * (k / n - 0.5) * len - sin(a) * (k.isEven ? 0.04 : -0.04),
              p.y + sin(a) * (k / n - 0.5) * len + cos(a) * (k.isEven ? 0.04 : -0.04),
            )),
        ];
    }
  }
}
