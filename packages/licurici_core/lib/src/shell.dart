/// Cucu-bau (COG2, catalog #25): un obiect se ascunde sub un pahar, paharele se mută, copilul
/// arată unde e. Permanența obiectului și urmărirea vizuală. Niveluri din seed (ADR-027);
/// KPI: acuratețea în funcție de numărul de mutări.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

/// Obiectul ascuns: imaginea și numele rostit („Unde este mingea acum?”).
class HiddenThing {
  const HiddenThing(this.emoji, this.name);
  final String emoji;
  final String name;

  String get question => 'Unde este $name acum?';
}

const hiddenThings = [
  HiddenThing('⚽', 'mingea'),
  HiddenThing('🧸', 'ursulețul'),
  HiddenThing('📖', 'cartea'),
  HiddenThing('🚗', 'mașinuța'),
];

class ShellAxes {
  const ShellAxes({required this.cups, required this.swaps, required this.swapMs});

  /// Câte pahare (2 → 4).
  final int cups;

  /// Câte mutări (0 → 8). La 0, copilul doar își amintește unde a văzut obiectul.
  final int swaps;

  /// Durata unei mutări (lent → mai repede, dar mereu ușor de urmărit).
  final int swapMs;

  Map<String, Object> toJson() => {'cups': cups, 'swaps': swaps, 'swapMs': swapMs};
}

/// O rundă: sub ce loc se ascunde obiectul și ce locuri își schimbă paharele, pe rând.
class ShellRound {
  const ShellRound({required this.thing, required this.start, required this.swaps});

  final HiddenThing thing;

  /// Locul (0..cups-1) unde e obiectul la început.
  final int start;

  /// Perechi de locuri care își schimbă paharele.
  final List<(int, int)> swaps;

  /// Locul final al paharului cu obiectul.
  int get answer {
    var at = start;
    for (final (a, b) in swaps) {
      if (at == a) {
        at = b;
      } else if (at == b) {
        at = a;
      }
    }
    return at;
  }
}

class ShellLevel {
  const ShellLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final ShellAxes axes;
  final List<ShellRound> rounds;

  Set<String> get art => rounds.map((r) => r.thing.emoji).toSet();
}

/// Ce a ales copilul într-o rundă.
class ShellPick {
  const ShellPick(this.round, this.slot, {this.ms});

  final int round;
  final int slot;
  final int? ms;
}

class ShellResult {
  ShellResult(this.level, List<ShellPick> picks) : picks = List.unmodifiable(picks);

  final ShellLevel level;
  final List<ShellPick> picks;

  bool isCorrect(ShellPick p) => level.rounds[p.round].answer == p.slot;

  double get accuracy =>
      picks.isEmpty ? 0 : picks.where(isCorrect).length / picks.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  /// 80%+ → +1; sub 50% → −1; altfel rămâne.
  int suggestedNextLevel(int current) {
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class ShellGame {
  const ShellGame();

  String get id => 'cucu-bau';
  String get name => 'Cucu-bau';
  String get emoji => '🥤';
  String get description => 'Unde s-a ascuns?';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['COG2'];

  static const roundsPerLevel = 5;

  ShellAxes axesFor(int level) => ShellAxes(
        cups: level < 4 ? 2 : (level < 9 ? 3 : 4),
        swaps: ramp(level, 0, 8, 14).round(),
        swapMs: ramp(level, 900, 450, 14).round(),
      );

  ShellLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    return ShellLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      rounds: [
        for (var r = 0; r < roundsPerLevel; r++)
          ShellRound(
            thing: hiddenThings[random.nextInt(hiddenThings.length)],
            start: random.nextInt(axes.cups),
            swaps: [
              for (var k = 0; k < axes.swaps; k++)
                () {
                  final a = random.nextInt(axes.cups);
                  final b = (a + 1 + random.nextInt(axes.cups - 1)) % axes.cups;
                  return (a, b);
                }(),
            ],
          ),
      ],
    );
  }
}
