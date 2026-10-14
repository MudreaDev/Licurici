/// Puzzle (POT7, catalog #11): o ilustrație pictată, tăiată în piese, se reface trăgând
/// piesele la locul lor. Percepția spațială și relația parte–întreg. Generat din seed
/// (ADR-027): 2 piese (jumătăți) → 4 → 6 → 9; modelul se vede estompat în ramă, apoi nu.
/// KPI: **mutări greșite pe piesă** și timpul pe piesă.
library;

import 'dart:math';

import 'grades.dart';

/// Ilustrațiile folosite (pictate, 4:3): scenele ariilor, cu copilul și Licurici.
const puzzleImages = ['atn', 'pot', 'lrc', 'com', 'emo', 'fex', 'pac', 'imi', 'cog', 'aut', 'mot'];

class PuzzlePiece {
  const PuzzlePiece(this.index, this.col, this.row);

  final int index;
  final int col;
  final int row;
}

class PuzzleRound {
  const PuzzleRound({required this.image, required this.cols, required this.rows, required this.tray});

  /// Codul ilustrației (`domains/<image>`).
  final String image;
  final int cols;
  final int rows;

  /// Ordinea pieselor în tavă (amestecată).
  final List<PuzzlePiece> tray;

  int get pieces => cols * rows;
}

class PuzzleAxes {
  const PuzzleAxes({required this.cols, required this.rows, required this.model, required this.rounds});

  final int cols;
  final int rows;

  /// Modelul se vede estompat în ramă.
  final bool model;
  final int rounds;

  Map<String, Object> toJson() => {'cols': cols, 'rows': rows, 'model': model, 'rounds': rounds};
}

class PuzzleLevel {
  const PuzzleLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final PuzzleAxes axes;
  final List<PuzzleRound> rounds;
}

/// Cum s-a făcut un puzzle: mutări greșite (piesă lăsată în alt loc) și timpul.
class PuzzleSolve {
  const PuzzleSolve(this.round, {required this.wrongMoves, this.ms});

  final PuzzleRound round;
  final int wrongMoves;
  final int? ms;

  /// Mutări greșite pe piesă.
  double get errorsPerPiece => wrongMoves / round.pieces;

  /// „Curat”: cel mult o mutare greșită la fiecare patru piese.
  bool get clean => errorsPerPiece <= 0.25;
}

class PuzzleResult {
  PuzzleResult(this.level, List<PuzzleSolve> solves) : solves = List.unmodifiable(solves);

  final PuzzleLevel level;
  final List<PuzzleSolve> solves;

  double get accuracy => solves.isEmpty ? 0 : solves.where((s) => s.clean).length / solves.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class PuzzleGame {
  const PuzzleGame();

  String get id => 'puzzle';
  String get name => 'Puzzle';
  String get emoji => '🧩';
  String get description => 'Pune piesele la locul lor';
  Set<Grade> get grades => Grade.parseCodes('G123');
  List<String> get steps => const ['POT7'];

  PuzzleAxes axesFor(int level) {
    final (cols, rows) = switch (level) {
      1 => (2, 1),
      2 || 3 => (2, 2),
      4 || 5 => (3, 2),
      6 || 7 => (3, 3),
      8 || 9 => (4, 3),
      _ => (4, 4),
    };
    // Modelul (poza ștearsă din ramă) ajută la fiecare mărime nouă, apoi dispare:
    // 3 × 3 de la 7, 4 × 3 de la 9, 4 × 4 de la 11.
    return PuzzleAxes(cols: cols, rows: rows, model: level <= 6 || level == 8 || level == 10, rounds: 3);
  }

  PuzzleLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final images = ([...puzzleImages]..shuffle(random)).take(axes.rounds).toList();
    final rounds = <PuzzleRound>[];
    for (final image in images) {
      final pieces = [
        for (var r = 0; r < axes.rows; r++)
          for (var c = 0; c < axes.cols; c++) PuzzlePiece(r * axes.cols + c, c, r),
      ];
      List<PuzzlePiece> tray;
      do {
        tray = [...pieces]..shuffle(random);
      } while (tray.length > 1 && [for (var i = 0; i < tray.length; i++) tray[i].index == i].every((x) => x));
      rounds.add(PuzzleRound(image: image, cols: axes.cols, rows: axes.rows, tray: tray));
    }
    return PuzzleLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
