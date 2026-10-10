/// Încercarea măsurată (plan §4.1), ierarhia de ajutor (§3.3), criteriul de stăpânire (§3)
/// și rating-ul adaptiv Elo (§3.5 b). Totul Dart pur: aplicația produce încercări, iar
/// KPI-urile se calculează la fel pe dispozitiv și în worker.
library;

import 'dart:math';

/// Nivelul de ajutor primit într-o încercare (plan §3.3). Ordinea contează: P0 < P4.
enum PromptLevel {
  /// Independent, fără ajutor.
  p0,

  /// Indiciu vocal neutru.
  p1,

  /// Distractorii se estompează (variante reduse).
  p2,

  /// Răspunsul corect pulsează (indicare).
  p3,

  /// Model complet: mânuța animată arată răspunsul.
  p4;

  String get code => 'P$index';

  /// Cât „valorează” o reușită cu acest ajutor pentru rating (o reușită cu ajutor contează puțin).
  double get credit => const [1.0, 0.6, 0.35, 0.15, 0.0][index];

  PromptLevel get next => this == p4 ? p4 : PromptLevel.values[index + 1];
  PromptLevel get previous => this == p0 ? p0 : PromptLevel.values[index - 1];
}

/// Cum crește ajutorul în timpul unei runde (plan §3.3):
/// - [mostToLeast]: treaptă nouă — ajutor de la început, apoi întârziere progresivă (time delay);
/// - [leastToMost]: treaptă cunoscută — ajutorul vine doar după greșeli sau pauză lungă.
enum PromptStrategy { mostToLeast, leastToMost }

/// Decide ajutorul pentru runda curentă. Starea e mică și explicită, ca motorul UI să o
/// poată întreba după fiecare greșeală sau la fiecare tic de inactivitate.
class PromptLadder {
  const PromptLadder({
    this.strategy = PromptStrategy.leastToMost,
    this.maxLevel = PromptLevel.p4,
    this.idleStepMs = 5000,
  });

  final PromptStrategy strategy;

  /// Specialistul poate plafona ajutorul (ex. „fără P4, se enervează la mânuță”).
  final PromptLevel maxLevel;

  /// După câtă inactivitate urcă ajutorul o treaptă (least-to-most), ms.
  final int idleStepMs;

  /// Ajutorul de start: la most-to-least, nivelul scade pe măsură ce copilul reușește
  /// independent ([independentStreak] = runde reușite la rând fără ajutor pe treaptă).
  PromptLevel initial({int independentStreak = 0}) {
    if (strategy == PromptStrategy.leastToMost) return PromptLevel.p0;
    final start = max(0, PromptLevel.p3.index - independentStreak);
    return _cap(PromptLevel.values[start]);
  }

  /// Întârzierea înainte de primul ajutor (time delay progresiv: 0 s → 2 s → 4 s).
  int delayMs({int independentStreak = 0}) =>
      strategy == PromptStrategy.leastToMost ? idleStepMs : min(4000, 2000 * independentStreak);

  /// Ajutorul după [wrongAttempts] greșeli și [idleMs] de inactivitate în runda curentă.
  PromptLevel current({required PromptLevel start, int wrongAttempts = 0, int idleMs = 0}) {
    final bumps = wrongAttempts + idleMs ~/ idleStepMs;
    return _cap(PromptLevel.values[min(PromptLevel.p4.index, start.index + bumps)]);
  }

  PromptLevel _cap(PromptLevel p) => p.index > maxLevel.index ? maxLevel : p;
}

/// O încercare (o rundă jucată). Fără date personale: doar id-uri pseudonime și măsurători.
class Trial {
  const Trial({
    required this.stepId,
    required this.gameId,
    required this.correct,
    required this.promptLevel,
    required this.at,
    this.attempts = 1,
    this.latencyMs,
    this.stimulusId,
    this.stimulusSet,
    this.seed,
    this.difficulty,
    this.level,
    this.offTargetTaps = 0,
    this.targetId,
    this.chosenId,
  });

