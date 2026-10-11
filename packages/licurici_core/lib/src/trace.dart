/// Trasează (MOT1–4, catalog #48): copilul duce cu degetul un personaj pe un drum până la
/// ținta lui (albina la floare). Nivelurile sunt generate din seed (ADR-027): drumul trece
/// de la linie dreaptă la arc, val, zig-zag și buclă, se îngustează, iar ghidajul dispare.
///
/// Logica urmăririi ([TraceTracker]) e aici, pură și testată: UI-ul doar îi trimite poziția
/// degetului și desenează progresul. KPI: **abaterea medie** de la drum și **ieșirile**.
library;

import 'dart:math';

import 'dots.dart';
import 'grades.dart';

enum TraceShape { line, diagonal, arc, wave, zigzag, loop }

/// Ce ajutor vizual are drumul.
enum TraceGuide {
  /// Puncte pe mijlocul drumului + săgeata de start.
  dots,

  /// Doar săgeata de start.
  arrow,

  /// Fără ajutor.
  none,
}

class TraceAxes {
  const TraceAxes({
    required this.shapes,
    required this.width,
    required this.guide,
    required this.paths,
  });

  /// Formele din care se aleg drumurile nivelului.
  final List<TraceShape> shapes;

  /// Lățimea drumului, ca fracție din înălțimea zonei de joc (0.24 → 0.1).
  final double width;
  final TraceGuide guide;

  /// Câte drumuri are nivelul.
  final int paths;

  Map<String, Object> toJson() => {
        'shapes': shapes.map((s) => s.name).join(','),
        'width': width,
        'guide': guide.name,
        'paths': paths,
      };
}

/// Cine pleacă și unde ajunge (poveste mică pentru fiecare drum).
class TraceTrip {
  const TraceTrip(this.traveler, this.goal, this.says);

  final String traveler;
  final String goal;

  /// Rostit la început: „Du albina la floare.”
  final String says;
}

const traceTrips = [
  TraceTrip('🐝', '🌸', 'Du albina la floare.'),
  TraceTrip('🐶', '🏠', 'Du cățelul acasă.'),
  TraceTrip('🐇', '🥕', 'Du iepurașul la morcov.'),
  TraceTrip('🐿️', '🌳', 'Du veverița la copac.'),
  TraceTrip('🦋', '🌷', 'Du fluturele la lalea.'),
  TraceTrip('🐱', '🥛', 'Du pisica la lapte.'),
  TraceTrip('🚗', '🏠', 'Du mașina acasă.'),
  TraceTrip('🐢', '💧', 'Du broasca țestoasă la apă.'),
];

/// Un drum: puncte dese (0…1 în zona de joc, y în jos), de la start la țintă.
class TracePath {
  const TracePath({
    required this.index,
    required this.shape,
    required this.points,
    required this.trip,
    this.figure,
  });

  final int index;
  final TraceShape shape;
  final List<Point<double>> points;
  final TraceTrip trip;

  /// La „Unește punctele”: desenul din puncte (punctele numerotate se desenează din el).
  final DotFigure? figure;

  /// Lungimea drumului în unități de înălțime, pentru o zonă cu raportul [aspect] (lățime/înălțime).
  double length(double aspect) {
    var l = 0.0;
    for (var i = 1; i < points.length; i++) {
      l += _scaled(points[i - 1], aspect).distanceTo(_scaled(points[i], aspect));
    }
    return l;
  }
}

Point<double> _scaled(Point<double> p, double aspect) => Point(p.x * aspect, p.y);

/// Distanța de la punctul [p] la segmentul [a]–[b].
double _toSegment(Point<double> p, Point<double> a, Point<double> b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return p.distanceTo(Point(a.x + t * dx, a.y + t * dy));
}

class TraceLevel {
  const TraceLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.paths,
  });

  final String gameId;
  final int level;
  final int seed;
  final TraceAxes axes;
  final List<TracePath> paths;

  Set<String> get art => {for (final p in paths) ...[p.trip.traveler, p.trip.goal]};
}

