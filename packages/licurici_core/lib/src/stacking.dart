/// Turnul (COG4, fratele lui „Mare și mic”): piramida cu inele, jucăria clasică din terapia
/// ocupațională. Copilul pune inelele pe țăruș **de la cel mai mare la cel mai mic**; un inel pus
/// prea devreme se întoarce în tavă (fără semn de greșeală) și se numără.
///
/// Axe: câte inele (3 → 7), cât de diferite sunt ca mărime (pași mari → mici) și culoarea (la
/// început fiecare inel are culoarea lui, ca un indiciu în plus; de la nivelul 6 sunt toate la fel
/// — rămâne doar mărimea). KPI: alegeri greșite pe turn, timpul pe turn.
library;

import 'dart:math';

import 'grades.dart';

class StackingAxes {
  const StackingAxes({required this.rings, required this.step, required this.sameColor});

  final int rings;

  /// Diferența de lățime dintre două inele vecine (ca parte din cel mai mare).
  final double step;

  /// Toate inelele au aceeași culoare (doar mărimea le deosebește).
  final bool sameColor;

  Map<String, Object> toJson() => {'rings': rings, 'step': step, 'sameColor': sameColor};
}

class StackRing {
  const StackRing(this.rank, this.width, this.color);

  /// 0 = cel mai mare (jos) … rings − 1 = cel mai mic (sus).
  final int rank;

  /// Lățimea (0…1, cel mai mare = 1).
  final double width;

  /// Indexul culorii (paleta e în aplicație).
  final int color;
}

class StackTower {
  const StackTower(this.tray);

  /// Inelele în ordinea din tavă (amestecate).
  final List<StackRing> tray;

  int get size => tray.length;
}

class StackingLevel {
  const StackingLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.towers});

  final String gameId;
  final int level;
  final int seed;
  final StackingAxes axes;
  final List<StackTower> towers;
}

/// Un turn construit: câte alegeri greșite și cât a durat.
class StackBuild {
  const StackBuild(this.tower, {required this.wrong, required this.ms});

  final StackTower tower;
  final int wrong;
  final int ms;

  bool get clean => wrong == 0;
}

class StackingResult {
  StackingResult(this.level, List<StackBuild> builds) : builds = List.unmodifiable(builds);

  final StackingLevel level;
  final List<StackBuild> builds;

  double get accuracy => builds.isEmpty ? 0 : builds.where((b) => b.clean).length / builds.length;

  int get stars => accuracy >= 0.66 ? 3 : (accuracy >= 0.33 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (builds.isEmpty) return current;
    if (accuracy == 1) return current + 1;
    if (builds.every((b) => b.wrong >= 2)) return max(1, current - 1);
    return current;
  }
}

class StackingGame {
  const StackingGame();

  String get id => 'turnul';
  String get name => 'Turnul';
  String get emoji => '🏰';
  String get description => 'Pune inelele de la cel mai mare la cel mai mic';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['COG4'];

  /// Câte turnuri pe nivel.
  static const towers = 3;

  StackingAxes axesFor(int level) => StackingAxes(
        rings: min(7, 2 + level),
        step: max(0.09, 0.2 - 0.02 * (level - 1)),
        sameColor: level >= 6,
      );

  StackingLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final list = <StackTower>[];
    for (var t = 0; t < towers; t++) {
      final base = random.nextInt(6);
      final rings = [
        for (var k = 0; k < axes.rings; k++)
          StackRing(k, 1 - axes.step * k, axes.sameColor ? base : (base + k) % 6),
      ];
      List<StackRing> tray;
      // Tava nu e niciodată deja în ordine (altfel n-ar fi nimic de gândit).
      do {
        tray = [...rings]..shuffle(random);
      } while ([for (var i = 0; i < tray.length; i++) tray[i].rank == i].every((x) => x));
      list.add(StackTower(tray));
    }
    return StackingLevel(gameId: id, level: level, seed: s, axes: axes, towers: list);
  }
}
