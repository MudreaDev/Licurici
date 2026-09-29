/// Dificultatea ca vector de axe (plan §3.5 a, ADR-027). Fiecare joc își declară axele; un nivel =
/// un punct în spațiul lor. Treapta fixează axele calitative (ex. identic/neidentic) și limitele;
/// generatorul alege continuu restul, aproape de dificultatea țintă dată de rating.
library;

import 'dart:math';

import 'rating.dart';

/// O axă: valori ordonate de la ușor la greu. [weight] = câte puncte de dificultate (scara Elo)
/// adaugă trecerea de la prima la ultima valoare. Dificultatea crește monoton pe fiecare axă.
class AxisSpec {
  const AxisSpec(this.name, this.values, {required this.weight, this.label})
      : assert(weight >= 0);

  final String name;
  final List<num> values;
  final double weight;
  final String? label;

  double cost(num v) {
    final i = values.indexOf(v);
    if (i < 0) throw ArgumentError.value(v, name, 'valoare necunoscută');
    return values.length == 1 ? 0 : weight * i / (values.length - 1);
  }

  /// Valorile permise de limitele unei trepte ([lo], [hi] incluse).
  List<num> within(num? lo, num? hi) => [
        for (final v in values)
          if ((lo == null || v >= lo) && (hi == null || v <= hi)) v,
      ];
}

typedef AxisPoint = Map<String, num>;

class DifficultyAxes {
  const DifficultyAxes(this.axes, {this.base = SkillRating.initial - 300});

  final List<AxisSpec> axes;

  /// Dificultatea celui mai ușor punct (toate axele la minim).
  final double base;

  AxisSpec axis(String name) => axes.firstWhere((a) => a.name == name);

  double difficultyOf(AxisPoint p) =>
      base + axes.fold(0.0, (s, a) => s + a.cost(p[a.name] ?? a.values.first));

  /// Toate punctele permise: [fixed] fixează o axă la o valoare, [limits] o restrânge la un interval.
  List<AxisPoint> grid({AxisPoint fixed = const {}, Map<String, (num?, num?)> limits = const {}}) {
    var points = <AxisPoint>[{}];
    for (final a in axes) {
      final List<num> vals;
      if (fixed[a.name] case final v?) {
        a.cost(v); // validează valoarea
        vals = [v];
      } else if (limits[a.name] case (final lo, final hi)) {
        vals = a.within(lo, hi);
      } else {
        vals = a.values;
      }
      if (vals.isEmpty) throw ArgumentError('axa ${a.name}: nicio valoare în limite');
      points = [
        for (final p in points)
          for (final v in vals) {...p, a.name: v},
      ];
    }
    return points;
  }

  /// Intervalul de dificultate accesibil în limitele date.
  (double, double) range({AxisPoint fixed = const {}, Map<String, (num?, num?)> limits = const {}}) {
    final ds = grid(fixed: fixed, limits: limits).map(difficultyOf);
    return (ds.reduce(min), ds.reduce(max));
  }

  /// Un punct cu dificultatea cât mai aproape de [target]: dintre punctele aflate la cel mult
  /// [tolerance] de țintă alegem aleator (varietate); dacă nu există, cel mai apropiat.
  AxisPoint pointFor(
    double target,
    Random random, {
    AxisPoint fixed = const {},
    Map<String, (num?, num?)> limits = const {},
    double tolerance = 60,
  }) {
    final points = grid(fixed: fixed, limits: limits);
    final near = [
      for (final p in points)
        if ((difficultyOf(p) - target).abs() <= tolerance) p,
    ];
    if (near.isNotEmpty) return near[random.nextInt(near.length)];
    var best = points.first;
    var bestD = double.infinity;
    for (final p in points) {
      final d = (difficultyOf(p) - target).abs();
      if (d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }
}
