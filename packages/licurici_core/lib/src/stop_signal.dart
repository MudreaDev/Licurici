/// Stop! (FEX2c, sarcina semnalului de oprire — Logan & Cowan): felinarul se aprinde **verde**
/// și copilul îl atinge repede; uneori, la scurt timp după, se face **roșu** — atunci nu-l mai
/// atinge. Întârzierea semnalului (SSD) se adaptează „în scară”: oprire reușită → semnalul vine
/// mai târziu (mai greu), oprire ratată → mai devreme. Așa copilul reușește să se oprească cam
/// la jumătate din încercări, iar **SSRT** (timpul de reacție la semnalul de oprire) se
/// estimează ca timpul median de reacție la „verde” minus întârzierea medie. Un SSRT mai mic =
/// o frână mai bună (inhibiție).
///
/// Axe: câte încercări (16 → 32), cât de des apare oprirea (20% → 30%), cât stă felinarul
/// aprins (cât de repede trebuie răspuns: 1,6 s → 0,9 s).
library;

import 'dart:math';

import 'grades.dart';

class StopAxes {
  const StopAxes({required this.count, required this.stopRatio, required this.windowMs, required this.startSsdMs});

  final int count;
  final double stopRatio;

  /// Cât stă felinarul aprins (fereastra de răspuns).
  final int windowMs;

  /// Întârzierea de la care pornește scara.
  final int startSsdMs;

  Map<String, Object> toJson() => {'count': count, 'stopRatio': stopRatio, 'windowMs': windowMs, 'startSsdMs': startSsdMs};
}

class StopLevel {
  const StopLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.stops, required this.gapsMs});

  final String gameId;
  final int level;
  final int seed;
  final StopAxes axes;

  /// Pentru fiecare încercare: are semnal de oprire?
  final List<bool> stops;

  /// Pauza dinaintea fiecărei încercări (ms), puțin variată (momentul nu e previzibil).
  final List<int> gapsMs;
}

/// Scara întârzierii: ±50 ms, între 50 ms și fereastra de răspuns − 100 ms.
class StopStaircase {
  StopStaircase(this.axes) : ssdMs = axes.startSsdMs;

  final StopAxes axes;
  int ssdMs;

  static const step = 50;

  /// Rezultatul unei încercări cu oprire: [stopped] = n-a atins.
  void update({required bool stopped}) {
    ssdMs = (ssdMs + (stopped ? step : -step)).clamp(50, axes.windowMs - 100);
  }
}

/// O încercare jucată.
class StopTrial {
  const StopTrial({required this.stop, required this.tapped, this.rtMs, this.ssdMs});

  final bool stop;
  final bool tapped;

  /// Timpul de reacție (dacă a atins).
  final int? rtMs;

  /// Întârzierea semnalului (doar la încercările cu oprire).
  final int? ssdMs;

  /// Corect: a atins la verde, nu a atins la roșu.
  bool get correct => stop ? !tapped : tapped;
}

class StopResult {
  StopResult(this.level, List<StopTrial> trials) : trials = List.unmodifiable(trials);

  final StopLevel level;
  final List<StopTrial> trials;

  Iterable<StopTrial> get _go => trials.where((t) => !t.stop);
  Iterable<StopTrial> get _stop => trials.where((t) => t.stop);

  /// Cât de des s-a oprit la roșu (0…1).
  double get stopRate => _stop.isEmpty ? 0 : _stop.where((t) => !t.tapped).length / _stop.length;

  /// Timpul median de reacție la verde (ms), sau null.
  int? get goRtMedian {
    final xs = [for (final t in _go) if (t.tapped) ?t.rtMs]..sort();
    return xs.isEmpty ? null : xs[xs.length ~/ 2];
  }

  /// Întârzierea medie a semnalului (ms), sau null.
  double? get meanSsd {
    final xs = [for (final t in _stop) ?t.ssdMs];
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  /// SSRT estimat (ms): RT median la verde − SSD medie (metoda mediei, valabilă când rata de
  /// oprire e aproape de 50%); null dacă nu sunt destule date.
  double? get ssrt {
    final rt = goRtMedian, ssd = meanSsd;
    if (rt == null || ssd == null) return null;
    return max(0, rt - ssd).toDouble();
  }

  double get accuracy => trials.isEmpty ? 0 : trials.where((t) => t.correct).length / trials.length;

  int get stars => accuracy >= 0.75 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  /// Mai greu când la verde răspunde aproape mereu (scara are grijă de opriri).
  int suggestedNextLevel(int current) {
    final go = _go.toList();
    if (go.isEmpty) return current;
    final hit = go.where((t) => t.tapped).length / go.length;
    if (hit >= 0.9) return current + 1;
    if (hit < 0.6) return max(1, current - 1);
    return current;
  }
}

class StopSignalGame {
  const StopSignalGame();

  String get id => 'stop';
  String get name => 'Stop!';
  String get emoji => '🚦';
  String get description => 'Atinge la verde, oprește-te la roșu';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['FEX2c'];

  StopAxes axesFor(int level) => StopAxes(
        count: min(32, 14 + 2 * level),
        stopRatio: min(0.3, 0.2 + 0.0125 * (level - 1)),
        windowMs: max(900, 1600 - 90 * (level - 1)),
        startSsdMs: 250,
      );

  StopLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final nStop = max(1, (axes.count * axes.stopRatio).round());
    // Primele trei sunt mereu „verde” (copilul prinde ritmul); niciodată două opriri la rând:
    // alegem locurile dintre „verzi” (m − k + 1 locuri pentru k opriri, apoi le depărtăm).
    final m = axes.count - 3;
    final slots = ([for (var i = 0; i < m - nStop + 1; i++) i]..shuffle(random)).take(nStop).toList()..sort();
    final at = {for (final (i, p) in slots.indexed) p + i};
    final stops = [false, false, false, for (var i = 0; i < m; i++) at.contains(i)];
    final gaps = [for (var i = 0; i < axes.count; i++) 900 + random.nextInt(700)];
    return StopLevel(gameId: id, level: level, seed: s, axes: axes, stops: stops, gapsMs: gaps);
  }

}
