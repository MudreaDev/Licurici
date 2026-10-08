/// Scriem cifrele (catalog #21) și Scriem literele (#7): copilul urmărește cu degetul
/// trăsăturile unei cifre sau ale unei litere de tipar, **în ordinea și în sensul în care se
/// scriu** (de sus în jos, de la stânga la dreapta, cercurile pornind de sus). Fiecare
/// trăsătură e un drum urmărit cu [TraceTracker] (aceeași logică ca la „Trasează”).
///
/// Nivelurile sunt generate din seed (ADR-027). Axe: setul de semne (cele din linii drepte →
/// cele cu curbe → cele cu mai multe trăsături → diacriticele), lățimea drumului, ajutorul
/// (puncte + săgeți → doar săgeata de start → nimic).
/// KPI: semne scrise curat (fără ieșiri), abaterea medie, ieșirile.
library;

import 'dart:math';

import 'grades.dart';
import 'trace.dart';

/// Un semn de scris: trăsăturile lui, în ordine. Coordonatele sunt în „unități de semn”:
/// y ∈ [0, 1] de sus în jos (accentele ies puțin în afară), x de la 0 spre dreapta.
class Glyph {
  Glyph(this.char, this.strokes, {this.word, this.picture});

  final String char;
  final List<List<Point<double>>> strokes;

  /// Un cuvânt care începe cu semnul și ilustrația lui (emoji din baza de obiecte), dacă există.
  final String? word;
  final String? picture;

  /// Marginile semnului (toate trăsăturile).
  ({double left, double top, double right, double bottom}) get bounds {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final s in strokes) {
      for (final p in s) {
        l = min(l, p.x);
        t = min(t, p.y);
        r = max(r, p.x);
        b = max(b, p.y);
      }
    }
    return (left: l, top: t, right: r, bottom: b);
  }

  /// Trăsăturile așezate în zona de joc (0…1, cu raportul [aspect] = lățime / înălțime):
  /// semnul ocupă [height] din înălțime, centrat. Rezultatul e gata pentru [TraceTracker].
  List<TracePath> fit(double aspect, {double height = 0.74}) {
    final b = bounds;
    final h = max(1e-6, b.bottom - b.top);
    final k = min(height / h, aspect * 0.8 / max(1e-6, b.right - b.left));
    final ox = aspect / 2 - (b.left + b.right) / 2 * k, oy = 0.5 - (b.top + b.bottom) / 2 * k;
    return [
      for (final (i, s) in strokes.indexed)
        TracePath(
          index: i,
          shape: TraceShape.line,
          points: [for (final p in s) Point((ox + p.x * k) / aspect, oy + p.y * k)],
          trip: const TraceTrip('⭐', '⭐', ''),
        ),
    ];
  }
}

// --- Construcția trăsăturilor --------------------------------------------------------------

List<Point<double>> _line(List<List<double>> pts) => [for (final p in pts) Point(p[0], p[1])];

/// Curbă Catmull-Rom deschisă prin toate punctele.
List<Point<double>> _curve(List<List<double>> pts) {
  final p = [for (final q in pts) Point(q[0], q[1])];
  final out = <Point<double>>[];
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(p.length - 1, i + 2)];
    for (var s = 0; s < 12; s++) {
      final t = s / 12, t2 = t * t, t3 = t2 * t;
      out.add(Point(
        0.5 * (2 * p1.x + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
        0.5 * (2 * p1.y + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3),
      ));
    }
  }
  out.add(p.last);
  return out;
}

/// Arc de elipsă: unghiuri în grade, 0 = dreapta, 90 = jos; [sweep] negativ = invers acelor
/// de ceasornic pe ecran (cum se scrie „O”: de sus, spre stânga).
List<Point<double>> _arc(double cx, double cy, double rx, double ry, double start, double sweep) {
  final n = max(8, (sweep.abs() / 6).round());
  return [
    for (var i = 0; i <= n; i++)
      Point(cx + rx * cos((start + sweep * i / n) * pi / 180), cy + ry * sin((start + sweep * i / n) * pi / 180)),
  ];
}

