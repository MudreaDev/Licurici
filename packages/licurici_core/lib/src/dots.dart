/// Unește punctele (MOT1–3, fratele lui „Trasează”): degetul duce creionul de la punctul 1 la
/// ultimul, în ordine; unite, punctele fac un desen. Același urmăritor ([TraceTracker]) și
/// aceleași măsurători (ieșiri de pe drum, abaterea medie), pe alt material: drumul nu e
/// desenat, copilul îl construiește din puncte (planificare motorie + ordinea numerelor).
library;

import 'dart:math';

import 'reaction.dart' show ramp;
import 'trace.dart';

/// Un desen din puncte, în pătratul 0…1 (y în jos). Punctele se unesc în ordine; la desenele
/// închise ultimul punct e chiar primul (nu primește alt număr).
class DotFigure {
  const DotFigure(this.id, this.name, this.emoji, this.vertices);

  final String id;

  /// Rostit la final („O casă!”).
  final String name;

  /// Ce apare la final, ca recompensă.
  final String emoji;
  final List<Point<double>> vertices;

  bool get closed => vertices.first == vertices.last;

  /// Câte puncte numerotate are (cel închis nu-și repetă primul punct).
  int get dots => closed ? vertices.length - 1 : vertices.length;
}

List<Point<double>> _star() => [
      for (var i = 0; i <= 10; i++)
        Point(0.5 + (i.isEven ? 0.45 : 0.19) * sin(i * pi / 5), 0.53 - (i.isEven ? 0.45 : 0.19) * cos(i * pi / 5)),
    ];

List<Point<double>> _heart() {
  // Curba clasică a inimii, eșantionată în 12 puncte, pornind de la vârful de jos.
  Point<double> at(double t) {
    final x = 16 * pow(sin(t), 3);
    final y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t);
    return Point(0.5 + x / 36, 0.47 - y / 36);
  }

  return [for (var i = 0; i <= 12; i++) at(pi + i * 2 * pi / 12)];
}

final dotFigures = <DotFigure>[
  const DotFigure('triunghi', 'Un triunghi!', '🔺', [Point(0.5, 0.1), Point(0.9, 0.85), Point(0.1, 0.85), Point(0.5, 0.1)]),
  const DotFigure('patrat', 'Un pătrat!', '🟦', [Point(0.15, 0.15), Point(0.85, 0.15), Point(0.85, 0.85), Point(0.15, 0.85), Point(0.15, 0.15)]),
  const DotFigure('zmeu', 'Un zmeu!', '🪁', [Point(0.5, 0.05), Point(0.85, 0.4), Point(0.5, 0.95), Point(0.15, 0.4), Point(0.5, 0.05)]),
  const DotFigure('casa', 'O casă!', '🏠', [Point(0.15, 0.9), Point(0.15, 0.45), Point(0.5, 0.1), Point(0.85, 0.45), Point(0.85, 0.9), Point(0.15, 0.9)]),
  const DotFigure('barca', 'O barcă!', '⛵', [
    Point(0.05, 0.62), Point(0.25, 0.9), Point(0.75, 0.9), Point(0.95, 0.62), //
    Point(0.5, 0.62), Point(0.5, 0.08), Point(0.85, 0.52), Point(0.52, 0.52),
  ]),
  const DotFigure('peste', 'Un pește!', '🐟', [
    Point(0.1, 0.5), Point(0.35, 0.25), Point(0.65, 0.3), Point(0.8, 0.45), Point(0.95, 0.25), //
    Point(0.95, 0.75), Point(0.8, 0.55), Point(0.65, 0.7), Point(0.35, 0.75), Point(0.1, 0.5),
  ]),
  DotFigure('steaua', 'O stea!', '⭐', _star()),
  const DotFigure('brad', 'Un brad!', '🌲', [
    Point(0.5, 0.05), Point(0.75, 0.35), Point(0.62, 0.35), Point(0.85, 0.65), Point(0.58, 0.65), Point(0.58, 0.92), //
    Point(0.42, 0.92), Point(0.42, 0.65), Point(0.15, 0.65), Point(0.38, 0.35), Point(0.25, 0.35), Point(0.5, 0.05),
  ]),
  DotFigure('inima', 'O inimă!', '❤️', _heart()),
];

