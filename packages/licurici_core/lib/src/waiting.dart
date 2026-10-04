/// Semaforul (FEX1, catalog #35): felinarul e stins; copilul atinge doar când se aprinde
/// verde. Exersează amânarea (a aștepta semnalul) — baza autocontrolului. Nivelurile sunt
/// generate din seed (ADR-027): așteptarea crește (1 → 6 s), devine mai puțin previzibilă,
/// iar de la nivelul 4 apar „tentații” (felinarul licărește galben, scurt).
/// KPI: **atingerile anticipate** (înainte de verde) și timpul de reacție după verde.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

class WaitAxes {
  const WaitAxes({
    required this.trials,
    required this.minWaitMs,
    required this.maxWaitMs,
    required this.flickers,
  });

  final int trials;
  final int minWaitMs;
  final int maxWaitMs;

  /// Câte licăriri (tentații) are fiecare așteptare.
  final int flickers;

  Map<String, Object> toJson() => {
        'trials': trials,
        'minWaitMs': minWaitMs,
        'maxWaitMs': maxWaitMs,
        'flickers': flickers,
      };
}

class WaitTrial {
  const WaitTrial({required this.index, required this.waitMs, required this.flickersAtMs});

  final int index;

  /// După cât timp se aprinde verde (de la începutul încercării).
  final int waitMs;

  /// Când licărește galben (mereu înainte de verde, nu chiar lângă el).
  final List<int> flickersAtMs;
}

class WaitLevel {
  const WaitLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.trials,
  });

  final String gameId;
  final int level;
  final int seed;
  final WaitAxes axes;
  final List<WaitTrial> trials;

  /// Cât stă verde: dacă nu atinge, verdele se stinge și trecem mai departe (fără reproș).
  static const greenMs = 4000;

  /// Cât durează o licărire.
  static const flickerMs = 450;
}

class WaitResponse {
  const WaitResponse(this.trial, {this.anticipations = 0, this.rtMs});

  final WaitTrial trial;

  /// Atingeri înainte de verde.
  final int anticipations;

  /// Timpul de reacție după verde (null = n-a atins cât a stat verde).
  final int? rtMs;

  bool get clean => anticipations == 0 && rtMs != null;
}

class WaitResult {
  WaitResult(this.level, List<WaitResponse> responses) : responses = List.unmodifiable(responses);

  final WaitLevel level;
  final List<WaitResponse> responses;

  int get anticipations => responses.fold(0, (s, r) => s + r.anticipations);

  double get accuracy =>
      responses.isEmpty ? 0 : responses.where((r) => r.clean).length / responses.length;

  /// Cea mai lungă așteptare dusă la capăt fără atingere anticipată (ms).
  int? get longestWaitMs {
    final ok = [for (final r in responses) if (r.anticipations == 0 && r.rtMs != null) r.trial.waitMs];
    return ok.isEmpty ? null : ok.reduce(max);
  }

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.85) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class WaitGame {
  const WaitGame();

  String get id => 'semaforul';
  String get name => 'Semaforul';
  String get emoji => '🚦';
  String get description => 'Atinge doar la verde';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['FEX1'];

  WaitAxes axesFor(int level) => WaitAxes(
        trials: ramp(level, 5, 8, 8).round(),
        minWaitMs: ramp(level, 1000, 2500, 10).round(),
        maxWaitMs: ramp(level, 2000, 6000, 10).round(),
        flickers: level < 4 ? 0 : (level < 7 ? 1 : (level < 10 ? 2 : 3)),
      );

  WaitLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final trials = <WaitTrial>[];
    for (var i = 0; i < axes.trials; i++) {
      final wait = axes.minWaitMs + random.nextInt(axes.maxWaitMs - axes.minWaitMs + 1);
      // Licăririle: în prima parte a așteptării, la cel puțin 700 ms una de alta și de verde.
      final flickers = <int>[];
      for (var f = 0; f < axes.flickers; f++) {
        for (var tries = 0; tries < 20; tries++) {
          final at = 400 + random.nextInt(max(1, wait - 400 - 700 - WaitLevel.flickerMs));
          if (flickers.every((x) => (x - at).abs() >= 700 + WaitLevel.flickerMs)) {
            flickers.add(at);
            break;
          }
        }
      }
      flickers.sort();
      trials.add(WaitTrial(index: i, waitMs: wait, flickersAtMs: flickers));
    }
    return WaitLevel(gameId: id, level: level, seed: s, axes: axes, trials: trials);
  }
}