/// Trăsătura din bucăți lipite, apoi împărțită în puncte egal depărtate (pas [step]).
List<Point<double>> _stroke(List<List<Point<double>>> parts, {double step = 0.012}) {
  final raw = <Point<double>>[];
  for (final part in parts) {
    for (final p in part) {
      if (raw.isEmpty || raw.last.distanceTo(p) > 1e-9) raw.add(p);
    }
  }
  final out = <Point<double>>[raw.first];
  var acc = 0.0; // drumul parcurs de la ultimul punct pus
  for (var i = 1; i < raw.length; i++) {
    final a = raw[i - 1], b = raw[i];
    final d = a.distanceTo(b);
    var pos = 0.0;
    while (acc + (d - pos) >= step) {
      pos += step - acc;
      acc = 0;
      out.add(Point(a.x + (b.x - a.x) * pos / d, a.y + (b.y - a.y) * pos / d));
    }
    acc += d - pos;
  }
  if (out.last.distanceTo(raw.last) > step * 0.3) out.add(raw.last);
  return out;
}

Glyph _g(String c, List<List<List<Point<double>>>> strokes, {String? word, String? picture}) =>
    Glyph(c, [for (final s in strokes) _stroke(s)], word: word, picture: picture);

// --- Cifrele -----------------------------------------------------------------------------

final digitGlyphs = <Glyph>[
  _g('0', [[_arc(0.3, 0.5, 0.28, 0.48, -90, -360)]], word: 'zero'),
  _g('1', [[_line([[0.08, 0.26], [0.36, 0], [0.36, 1]])]], word: 'unu'),
  _g('2', [[_arc(0.3, 0.28, 0.27, 0.26, 195, 205), _line([[0.53, 0.42], [0.03, 1], [0.6, 1]])]], word: 'doi'),
  _g('3', [[_arc(0.29, 0.25, 0.26, 0.24, 200, 250), _arc(0.29, 0.745, 0.29, 0.255, -90, 255)]], word: 'trei'),
  _g('4', [[_line([[0.44, 0], [0.02, 0.68], [0.62, 0.68]])], [_line([[0.46, 0.32], [0.46, 1]])]], word: 'patru'),
  _g('5', [[_line([[0.1, 0], [0.07, 0.44]]), _curve([[0.07, 0.44], [0.3, 0.38], [0.54, 0.47], [0.62, 0.7], [0.52, 0.93], [0.3, 1], [0.04, 0.9]])], [_line([[0.1, 0], [0.58, 0]])]], word: 'cinci'),
  _g('6', [[_curve([[0.52, 0.02], [0.3, 0.12], [0.12, 0.34], [0.04, 0.62], [0.1, 0.88], [0.3, 1], [0.52, 0.92], [0.6, 0.72], [0.52, 0.52], [0.3, 0.46], [0.12, 0.54], [0.05, 0.66]])]], word: 'șase'),
  _g('7', [[_line([[0.02, 0], [0.6, 0], [0.2, 1]])]], word: 'șapte'),
  _g('8', [[_curve([[0.56, 0.13], [0.32, 0], [0.1, 0.1], [0.12, 0.3], [0.32, 0.46], [0.56, 0.62], [0.6, 0.85], [0.32, 1], [0.06, 0.86], [0.08, 0.62], [0.32, 0.46], [0.52, 0.32], [0.56, 0.13]])]], word: 'opt'),
  _g('9', [[_arc(0.3, 0.28, 0.27, 0.28, 0, -360), _line([[0.57, 0.28], [0.52, 1]])]], word: 'nouă'),
];

// --- Literele de tipar --------------------------------------------------------------------

