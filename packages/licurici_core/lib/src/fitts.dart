/// Atinge rapid (MOT0, legea lui Fitts): bule apar pe rând în locuri diferite; copilul le atinge
/// cât de repede poate. Fiecare atingere are un **indice de dificultate**
/// ID = log₂(D/W + 1) (D = distanța de la bula de dinainte, W = lățimea bulei) și un timp de
/// mișcare (MT). Metrica standard e **throughput** = ID / MT (biți pe secundă): crește odată cu
/// controlul motor fin și nu depinde de cât de mari sau depărtate au fost țintele.
///
/// Coordonatele sunt în înălțimi ale terenului de joc: x ∈ [0, [FittsGame.aspect]], y ∈ [0, 1].
/// Axe: bula se micșorează (0,22 → 0,07 din înălțime) și sare tot mai departe.
library;

import 'dart:math';

import 'grades.dart';

class FittsTarget {
  const FittsTarget(this.x, this.y, this.size);

  final double x, y;

  /// Diametrul bulei (înălțimi).
  final double size;

  /// Distanța (centru la centru) de la [o].
  double distanceTo(FittsTarget o) => sqrt(pow(x - o.x, 2) + pow(y - o.y, 2));
}

class FittsLevel {
  const FittsLevel({required this.gameId, required this.level, required this.seed, required this.targets});

  final String gameId;
  final int level;
  final int seed;

  /// Prima bulă e „startul” (nu se măsoară); urmează țintele.
  final List<FittsTarget> targets;
}

/// O atingere: cât a durat de la bula de dinainte și câte atingeri au fost pe lângă.
class FittsHit {
  const FittsHit(this.index, this.movementMs, {this.misses = 0});

  /// Indexul țintei (≥ 1).
  final int index;
  final int movementMs;
  final int misses;
}

class FittsResult {
  FittsResult(this.level, List<FittsHit> hits) : hits = List.unmodifiable(hits);

  final FittsLevel level;
  final List<FittsHit> hits;

  /// Indicele de dificultate al țintei [index] (biți).
  double idOf(int index) {
    final t = level.targets[index], prev = level.targets[index - 1];
    return log(t.distanceTo(prev) / t.size + 1) / ln2;
  }

  /// Throughput mediu (biți/s): media ID/MT pe atingeri.
  double get throughput {
    final xs = [for (final h in hits) if (h.movementMs > 0) idOf(h.index) / (h.movementMs / 1000)];
    return xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  }

  int get misses => hits.fold(0, (a, h) => a + h.misses);

  /// Partea bulelor atinse din prima (0…1).
  double get accuracy => hits.isEmpty ? 0 : hits.where((h) => h.misses == 0).length / hits.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  /// Mai greu dacă aproape toate au fost atinse din prima; mai ușor la multe ratări.
  int suggestedNextLevel(int current) {
    if (hits.isEmpty) return current;
    final clean = hits.where((h) => h.misses == 0).length / hits.length;
    if (clean >= 0.85) return current + 1;
    if (clean < 0.5) return max(1, current - 1);
    return current;
  }
}

class FittsGame {
  const FittsGame();

  String get id => 'atinge-rapid';
  String get name => 'Atinge rapid';
  String get emoji => '🫧';
  String get description => 'Atinge bulele cât de repede poți';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['MOT0'];

  /// Lățimea terenului față de înălțime (încape pe orice ecran landscape).
  static const aspect = 1.6;

  /// Câte ținte pe nivel (fără start).
  static const count = 10;

  /// Diametrul bulei la [level] (0,22 → 0,07 la nivelul 9).
  double sizeFor(int level) => max(0.07, 0.22 - 0.019 * (level - 1));

  /// Cât de departe sare bula (cel puțin), ca parte din teren (0,15 → 0,55).
  double reachFor(int level) => min(0.55, 0.15 + 0.05 * (level - 1));

  FittsLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final w = sizeFor(level), reach = reachFor(level);
    final targets = <FittsTarget>[];
    var prev = const FittsTarget(aspect / 2, 0.5, 0.2);
    targets.add(FittsTarget(prev.x, prev.y, max(w, 0.16)));
    for (var i = 0; i < count; i++) {
      FittsTarget next;
      var guard = 0;
      do {
        final x = w / 2 + random.nextDouble() * (aspect - w);
        final y = w / 2 + random.nextDouble() * (1 - w);
        next = FittsTarget(x, y, w);
      } while (next.distanceTo(prev) < reach && guard++ < 200);
      targets.add(next);
      prev = next;
    }
    return FittsLevel(gameId: id, level: level, seed: s, targets: targets);
  }
}