/// Câte puncte poate avea un desen la [level]: 3–4 → 12.
int maxDotsFor(int level) => switch (level) {
      1 => 4,
      2 || 3 => 5,
      4 || 5 => 8,
      6 || 7 => 10,
      _ => 12,
    };

/// Desenele potrivite nivelului: cele noi (cu cele mai multe puncte permise) au întâietate.
List<DotFigure> figuresFor(int level) => [for (final f in dotFigures) if (f.dots <= maxDotsFor(level)) f];

/// Linia frântă prin vârfuri, cu puncte dese pe fiecare latură (pentru urmăritorul degetului).
/// Desenul (pătratul 0…1) e pus în mijlocul ecranului, păstrându-și proporțiile pe un ecran
/// landscape obișnuit (raportul ~1,75).
List<Point<double>> dotPathPoints(DotFigure f, {double fieldAspect = 1.75}) {
  const height = 0.76;
  final width = height / fieldAspect;
  Point<double> place(Point<double> p) => Point(0.5 + (p.x - 0.5) * width, 0.5 + (p.y - 0.5) * height);
  final out = <Point<double>>[];
  for (var i = 1; i < f.vertices.length; i++) {
    final a = place(f.vertices[i - 1]), b = place(f.vertices[i]);
    for (var k = 0; k < 12; k++) {
      final t = k / 12;
      out.add(Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
    }
  }
  out.add(place(f.vertices.last));
  return out;
}

/// Punctele numerotate, în coordonatele ecranului (aceeași așezare ca [dotPathPoints]).
List<Point<double>> dotMarks(DotFigure f, {double fieldAspect = 1.75}) {
  const height = 0.76;
  final width = height / fieldAspect;
  return [
    for (final p in f.vertices.take(f.dots)) Point(0.5 + (p.x - 0.5) * width, 0.5 + (p.y - 0.5) * height),
  ];
}

/// Jocul: un [TraceGame] cu desene din puncte în loc de drumuri.
class DotsGame extends TraceGame {
  const DotsGame();

  @override
  String get id => 'uneste-punctele';
  @override
  String get name => 'Unește punctele';
  @override
  String get emoji => '✏️';
  @override
  String get description => 'Unește punctele în ordine';

  static const says = 'Unește punctele în ordine.';

  @override
  TraceAxes axesFor(int level) => TraceAxes(
        shapes: const [TraceShape.line],
        // Toleranța față de linie se strânge: 0,2 → 0,1 din înălțime.
        width: ramp(level, 0.2, 0.1, 10),
        // Punctul următor pulsează (nivelurile 1–3), apoi doar numerele; de la 8, puncte mai mici.
        guide: level <= 3 ? TraceGuide.dots : (level <= 7 ? TraceGuide.arrow : TraceGuide.none),
        paths: level <= 3 ? 3 : 4,
      );

  @override
  TraceLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final pool = figuresFor(level);
    // Cele mai grele desene permise întâi (ce e nou la nivel), apoi restul, fără repetări.
    final hardest = pool.where((f) => f.dots > maxDotsFor(max(1, level - 2))).toList()..shuffle(random);
    final rest = pool.where((f) => !hardest.contains(f)).toList()..shuffle(random);
    final chosen = [...hardest, ...rest].take(axes.paths).toList()..shuffle(random);
    return TraceLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      paths: [
        for (final (i, f) in chosen.indexed)
          TracePath(
            index: i,
            shape: TraceShape.line,
            points: dotPathPoints(f),
            trip: TraceTrip('✏️', f.emoji, says),
            figure: f,
          ),
      ],
    );
  }
}