List<List<Point<double>>> _o() => [_arc(0.42, 0.5, 0.4, 0.5, -90, -360)];
List<List<Point<double>>> _a1() => [_line([[0.4, 0], [0.02, 1]])];
List<List<Point<double>>> _a2() => [_line([[0.4, 0], [0.78, 1]])];
List<List<Point<double>>> _a3() => [_line([[0.17, 0.62], [0.63, 0.62]])];
List<List<Point<double>>> _vert(double x) => [_line([[x, 0], [x, 1]])];
List<List<Point<double>>> _s() => [
  _curve([[0.62, 0.12], [0.45, 0.01], [0.24, 0.02], [0.08, 0.15], [0.1, 0.35], [0.35, 0.48], [0.58, 0.6], [0.64, 0.8], [0.5, 0.97], [0.28, 1], [0.06, 0.88]]),
];
List<List<Point<double>>> _comma(double x) => [_curve([[x, 1.12], [x - 0.02, 1.24], [x - 0.08, 1.36]])];
List<List<Point<double>>> _hat(double x) => [_line([[x - 0.16, -0.1], [x, -0.26], [x + 0.16, -0.1]])];

final letterGlyphs = <Glyph>[
  _g('A', [_a1(), _a2(), _a3()], word: 'albină', picture: '🐝'),
  _g('B', [_vert(0.08), [_line([[0.08, 0], [0.36, 0]]), _curve([[0.36, 0], [0.58, 0.08], [0.6, 0.26], [0.48, 0.44], [0.36, 0.48]]), _line([[0.36, 0.48], [0.08, 0.48]])], [_line([[0.08, 0.48], [0.4, 0.48]]), _curve([[0.4, 0.48], [0.64, 0.6], [0.66, 0.8], [0.54, 0.96], [0.38, 1]]), _line([[0.38, 1], [0.08, 1]])]], word: 'balon', picture: '🎈'),
  _g('C', [[_arc(0.42, 0.5, 0.4, 0.5, -40, -280)]], word: 'casă', picture: '🏠'),
  _g('D', [_vert(0.08), [_line([[0.08, 0], [0.3, 0]]), _curve([[0.3, 0], [0.6, 0.12], [0.7, 0.5], [0.6, 0.88], [0.3, 1]]), _line([[0.3, 1], [0.08, 1]])]], word: 'delfin', picture: '🐬'),
  _g('E', [_vert(0.08), [_line([[0.08, 0], [0.6, 0]])], [_line([[0.08, 0.5], [0.5, 0.5]])], [_line([[0.08, 1], [0.6, 1]])]], word: 'elefant', picture: '🐘'),
  _g('F', [_vert(0.08), [_line([[0.08, 0], [0.6, 0]])], [_line([[0.08, 0.5], [0.5, 0.5]])]], word: 'fluture', picture: '🦋'),
  _g('G', [[_arc(0.42, 0.5, 0.4, 0.5, -40, -300), _line([[0.796, 0.67], [0.8, 0.54], [0.52, 0.54]])]], word: 'girafă', picture: '🦒'),
  _g('H', [_vert(0.08), _vert(0.66), [_line([[0.08, 0.5], [0.66, 0.5]])]]),
  _g('I', [_vert(0.1)], word: 'iepuraș', picture: '🐇'),
  _g('J', [[_line([[0.46, 0], [0.46, 0.7]]), _curve([[0.46, 0.7], [0.4, 0.92], [0.24, 1], [0.08, 0.9], [0.03, 0.75]])]], word: 'jucărie', picture: '🧸'),
  _g('K', [_vert(0.08), [_line([[0.62, 0], [0.08, 0.56]])], [_line([[0.26, 0.4], [0.66, 1]])]]),
  _g('L', [[_line([[0.08, 0], [0.08, 1], [0.58, 1]])]], word: 'lună', picture: '🌙'),
  _g('M', [[_line([[0.06, 1], [0.06, 0], [0.42, 0.62], [0.78, 0], [0.78, 1]])]], word: 'măr', picture: '🍎'),
  _g('N', [[_line([[0.08, 1], [0.08, 0], [0.66, 1], [0.66, 0]])]], word: 'nor', picture: '☁️'),
  _g('O', [_o()], word: 'ou', picture: '🥚'),
  _g('P', [_vert(0.08), [_line([[0.08, 0], [0.36, 0]]), _curve([[0.36, 0], [0.6, 0.08], [0.64, 0.27], [0.52, 0.46], [0.36, 0.52]]), _line([[0.36, 0.52], [0.08, 0.52]])]], word: 'pisică', picture: '🐱'),
  _g('R', [_vert(0.08), [_line([[0.08, 0], [0.36, 0]]), _curve([[0.36, 0], [0.6, 0.08], [0.64, 0.27], [0.52, 0.46], [0.36, 0.52]]), _line([[0.36, 0.52], [0.08, 0.52]])], [_line([[0.32, 0.52], [0.66, 1]])]], word: 'rață', picture: '🦆'),
  _g('S', [_s()], word: 'soare', picture: '☀️'),
  _g('T', [[_line([[0.02, 0], [0.72, 0]])], _vert(0.37)], word: 'tobă', picture: '🥁'),
  _g('U', [[_line([[0.06, 0], [0.06, 0.66]]), _curve([[0.06, 0.66], [0.13, 0.9], [0.36, 1], [0.59, 0.9], [0.66, 0.66]]), _line([[0.66, 0.66], [0.66, 0]])]], word: 'urs', picture: '🐻'),
  _g('V', [[_line([[0.02, 0], [0.37, 1], [0.72, 0]])]], word: 'vacă', picture: '🐄'),
  _g('X', [[_line([[0.04, 0], [0.68, 1]])], [_line([[0.68, 0], [0.04, 1]])]]),
  _g('Z', [[_line([[0.04, 0], [0.66, 0], [0.04, 1], [0.68, 1]])]], word: 'zebră', picture: '🦓'),
  _g('Ă', [_a1(), _a2(), _a3(), [_curve([[0.24, -0.26], [0.4, -0.12], [0.56, -0.26]])]]),
  _g('Â', [_a1(), _a2(), _a3(), _hat(0.4)]),
  _g('Î', [_vert(0.1), _hat(0.1)]),
  _g('Ș', [_s(), _comma(0.36)], word: 'șosete', picture: '🧦'),
  _g('Ț', [[_line([[0.02, 0], [0.72, 0]])], _vert(0.37), _comma(0.4)], word: 'țestoasă', picture: '🐢'),
];