/// Urmărirea degetului pe un drum. Personajul înaintează doar cât degetul rămâne pe drum,
/// lângă el (nu se poate „sări” peste o bucată); dacă degetul iese, personajul așteaptă —
/// fără penalizare vizibilă, doar se numără ieșirea (o dată pe ieșire).
class TraceTracker {
  TraceTracker(this.path, {required this.width, required this.aspect})
      : _pts = [for (final p in path.points) _scaled(p, aspect)];

  final TracePath path;

  /// Lățimea drumului (unități de înălțime).
  final double width;
  final double aspect;
  final List<Point<double>> _pts;

  int _progress = 0;
  int _exits = 0;
  bool _outside = false;
  bool _holding = false;
  double _deviationSum = 0;
  int _samples = 0;

  /// Indexul punctului atins (0 … points.length − 1).
  int get progress => _progress;
  double get fraction => _progress / (_pts.length - 1);
  bool get done => _progress >= _pts.length - 1;
  int get exits => _exits;

  /// Abaterea medie de la mijlocul drumului, în lățimi de drum (0 = pe mijloc, 0.5 = la margine).
  double get meanDeviation => _samples == 0 ? 0 : _deviationSum / _samples / width;

  /// Cât de departe poate fi degetul de personaj ca să-l „prindă” (o lățime de drum).
  double get _grab => width;

  /// Cât poate ieși degetul de pe mijloc fără să se considere ieșire (marginea + toleranță).
  double get _tolerance => width * 0.75;

  /// Unde e personajul acum (coordonate 0…1).
  Point<double> get position => path.points[_progress];

  /// Degetul atinge ecranul la [x], [y] (0…1). Întoarce true dacă a „prins” personajul.
  bool down(double x, double y) {
    final p = Point(x * aspect, y);
    _holding = p.distanceTo(_pts[_progress]) <= _grab;
    _outside = false;
    if (_holding) move(x, y);
    return _holding;
  }

