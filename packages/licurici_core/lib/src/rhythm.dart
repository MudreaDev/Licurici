/// Toba magică (IMI2–4, catalog #7): Licurici bate un ritm la tobă, copilul îl repetă.
/// Imitație ritmică și sincronizare. Nivelurile sunt generate din seed (ADR-027): numărul de
/// bătăi (2 → 6), ritm egal → cu pauze (lung–scurt), o tobă → două tobe.
/// KPI: **abaterea de timp** (ms) față de ritmul model și lungimea maximă reprodusă.
library;

import 'dart:math';

import 'grades.dart';

class RhythmBeat {
  const RhythmBeat(this.atMs, this.drum);

  /// Momentul bătăii, de la prima (prima = 0).
  final int atMs;

  /// Toba: 0 (joasă) sau 1 (înaltă).
  final int drum;
}

class RhythmAxes {
  const RhythmAxes({required this.beats, required this.uneven, required this.drums, required this.rounds});

  final int beats;

  /// Intervale diferite (lung / scurt), nu doar egale.
  final bool uneven;

  /// 1 sau 2 tobe.
  final int drums;
  final int rounds;

  Map<String, Object> toJson() => {'beats': beats, 'uneven': uneven, 'drums': drums, 'rounds': rounds};
}

class RhythmPattern {
  const RhythmPattern(this.beats);

  final List<RhythmBeat> beats;

  int get durationMs => beats.last.atMs;

  /// Codul ritmului pentru rapoarte: `xx.o` (punct = un pas de pauză în plus), litera tobei.
  String get code => [
        for (final (i, b) in beats.indexed) ...[
          if (i > 0) '.' * max(0, ((b.atMs - beats[i - 1].atMs) / RhythmGame.step).round() - 1),
          b.drum == 0 ? 'x' : 'o',
        ],
      ].join();
}

class RhythmLevel {
  const RhythmLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.patterns,
  });

  final String gameId;
  final int level;
  final int seed;
  final RhythmAxes axes;
  final List<RhythmPattern> patterns;
}

/// Cum a bătut copilul: momentele atingerilor (de la prima) și tobele.
class RhythmPlay {
  const RhythmPlay(this.pattern, this.taps, {this.startMs, this.replays = 0});

  final RhythmPattern pattern;
  final List<RhythmBeat> taps;

  /// Cât a așteptat până la prima bătaie.
  final int? startMs;

  /// De câte ori a cerut să audă din nou modelul.
  final int replays;

  bool get sameCount => taps.length == pattern.beats.length;

  bool get sameDrums =>
      sameCount && [for (var i = 0; i < taps.length; i++) taps[i].drum == pattern.beats[i].drum].every((x) => x);

  /// Abaterea medie a intervalelor față de model (ms); null dacă numărul de bătăi diferă.
  int? get timingErrorMs {
    if (!sameCount || taps.length < 2) return sameCount ? 0 : null;
    var sum = 0;
    for (var i = 1; i < taps.length; i++) {
      final want = pattern.beats[i].atMs - pattern.beats[i - 1].atMs;
      final got = taps[i].atMs - taps[i - 1].atMs;
      sum += (got - want).abs();
    }
    return (sum / (taps.length - 1)).round();
  }

  /// Ritm păstrat: aceleași bătăi, aceleași tobe, fiecare interval la cel mult 40% (min. 220 ms)
  /// de model — copiii mici nu bat la milisecundă; contează forma ritmului.
  bool get correct {
    if (!sameDrums) return false;
    for (var i = 1; i < taps.length; i++) {
      final want = pattern.beats[i].atMs - pattern.beats[i - 1].atMs;
      final got = taps[i].atMs - taps[i - 1].atMs;
      if ((got - want).abs() > max(220, want * 0.4)) return false;
    }
    return true;
  }
}

class RhythmResult {
  RhythmResult(this.level, List<RhythmPlay> plays) : plays = List.unmodifiable(plays);

  final RhythmLevel level;
  final List<RhythmPlay> plays;

  double get accuracy => plays.isEmpty ? 0 : plays.where((p) => p.correct).length / plays.length;

  /// Cea mai lungă secvență reprodusă corect (bătăi).
  int get longest =>
      plays.where((p) => p.correct).fold(0, (m, p) => max(m, p.pattern.beats.length));

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.75) return current + 1;
    if (accuracy < 0.4) return max(1, current - 1);
    return current;
  }
}

class RhythmGame {
  const RhythmGame();

  String get id => 'toba-magica';
  String get name => 'Toba magică';
  String get emoji => '🥁';
  String get description => 'Ascultă ritmul și bate la fel';
  Set<Grade> get grades => Grade.parseCodes('G12');
  List<String> get steps => const ['IMI4'];

  RhythmAxes axesFor(int level) => RhythmAxes(
        beats: min(6, 2 + (level - 1) ~/ 2),
        uneven: level >= 4,
        drums: level >= 7 ? 2 : 1,
        rounds: 4,
      );

  /// Pasul de bază al ritmului (ms) — tempo calm.
  static const step = 600;

  RhythmLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final patterns = <RhythmPattern>[];
    for (var r = 0; r < axes.rounds; r++) {
      final beats = <RhythmBeat>[];
      var at = 0;
      for (var i = 0; i < axes.beats; i++) {
        if (i > 0) {
          // Lung (2 pași) sau scurt (1 pas); cu ritm inegal, măcar o pauză lungă.
          final long = axes.uneven && (random.nextInt(3) == 0 || (i == axes.beats - 1 && !_hasLong(beats, at)));
          at += long ? step * 2 : step;
        }
        final drum = axes.drums == 2 ? random.nextInt(2) : 0;
        beats.add(RhythmBeat(at, drum));
      }
      // Cu două tobe, ambele trebuie să apară.
      if (axes.drums == 2 && beats.map((b) => b.drum).toSet().length < 2) {
        beats[beats.length - 1] = RhythmBeat(beats.last.atMs, 1 - beats.first.drum);
      }
      patterns.add(RhythmPattern(beats));
    }
    return RhythmLevel(gameId: id, level: level, seed: s, axes: axes, patterns: patterns);
  }

  static bool _hasLong(List<RhythmBeat> beats, int now) {
    for (var i = 1; i < beats.length; i++) {
      if (beats[i].atMs - beats[i - 1].atMs > step) return true;
    }
    return false;
  }
}