Glyph? glyphFor(String char) {
  for (final g in [...digitGlyphs, ...letterGlyphs]) {
    if (g.char == char) return g;
  }
  return null;
}

// --- Nivelurile ---------------------------------------------------------------------------

class WritingAxes {
  const WritingAxes({required this.pool, required this.width, required this.guide, required this.glyphs});

  /// Semnele din care se aleg cele ale nivelului.
  final List<String> pool;

  /// Lățimea drumului (fracție din înălțimea zonei de joc).
  final double width;
  final TraceGuide guide;

  /// Câte semne are nivelul.
  final int glyphs;

  Map<String, Object> toJson() => {'pool': pool.join(), 'width': width, 'guide': guide.name, 'glyphs': glyphs};
}

class WritingLevel {
  const WritingLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.glyphs});

  final String gameId;
  final int level;
  final int seed;
  final WritingAxes axes;
  final List<Glyph> glyphs;
}

/// Un semn scris: câte o urmărire pe trăsătură.
class WritingRun {
  const WritingRun(this.glyph, this.strokes, {this.ms});

  final Glyph glyph;
  final List<TraceRun> strokes;
  final int? ms;

  bool get completed => strokes.length == glyph.strokes.length && strokes.every((s) => s.completed);
  int get exits => strokes.fold(0, (a, s) => a + s.exits);
  double get meanDeviation => strokes.isEmpty ? 0 : strokes.fold(0.0, (a, s) => a + s.meanDeviation) / strokes.length;

