/// Linia numerelor (PAC-N5, sarcina de estimare a lui Siegler & Opfer): copilul așază un număr
/// pe o linie de la 0 la N, atingând locul. Metrica standard e **eroarea procentuală
/// absolută** (PAE = |estimare − număr| / N): scade odată cu înțelegerea mărimii numerelor și
/// prezice bine rezultatele la matematică.
///
/// Axe: capătul liniei (10 → 20 → 100) și câte repere are linia (fiecare unitate → doar
/// mijlocul → doar capetele). Numerele vin din toată linia, fără capete, fără repetări.
library;

import 'dart:math';

import 'grades.dart';

class NumberLineAxes {
  const NumberLineAxes({required this.max, required this.tick});

  /// Capătul din dreapta al liniei (0 … [max]).
  final int max;

  /// La ce distanță sunt reperele (0 = doar capetele).
  final int tick;

  Map<String, Object> toJson() => {'max': max, 'tick': tick};
}

class NumberLineRound {
  const NumberLineRound(this.target);

  final int target;
}

class NumberLineLevel {
  const NumberLineLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final NumberLineAxes axes;
  final List<NumberLineRound> rounds;
}

/// O estimare: unde a atins copilul (pe linie, în unități), cât a durat.
class NumberLineMark {
  const NumberLineMark(this.round, this.estimate, {this.latencyMs});

  final NumberLineRound round;
  final double estimate;
  final int? latencyMs;
}

class NumberLineResult {
  NumberLineResult(this.level, List<NumberLineMark> marks) : marks = List.unmodifiable(marks);

  final NumberLineLevel level;
  final List<NumberLineMark> marks;

  /// Eroarea procentuală absolută a unei estimări (0…1).
  double paeOf(NumberLineMark m) => (m.estimate - m.round.target).abs() / level.axes.max;

  /// PAE medie pe nivel (0…1); 0 dacă nu s-a jucat nimic.
  double get pae => marks.isEmpty ? 0 : marks.map(paeOf).reduce((a, b) => a + b) / marks.length;

  /// O estimare „bună”: în cel mult 10% din linie (la 0–10, cel mult o unitate).
  static const tolerance = 0.1;

  bool isClose(NumberLineMark m) => paeOf(m) <= tolerance + 1e-9;

  /// Partea estimărilor bune (0…1).
  double get accuracy => marks.isEmpty ? 0 : marks.where(isClose).length / marks.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  /// Nivelul următor: aproape toate aproape → mai greu; sub jumătate → mai ușor.
  int suggestedNextLevel(int current) {
    if (marks.isEmpty) return current;
    final close = marks.where(isClose).length / marks.length;
    if (close >= 0.8) return current + 1;
    if (close < 0.5) return max(1, current - 1);
    return current;
  }
}

class NumberLineGame {
  const NumberLineGame();

  String get id => 'linia-numerelor';
  String get name => 'Linia numerelor';
  String get emoji => '📏';
  String get description => 'Pune numărul la locul lui pe linie';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['PAC-N5'];

  /// Câte numere pe nivel.
  static const rounds = 6;

  NumberLineAxes axesFor(int level) => switch (level) {
        1 => const NumberLineAxes(max: 10, tick: 1),
        2 => const NumberLineAxes(max: 10, tick: 5),
        3 => const NumberLineAxes(max: 10, tick: 0),
        4 => const NumberLineAxes(max: 20, tick: 10),
        5 => const NumberLineAxes(max: 20, tick: 0),
        6 => const NumberLineAxes(max: 100, tick: 10),
        7 => const NumberLineAxes(max: 100, tick: 50),
        _ => const NumberLineAxes(max: 100, tick: 0),
      };

  NumberLineLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    // Câte un număr din fiecare bucată a liniei (nu toate grămadă la început), apoi amestecate.
    final targets = <int>{};
    final band = (axes.max - 1) / rounds;
    for (var k = 0; k < rounds; k++) {
      for (var guard = 0; guard < 50; guard++) {
        final t = 1 + (k * band + random.nextDouble() * band).floor();
        // Fără numerele de pe repere (acolo n-ar fi estimare) când reperele sunt rare.
        final onTick = axes.tick > 1 && t % axes.tick == 0;
        if (t >= 1 && t < axes.max && !onTick && targets.add(t)) break;
      }
    }
    final list = targets.toList()..shuffle(random);
    return NumberLineLevel(gameId: id, level: level, seed: s, axes: axes, rounds: [for (final t in list) NumberLineRound(t)]);
  }
}