  /// Răspunsul corect (ex. `trist`) și ce a ales copilul prima dată când a greșit (ex. `suparat`).
  /// Din perechi se construiește matricea de confuzii („confundă trist cu supărat”).
  final String? targetId;
  final String? chosenId;

  final String stepId;
  final String gameId;
  final bool correct;

  /// Ajutorul MAXIM primit în încercare.
  final PromptLevel promptLevel;
  final DateTime at;
  final int attempts;
  final int? latencyMs;
  final String? stimulusId;

  /// Setul de stimuli (pentru generalizare: aceeași abilitate pe materiale diferite).
  final String? stimulusSet;
  final int? seed;

  /// Mărimea itemului pe axa principală a jocului (mutări, obiecte, secunde de așteptare…), pentru
  /// KPI de tipul „acuratețea față de mărime”. Fiecare joc are scara lui — NU e pe scara rating-ului.
  final double? difficulty;

  /// Nivelul jocului (1…∞) la care s-a jucat încercarea; pentru rating (Elo) devine dificultatea
  /// itemului prin [EloRating.difficultyOfLevel]. null = nivel necunoscut (sesiuni mai vechi).
  final int? level;

  /// Dificultatea itemului pe scara rating-ului.
  double get ratingDifficulty => level == null ? EloRating.start : EloRating.difficultyOfLevel(level!);
  final int offTargetTaps;

  /// Corect, din prima, fără ajutor.
  bool get independent => correct && attempts == 1 && promptLevel == PromptLevel.p0;

  factory Trial.fromJson(Map<String, Object?> j) => Trial(
        stepId: j['stepId']! as String,
        gameId: j['gameId']! as String,
        correct: j['correct']! as bool,
        promptLevel: PromptLevel.values.firstWhere((p) => p.code == j['promptLevel']),
        attempts: (j['attempts'] as int?) ?? 1,
        latencyMs: j['latencyMs'] as int?,
        stimulusId: j['stimulusId'] as String?,
        stimulusSet: j['stimulusSet'] as String?,
        seed: j['seed'] as int?,
        difficulty: (j['difficulty'] as num?)?.toDouble(),
        level: (j['level'] as num?)?.toInt(),
        offTargetTaps: (j['offTargetTaps'] as int?) ?? 0,
        targetId: j['targetId'] as String?,
        chosenId: j['chosenId'] as String?,
        at: DateTime.parse(j['at']! as String),
      );

  Map<String, Object?> toJson() => {
        'stepId': stepId,
        'gameId': gameId,
        'correct': correct,
        'promptLevel': promptLevel.code,
        'attempts': attempts,
        'latencyMs': latencyMs,
        'stimulusId': stimulusId,
        'stimulusSet': stimulusSet,
        'seed': seed,
        'difficulty': difficulty,
        if (level != null) 'level': level,
        'offTargetTaps': offTargetTaps,
        'targetId': targetId,
        'chosenId': chosenId,
        'at': at.toUtc().toIso8601String(),
      };
}

/// KPI-urile de bază pe o listă de încercări (plan §4.2).
class TrialStats {
  TrialStats(List<Trial> trials) : trials = List.unmodifiable(trials);

  final List<Trial> trials;

  int get count => trials.length;

  double get accuracy => count == 0 ? 0 : trials.where((t) => t.correct).length / count;

  /// Cel mai important KPI: corect, din prima, fără ajutor.
  double get independence => count == 0 ? 0 : trials.where((t) => t.independent).length / count;

  double get meanPromptLevel =>
      count == 0 ? 0 : trials.fold(0, (s, t) => s + t.promptLevel.index) / count;

