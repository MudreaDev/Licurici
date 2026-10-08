/// Rândul meu, rândul tău (EMO7): copilul și Licurici construiesc împreună un turn, pe rând —
/// un cub copilul, un cub Licurici. Exersează **așteptarea rândului** și, mai târziu,
/// **predarea rândului** („Rândul tău, Licurici!”), baza jocului cu altcineva.
///
/// Nivelurile sunt generate din seed (ADR-027). Axe: cât durează rândul lui Licurici
/// (1,5 → 6 s), cât de înalt e turnul, cine începe, dacă trebuie dat rândul cu butonul și
/// „ezitările” lui Licurici (se gândește, apoi pune — momentul cel mai greu de așteptat).
/// O încercare = un ciclu (rândul lui Licurici + rândul copilului). Corectă = n-a atins nimic
/// cât a fost rândul lui Licurici și, când trebuia, a dat singur rândul.
/// KPI: **atingerile în rândul celuilalt**, timpul până își face mutarea, predarea rândului
/// fără ajutor.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

class TurnAxes {
  const TurnAxes({
    required this.towers,
    required this.blocks,
    required this.waitMs,
    required this.childFirst,
    required this.passTurn,
    required this.hesitate,
  });

  /// Câte turnuri are nivelul.
  final int towers;

  /// Câte cuburi are un turn (jumătate copilul, jumătate Licurici).
  final int blocks;

  /// Cât durează rândul lui Licurici.
  final int waitMs;

  /// Începe copilul (mai ușor: întâi face, apoi așteaptă).
  final bool childFirst;

  /// Copilul dă rândul cu butonul „Rândul tău, Licurici!”.
  final bool passTurn;

  /// Licurici ezită: ia cubul, se gândește, abia apoi îl pune.
  final bool hesitate;

  Map<String, Object> toJson() => {
    'towers': towers,
    'blocks': blocks,
    'waitMs': waitMs,
    'childFirst': childFirst,
    'passTurn': passTurn,
    'hesitate': hesitate,
  };
}

class TurnLevel {
  const TurnLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.colors});

  final String gameId;
  final int level;
  final int seed;
  final TurnAxes axes;

  /// Culorile cuburilor copilului (calde) și ale lui Licurici (reci), pe rând, pentru fiecare
  /// turn: `colors[turn][cub]`.
  final List<List<int>> colors;

  /// Cât așteptăm să dea rândul singur, apoi Licurici întreabă („E rândul meu?”).
  static const passPromptMs = 6000;
}

/// Un ciclu: rândul lui Licurici + rândul copilului.
class TurnCycle {
  const TurnCycle({required this.earlyTaps, this.placeMs, this.passed = true, this.passPrompted = false});

  /// Atingeri cât a fost rândul lui Licurici.
  final int earlyTaps;

  /// Cât i-a luat să-și pună cubul, din momentul în care a fost rândul lui.
  final int? placeMs;

  /// A dat rândul (când nivelul o cere).
  final bool passed;

  /// L-a dat abia după ce a întrebat Licurici.
  final bool passPrompted;

  bool get clean => earlyTaps == 0 && passed && !passPrompted;
}

class TurnResult {
  TurnResult(this.level, List<TurnCycle> cycles) : cycles = List.unmodifiable(cycles);

  final TurnLevel level;
  final List<TurnCycle> cycles;

  double get accuracy => cycles.isEmpty ? 0 : cycles.where((c) => c.clean).length / cycles.length;
  int get earlyTaps => cycles.fold(0, (a, c) => a + c.earlyTaps);
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.85) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

const childBlockColors = [0xFFF2994A, 0xFFF2C94C, 0xFFEB5757, 0xFFF29BB8];
const licuriciBlockColors = [0xFF56CCF2, 0xFF6FCF97, 0xFF9B8CF2, 0xFF2D9CDB];

class TurnGame {
  const TurnGame();

  String get id => 'pe-rand';
  String get name => 'Rândul meu, rândul tău';
  String get emoji => '🧱';
  String get description => 'Construim turnul pe rând';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['EMO7'];

  TurnAxes axesFor(int level) => TurnAxes(
    towers: level <= 2 ? 1 : 2,
    blocks: ramp(level, 4, 10, 10).round() ~/ 2 * 2,
    waitMs: ramp(level, 1500, 6000, 12).round(),
    childFirst: level <= 3,
    passTurn: level >= 5,
    hesitate: level >= 7,
  );

  TurnLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final childFirst = axes.childFirst;
    return TurnLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      colors: [
        for (var t = 0; t < axes.towers; t++)
          [
            for (var b = 0; b < axes.blocks; b++)
              (b.isEven == childFirst)
                  ? childBlockColors[random.nextInt(childBlockColors.length)]
                  : licuriciBlockColors[random.nextInt(licuriciBlockColors.length)],
          ],
      ],
    );
  }

  /// Al cui e cubul [block] (al copilului sau al lui Licurici).
  bool childPlaces(TurnLevel level, int block) => block.isEven == level.axes.childFirst;
}
