/// Hrănește peștii (MOT1–3, catalog #49): copilul trage mâncarea la peștele flămând. Control
/// motor fin: tragere precisă spre o țintă care se mișcă. Generat din seed (ADR-027): peștele
/// e mare și stă → mai mic → înoată tot mai repede; apoi mai mulți pești, doar unul flămând.
/// KPI: **precizia plasării** (distanța față de centrul peștelui) și tragerile ratate.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

class FeedAxes {
  const FeedAxes({required this.size, required this.speed, required this.fish, required this.rounds});

  /// Diametrul peștelui, ca fracție din înălțimea zonei (0.3 → 0.14).
  final double size;

  /// Viteza (lățimi de zonă pe secundă): 0 = stă pe loc.
  final double speed;

  /// Câți pești sunt în apă (doar unul e flămând).
  final int fish;
  final int rounds;

  Map<String, Object> toJson() => {'size': size, 'speed': speed, 'fish': fish, 'rounds': rounds};
}

class FeedFish {
  const FeedFish({required this.art, required this.x, required this.y, required this.dir, required this.speedFactor});

  final String art;

  /// Poziția la început (0…1).
  final double x;
  final double y;

  /// Direcția: +1 spre dreapta, −1 spre stânga.
  final int dir;

  /// Fiecare pește are viteza lui (0.8…1.2 × viteza nivelului).
  final double speedFactor;

  /// Poziția după [seconds], cu întoarcere la marginile [margin, 1 − margin].
  Point<double> at(double seconds, double speed, {double margin = 0.12}) {
    final span = 1 - 2 * margin;
    if (span <= 0 || speed == 0) return Point(x, y);
    // Mers dus-întors pe segment: „pliem” distanța parcursă.
    final d = (x - margin) + dir * speed * speedFactor * seconds;
    final period = 2 * span;
    var m = d % period;
    if (m < 0) m += period;
    final pos = m <= span ? m : period - m;
    return Point(margin + pos, y);
  }

  /// Încotro înoată în acel moment (+1 / −1), ca să privească în direcția mersului.
  int heading(double seconds, double speed, {double margin = 0.12}) {
    final a = at(seconds, speed, margin: margin).x, b = at(seconds + 0.02, speed, margin: margin).x;
    return b >= a ? 1 : -1;
  }
}

class FeedRound {
  const FeedRound({required this.fish, required this.hungry});

  final List<FeedFish> fish;

  /// Indexul peștelui flămând.
  final int hungry;
}

class FeedLevel {
  const FeedLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final FeedAxes axes;
  final List<FeedRound> rounds;

  Set<String> get art => {for (final r in rounds) ...r.fish.map((f) => f.art), feedFood};
}

const feedFood = '🍞';

/// Cum a hrănit copilul peștele unei runde.
class FeedAttempt {
  const FeedAttempt(this.round, {required this.precision, this.misses = 0, this.wrongFish = 0, this.ms});

  final FeedRound round;

  /// Distanța față de centrul peștelui la reușită, în raze de pește (0 = în centru, 1 = la margine).
  final double precision;

  /// Trageri lăsate în apă, departe de orice pește.
  final int misses;

  /// Trageri la un pește care nu era flămând.
  final int wrongFish;
  final int? ms;

  bool get clean => misses == 0 && wrongFish == 0;
}

class FeedResult {
  FeedResult(this.level, List<FeedAttempt> feeds) : feeds = List.unmodifiable(feeds);

  final FeedLevel level;
  final List<FeedAttempt> feeds;

  double get accuracy => feeds.isEmpty ? 0 : feeds.where((f) => f.clean).length / feeds.length;

  /// Precizia medie (raze de pește).
  double get meanPrecision =>
      feeds.isEmpty ? 0 : feeds.fold(0.0, (s, f) => s + f.precision) / feeds.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class FeedGame {
  const FeedGame();

  String get id => 'hraneste-pestii';
  String get name => 'Hrănește peștii';
  String get emoji => '🐟';
  String get description => 'Du mâncarea la peștele flămând';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['MOT4'];

  FeedAxes axesFor(int level) => FeedAxes(
        size: ramp(level, 0.3, 0.14, 10),
        speed: level <= 2 ? 0 : ramp(level - 2, 0.05, 0.22, 10),
        fish: level <= 5 ? 1 : (level <= 8 ? 2 : 3),
        rounds: 5,
      );

  FeedLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final rounds = <FeedRound>[];
    for (var r = 0; r < axes.rounds; r++) {
      // Pești pe benzi diferite (nu se suprapun pe verticală), sus–jos în apă.
      final lanes = [for (var i = 0; i < axes.fish; i++) i]..shuffle(random);
      final fish = [
        for (var i = 0; i < axes.fish; i++)
          FeedFish(
            art: i == 0 ? '🐟' : '🐠',
            x: 0.3 + random.nextDouble() * 0.55,
            y: axes.fish == 1 ? 0.3 + random.nextDouble() * 0.25 : 0.2 + lanes[i] * (0.5 / (axes.fish - 1)),
            dir: random.nextBool() ? 1 : -1,
            speedFactor: 0.8 + random.nextDouble() * 0.4,
          ),
      ];
      rounds.add(FeedRound(fish: fish, hungry: random.nextInt(axes.fish)));
    }
    return FeedLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