  /// Degetul s-a mișcat. Întoarce progresul.
  int move(double x, double y) {
    if (!_holding || done) return _progress;
    final p = Point(x * aspect, y);
    // Căutăm înainte, într-o fereastră scurtă: personajul nu sare peste bucle sau colțuri.
    final window = max(3, (_pts.length * 0.12).round());
    var best = -1;
    var bestDist = double.infinity;
    for (var i = _progress; i < min(_pts.length - 1, _progress + window); i++) {
      final d = _toSegment(p, _pts[i], _pts[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best < 0) return _progress;
    if (bestDist > _tolerance) {
      if (!_outside) _exits++;
      _outside = true;
      return _progress;
    }
    _outside = false;
    _deviationSum += bestDist;
    _samples++;
    // Avansează până la capătul segmentului cel mai apropiat dacă degetul e mai aproape de el.
    final next = best + 1;
    final target = p.distanceTo(_pts[next]) < p.distanceTo(_pts[best]) ? next : best;
    if (target > _progress) _progress = target;
    return _progress;
  }

  void up() => _holding = false;

  TraceRun result({int? ms}) => TraceRun(
        path: path,
        completed: done,
        exits: _exits,
        meanDeviation: meanDeviation,
        ms: ms,
      );
}

class TraceRun {
  const TraceRun({
    required this.path,
    required this.completed,
    required this.exits,
    required this.meanDeviation,
    this.ms,
  });

  final TracePath path;
  final bool completed;
  final int exits;
  final double meanDeviation;
  final int? ms;

  /// Curat: dus până la capăt fără să iasă de pe drum.
  bool get clean => completed && exits == 0;
}

class TraceResult {
  TraceResult(this.level, List<TraceRun> runs) : runs = List.unmodifiable(runs);

  final TraceLevel level;
  final List<TraceRun> runs;

  double get accuracy => runs.isEmpty ? 0 : runs.where((r) => r.clean).length / runs.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  /// Toate curate → +1; sub 50% → −1; altfel rămâne.
  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class TraceGame {
  const TraceGame();

  String get id => 'traseaza';
  String get name => 'Trasează';
  String get emoji => '✏️';
  String get description => 'Du-l pe drum până la capăt';
  Set<Grade> get grades => Grade.parseCodes('G12');
  List<String> get steps => const ['MOT1', 'MOT2', 'MOT3'];

  TraceAxes axesFor(int level) {
    final shapes = switch (level) {
      1 => [TraceShape.line],
      2 => [TraceShape.line, TraceShape.diagonal],
      3 => [TraceShape.diagonal, TraceShape.arc],
      4 => [TraceShape.arc, TraceShape.wave],
      5 => [TraceShape.wave, TraceShape.zigzag],
      6 => [TraceShape.zigzag, TraceShape.wave, TraceShape.loop],
      _ => TraceShape.values.skip(2).toList(),
    };
    final t = ((level - 1) / 9).clamp(0.0, 1.0);
    return TraceAxes(
      shapes: shapes,
      width: 0.24 - 0.14 * t,
      guide: level <= 3 ? TraceGuide.dots : (level <= 6 ? TraceGuide.arrow : TraceGuide.none),
      paths: level <= 2 ? 4 : (level <= 6 ? 5 : 6),
    );
  }

  TraceLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final trips = [...traceTrips]..shuffle(random);
    return TraceLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      paths: [
        for (var i = 0; i < axes.paths; i++)
          TracePath(
            index: i,
            shape: axes.shapes[i % axes.shapes.length],
            points: shapePoints(axes.shapes[i % axes.shapes.length], random, level: level),
            trip: trips[i % trips.length],
          ),
      ],
    );
  }

  /// Punctele unei forme, de la stânga la dreapta (sensul scrisului), în [0.08, 0.92].
  static List<Point<double>> shapePoints(TraceShape shape, Random random, {int level = 1}) {
    const n = 80;
    const x0 = 0.12, x1 = 0.88;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    final pts = <Point<double>>[];
    switch (shape) {
      case TraceShape.line:
        final y = 0.35 + random.nextDouble() * 0.3;
        for (var i = 0; i <= n; i++) {
          pts.add(Point(lerp(x0, x1, i / n), y));
        }
      case TraceShape.diagonal:
        final down = random.nextBool();
        for (var i = 0; i <= n; i++) {
          final t = i / n;
          pts.add(Point(lerp(x0, x1, t), down ? lerp(0.22, 0.78, t) : lerp(0.78, 0.22, t)));
        }
      case TraceShape.arc:
        final up = random.nextBool();
        for (var i = 0; i <= n; i++) {
          final t = i / n;
          final h = 0.5 * sin(pi * t);
          pts.add(Point(lerp(x0, x1, t), up ? 0.78 - h : 0.22 + h));
        }
      case TraceShape.wave:
        final k = level < 6 ? 1 : 2;
        final phase = random.nextBool() ? 0.0 : pi;
        for (var i = 0; i <= n; i++) {
          final t = i / n;
          pts.add(Point(lerp(x0, x1, t), 0.5 + 0.28 * sin(2 * pi * k * t + phase)));
        }
      case TraceShape.zigzag:
        final teeth = level < 7 ? 2 : 3;
        final startHigh = random.nextBool();
        for (var i = 0; i <= n; i++) {
          final t = i / n;
          final u = (t * teeth * 2) % 2; // 0…2: urcă, apoi coboară
          final tri = u < 1 ? u : 2 - u;
          final y = startHigh ? lerp(0.25, 0.75, tri) : lerp(0.75, 0.25, tri);
          pts.add(Point(lerp(x0, x1, t), y));
        }
      case TraceShape.loop:
        // O buclă ca în scrisul de mână: înainte, un cerc mic deasupra, apoi mai departe.
        for (var i = 0; i <= n; i++) {
          final t = i / n;
          final a = 2 * pi * t;
          pts.add(Point(lerp(x0, x1, t) - 0.14 * sin(a), 0.62 - 0.22 * (1 - cos(a))));
        }
    }
    return [
      for (final p in pts) Point(p.x.clamp(0.08, 0.92), p.y.clamp(0.08, 0.92)),
    ];
  }
}
