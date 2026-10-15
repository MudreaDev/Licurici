/// Construiește la fel (IMI5, catalog #8): un model din forme colorate, copilul îl reface în
/// grila goală, alegând piesele din paletă. Copiere vizuo-constructivă (tip „block design”).
/// Generat din seed (ADR-027): 2 → 9 piese, distractori în paletă (aceeași formă în altă
/// culoare), iar de la nivelul 6 modelul dispare după câteva secunde (din memorie).
/// KPI: piese puse corect din prima, mutări greșite.
library;

import 'dart:math';

import 'grades.dart';
import 'switching.dart' show cardColors, cardShapes, SwitchCard;

class BuildRound {
  const BuildRound({required this.cols, required this.rows, required this.model, required this.palette});

  final int cols;
  final int rows;

  /// Piesa din fiecare celulă a modelului.
  final List<SwitchCard> model;

  /// Piesele din care alege copilul (cele necesare, o dată fiecare tip, + distractori).
  final List<SwitchCard> palette;
}

class BuildAxes {
  const BuildAxes({required this.cols, required this.rows, required this.distractors, this.hideModelMs});

  final int cols;
  final int rows;
  final int distractors;

  /// Modelul se ascunde după atâtea ms (null = rămâne la vedere).
  final int? hideModelMs;

  Map<String, Object?> toJson() =>
      {'cols': cols, 'rows': rows, 'distractors': distractors, 'hideModelMs': hideModelMs};
}

class BuildLevel {
  const BuildLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final BuildAxes axes;
  final List<BuildRound> rounds;
}

class BuildSolve {
  const BuildSolve(this.round, {required this.wrongMoves, this.ms, this.peeked = false});

  final BuildRound round;
  final int wrongMoves;
  final int? ms;

  /// A cerut să vadă din nou modelul ascuns (ajutor).
  final bool peeked;

  bool get clean => wrongMoves <= round.model.length ~/ 4;
}

class BuildResult {
  BuildResult(this.level, List<BuildSolve> solves) : solves = List.unmodifiable(solves);

  final BuildLevel level;
  final List<BuildSolve> solves;

  double get accuracy => solves.isEmpty ? 0 : solves.where((s) => s.clean).length / solves.length;
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class BuildGame {
  const BuildGame();

  String get id => 'construieste';
  String get name => 'Construiește la fel';
  String get emoji => '🟦';
  String get description => 'Fă la fel ca modelul';
  Set<Grade> get grades => Grade.parseCodes('G123');
  List<String> get steps => const ['IMI5'];

  BuildAxes axesFor(int level) {
    final (cols, rows) = switch (level) {
      1 => (2, 1),
      2 || 3 => (2, 2),
      4 || 5 || 6 => (3, 2),
      _ => (3, 3),
    };
    return BuildAxes(
      cols: cols,
      rows: rows,
      distractors: level <= 2 ? 0 : (level <= 5 ? 1 : 2),
      hideModelMs: level >= 6 ? 5000 : null,
    );
  }

  BuildLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final rounds = <BuildRound>[];
    for (var r = 0; r < 3; r++) {
      final n = axes.cols * axes.rows;
      // Câteva tipuri de piese (2 → 4), repetate în model.
      final kinds = min(4, 2 + level ~/ 3);
      final colors = ([...cardColors]..shuffle(random)).take(kinds).toList();
      final shapes = ([...cardShapes]..shuffle(random)).take(kinds).toList();
      final types = <SwitchCard>[
        for (var i = 0; i < kinds; i++) SwitchCard(colors[i], shapes[i]),
      ];
      List<SwitchCard> model;
      do {
        model = [for (var i = 0; i < n; i++) types[random.nextInt(types.length)]];
      } while (model.toSet().length < min(2, n));
      // Distractori: aceeași formă, altă culoare (seamănă, dar nu e la fel).
      final used = model.toSet();
      final distractors = <SwitchCard>[];
      for (final t in used) {
        if (distractors.length >= axes.distractors) break;
        final other = cardColors.where((c) => c != t.color).toList();
        final d = SwitchCard(other[random.nextInt(other.length)], t.shape);
        if (!used.contains(d) && !distractors.contains(d)) distractors.add(d);
      }
      final palette = [...used, ...distractors]..shuffle(random);
      rounds.add(BuildRound(cols: axes.cols, rows: axes.rows, model: model, palette: palette));
    }
    return BuildLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}