  /// Curat: toate trăsăturile, fără să iasă de pe drum.
  bool get clean => completed && exits == 0;
}

class WritingResult {
  WritingResult(this.level, List<WritingRun> runs) : runs = List.unmodifiable(runs);

  final WritingLevel level;
  final List<WritingRun> runs;

  double get accuracy => runs.isEmpty ? 0 : runs.where((r) => r.clean).length / runs.length;
  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.4) return max(1, current - 1);
    return current;
  }
}

/// „Scriem cifrele” și „Scriem literele”: același joc, alt set de semne.
class WritingGame {
  const WritingGame._(this.id, this.name, this.emoji, this.description, this.steps, this._sets);

  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> steps;

  /// Seturile de semne, de la ușor la greu (nivelul le deblochează pe rând).
  final List<String> _sets;

  Set<Grade> get grades => Grade.parseCodes('G12');

  bool get digits => id == 'scriem-cifrele';

  /// Rostit la început: „Scrie cifra 3.” / „Scrie litera A.”
  String instructionFor(Glyph g) => 'Scrie ${digits ? 'cifra' : 'litera'} ${g.char}.';

  /// Rostit când semnul e gata: cifra cu numele ei („trei”), litera cu un cuvânt
  /// („A, ca în albină.”) sau singură.
  String praiseFor(Glyph g) => digits ? g.word ?? g.char : (g.word == null ? g.char : '${g.char}, ca în ${g.word}.');

  /// Toate semnele jocului.
  List<Glyph> get allGlyphs => [for (final c in _sets.join().split('')) glyphFor(c)!];

  WritingAxes axesFor(int level) {
    // La fiecare 2 niveluri se adaugă un set nou; setul nou e cel mai des exersat.
    final unlocked = min(_sets.length, 1 + (level - 1) ~/ 2);
    final pool = [for (final s in _sets.take(unlocked)) ...s.split('')];
    final t = ((level - 1) / 9).clamp(0.0, 1.0);
    return WritingAxes(
      pool: pool,
      width: 0.17 - 0.07 * t,
      guide: level <= 3 ? TraceGuide.dots : (level <= 7 ? TraceGuide.arrow : TraceGuide.none),
      glyphs: level <= 2 ? 3 : 4,
    );
  }

  WritingLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final unlocked = min(_sets.length, 1 + (level - 1) ~/ 2);
    final newest = _sets[unlocked - 1].split('')..shuffle(random);
    final rest = [...axes.pool.where((c) => !newest.contains(c))]..shuffle(random);
    // Jumătate din setul cel nou, restul recapitulare; fără repetări.
    final picks = <String>[...newest.take((axes.glyphs + 1) ~/ 2)];
    for (final c in [...rest, ...newest]) {
      if (picks.length >= axes.glyphs) break;
      if (!picks.contains(c)) picks.add(c);
    }
    picks.shuffle(random);
    return WritingLevel(gameId: id, level: level, seed: s, axes: axes, glyphs: [for (final c in picks) glyphFor(c)!]);
  }
}

const writeDigits = WritingGame._('scriem-cifrele', 'Scriem cifrele', '✍️', 'Urmărește cifra cu degetul', ['PAC-N3'], [
  '1074', // linii și cercul
  '25', // o curbă și o linie
  '369', // curbe
  '8', // cea mai grea
]);

const writeLetters = WritingGame._('scriem-literele', 'Scriem literele', '🔤', 'Urmărește litera cu degetul', ['PAC-L4'], [
  'ILTEFH', // linii drepte
  'AVNMXZ', // linii oblice
  'OCUJS', // curbe
  'DPBRGK', // linii și curbe
  'ĂÂÎȘȚ', // diacriticele
]);

const writingGames = [writeDigits, writeLetters];

WritingGame? writingGameById(String id) {
  for (final g in writingGames) {
    if (g.id == id) return g;
  }
  return null;
}
