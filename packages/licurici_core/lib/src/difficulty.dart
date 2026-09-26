/// Motorul CENTRAL de dificultate. Un singur `tier` numeric conduce toată scalarea:
///  - în Aventură: dat de nivel și NEMĂRGINIT (crește la fiecare 4 niveluri);
///  - în joc liber: pornește de la clasă + setarea ușor/mediu.
///
/// Port 1:1 din `legacy/electron/src/difficulty.js` (valorile sunt verificate în teste).
library;

import 'grades.dart';

enum FreePlayLevel { usor, mediu }

class Difficulty {
  const Difficulty(this.tier) : assert(tier >= 1);

  /// Joc liber: tier din clasă (+1 pentru „mediu”).
  factory Difficulty.freePlay(Grade grade, [FreePlayLevel level = FreePlayLevel.usor]) =>
      Difficulty(grade.baseTier + (level == FreePlayLevel.mediu ? 1 : 0));

  /// Aventură: nivelul 1–4 → tier 1, 5–8 → tier 2 … (nemărginit).
  factory Difficulty.adventure(int levelIndex) {
    if (levelIndex < 1) throw ArgumentError.value(levelIndex, 'levelIndex', 'începe de la 1');
    return Difficulty(1 + (levelIndex - 1) ~/ 4);
  }

  final int tier;

  /// Câte variante de răspuns se arată: 2 → maxim 5.
  /// t1:2 t2:3 t3:3 t4:4 t5:4 t6+:5
  int get optionCount => (2 + tier ~/ 2).clamp(2, 5);

  /// Câte variante greșite generează un joc.
  int get distractors => optionCount - 1;

  /// Câte runde are o lecție: 5 → 8.
  int get roundCount => (5 + (tier - 1) ~/ 2).clamp(4, 8);

  /// Plafon numeric pentru matematică (crește cu tier-ul, limitat la [cap]).
  int numMax({int cap = 100, int growth = 8, int start = 5}) {
    final v = start + tier * growth;
    return v < cap ? v : cap;
  }

  Difficulty easier() => Difficulty(tier > 1 ? tier - 1 : 1);
  Difficulty harder() => Difficulty(tier + 1);

  @override
  bool operator ==(Object other) => other is Difficulty && other.tier == tier;

  @override
  int get hashCode => tier.hashCode;

  @override
  String toString() => 'Difficulty(tier: $tier)';
}
