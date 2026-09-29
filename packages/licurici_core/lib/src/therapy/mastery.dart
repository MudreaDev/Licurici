/// Stăpânirea unei trepte și KPI-urile de bază (plan §4.2). Dart pur: aceleași reguli rulează
/// pe tabletă (feedback imediat) și pe worker (sursa adevărului).
library;

import 'ladder.dart';
import 'trial.dart';

/// Indicatorii unui set de încercări (o sesiune sau o treaptă).
class TrialStats {
  TrialStats._(this.count, this.accuracy, this.independence, this.meanPrompt, this.medianLatencyMs,
      this.stimulusSets);

  factory TrialStats.of(Iterable<Trial> trials) {
    final list = trials.toList();
    if (list.isEmpty) return TrialStats._(0, 0, 0, 0, null, const {});
    final latencies = [
      for (final t in list)
        if (t.latencyMs != null) t.latencyMs!,
    ]..sort();
    int? median;
    if (latencies.isNotEmpty) {
      final m = latencies.length ~/ 2;
      median = latencies.length.isOdd ? latencies[m] : (latencies[m - 1] + latencies[m]) ~/ 2;
    }
    return TrialStats._(
      list.length,
      list.where((t) => t.correct).length / list.length,
      list.where((t) => t.independent).length / list.length,
      list.fold<int>(0, (s, t) => s + t.promptLevel.index) / list.length,
      median,
      {
        for (final t in list)
          if (t.independent && t.stimulusSet != null) t.stimulusSet!,
      },
    );
  }

  final int count;

  /// Corecte / încercări.
  final double accuracy;

  /// Corecte din prima, fără ajutor / încercări — KPI-ul principal.
  final double independence;

  /// Media nivelului de ajutor (0 = P0 … 4 = P4).
  final double meanPrompt;

  /// Mediana latenței (robustă la pauze lungi); `null` fără date.
  final int? medianLatencyMs;

  /// Seturile de stimuli la care copilul a răspuns independent (generalizare).
  final Set<String> stimulusSets;
}

enum MasteryState {
  /// Prea puține date pentru o concluzie (nu afișăm procente false).
  insufficientData,

  /// În lucru.
  inProgress,

  /// Criteriul atins.
  mastered,
}

class MasteryResult {
  const MasteryResult(this.state, {this.sessionsMet = 0, this.stimulusSets = 0, this.sessions = const []});

  final MasteryState state;

  /// Câte sesiuni consecutive (cele mai recente) ating pragul.
  final int sessionsMet;

  /// Seturi de stimuli distincte în sesiunile care au atins pragul.
  final int stimulusSets;

  /// Indicatorii fiecărei sesiuni valide, în ordine cronologică (pentru graficul ABA).
  final List<TrialStats> sessions;

  bool get mastered => state == MasteryState.mastered;
}

/// Aplică [MasteryCriterion] pe încercările unei trepte, grupate pe sesiuni.
class MasteryEvaluator {
  const MasteryEvaluator();

  MasteryResult evaluate(Iterable<Trial> trials, MasteryCriterion c) {
    // grupăm pe sesiuni, în ordinea primei încercări (sesiunile sub minTrials nu contează)
    final bySession = <String, List<Trial>>{};
    final sorted = trials.toList()..sort((a, b) => a.at.compareTo(b.at));
    for (final t in sorted) {
      if (t.mode == TrialMode.evaluare) continue; // sondajele de plasare nu intră în criteriu
      bySession.putIfAbsent(t.sessionId, () => []).add(t);
    }
    final sessions = [
      for (final s in bySession.values)
        if (s.length >= c.minTrials) TrialStats.of(s),
    ];
    if (sessions.isEmpty) return const MasteryResult(MasteryState.insufficientData);

    var met = 0;
    final sets = <String>{};
    for (final s in sessions.reversed) {
      if (s.independence < c.independence) break;
      met++;
      sets.addAll(s.stimulusSets);
    }
    final mastered = met >= c.sessions && sets.length >= c.stimulusSets;
    return MasteryResult(
      mastered ? MasteryState.mastered : MasteryState.inProgress,
      sessionsMet: met,
      stimulusSets: sets.length,
      sessions: sessions,
    );
  }
}