  int? get medianLatencyMs {
    final xs = [for (final t in trials) ?t.latencyMs]..sort();
    if (xs.isEmpty) return null;
    final m = xs.length ~/ 2;
    return xs.length.isOdd ? xs[m] : ((xs[m - 1] + xs[m]) / 2).round();
  }

  /// Seturi de stimuli distincte reușite independent (generalizare).
  Set<String> get generalizedSets => {
        for (final t in trials)
          if (t.independent && t.stimulusSet != null) t.stimulusSet!,
      };
}

/// Criteriul de stăpânire (plan §3, implicit: ≥ 80% independent, 2 sesiuni la rând,
/// ≥ 2 seturi de stimuli, minim 10 încercări pe sesiune). Specialistul îl poate modifica.
class MasteryCriterion {
  const MasteryCriterion({
    this.independence = 0.8,
    this.consecutiveSessions = 2,
    this.minTrialsPerSession = 10,
    this.minStimulusSets = 2,
  });

  final double independence;
  final int consecutiveSessions;
  final int minTrialsPerSession;
  final int minStimulusSets;

  /// [sessions] = încercările pe treaptă, grupate pe sesiuni, în ordine cronologică.
  MasteryResult evaluate(List<List<Trial>> sessions) {
    final eligible = sessions.where((s) => s.length >= minTrialsPerSession).toList();
    var streak = 0;
    for (final s in eligible.reversed) {
      if (TrialStats(s).independence >= independence) {
        streak++;
      } else {
        break;
      }
    }
    final recent = eligible.reversed.take(max(streak, 1)).expand((s) => s).toList();
    final sets = TrialStats(recent).generalizedSets.length;
    final mastered = streak >= consecutiveSessions && sets >= minStimulusSets;
    return MasteryResult(
      mastered: mastered,
      sessionStreak: streak,
      stimulusSets: sets,
      lastIndependence: eligible.isEmpty ? null : TrialStats(eligible.last).independence,
    );
  }
}

class MasteryResult {
  const MasteryResult({
    required this.mastered,
    required this.sessionStreak,
    required this.stimulusSets,
    this.lastIndependence,
  });

  final bool mastered;
  final int sessionStreak;
  final int stimulusSets;
  final double? lastIndependence;
}

/// Rating-ul copilului pe o treaptă (Elo, ca în Math Garden). Itemii au și ei o dificultate pe
/// aceeași scară; generatorul caută itemi cu ~[targetSuccess] șanse de reușită.
class EloRating {
  const EloRating({this.k = 32, this.scale = 400, this.targetSuccess = 0.8});

  final double k;
  final double scale;

  /// Probabilitatea dorită de reușită (0.8 implicit; specialistul poate cere 0.9).
  final double targetSuccess;

  static const double start = 1000;

  /// Probabilitatea ca un copil cu [rating] să reușească un item de [difficulty].
  double expected(double rating, double difficulty) =>
      1 / (1 + pow(10, (difficulty - rating) / scale));

  /// Rating-ul după o încercare. Reușita cu ajutor contează doar parțial ([PromptLevel.credit]).
  double update(double rating, double difficulty, {required bool correct, PromptLevel prompt = PromptLevel.p0}) {
    final score = correct ? prompt.credit : 0.0;
    return rating + k * (score - expected(rating, difficulty));
  }

  /// Dificultatea itemului la care copilul are exact [targetSuccess] șanse.
  double targetDifficulty(double rating) =>
      rating - scale * log(targetSuccess / (1 - targetSuccess)) / ln10;

  /// Jocurile cu niveluri numerotate (1…∞): nivelul n are dificultatea `start + (n−1)·perLevel`.
  static const double perLevel = 40;

  static double difficultyOfLevel(int level) => start + (level - 1) * perLevel;

  /// Nivelul potrivit pentru [rating] (cel mai greu nivel cu ≥ [targetSuccess] șanse).
  int levelFor(double rating) =>
      max(1, 1 + ((targetDifficulty(rating) - start) / perLevel).floor());
}
