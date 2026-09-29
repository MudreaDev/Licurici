import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Încercările și rating-urile pe trepte. Deocamdată în memorie; în Drift urmează tabelele
/// `trials` + `ladder_progress` + outbox-ul pentru sincronizare (plan §7.2).
class TrialLogState {
  const TrialLogState({this.trials = const [], this.ratings = const {}});

  final List<Trial> trials;

  /// Rating-ul Elo al copilului pe fiecare treaptă (plan §3.5 b).
  final Map<String, SkillRating> ratings;

  List<Trial> forStep(String stepId) => [
    for (final t in trials)
      if (t.stepId == stepId) t,
  ];

  SkillRating ratingOf(String stepId) => ratings[stepId] ?? const SkillRating();
}

class TrialLog extends Notifier<TrialLogState> {
  @override
  TrialLogState build() => const TrialLogState();

  /// Adaugă încercarea; dacă nivelul are o dificultate estimată, ajustează rating-ul treptei.
  void add(Trial t, {double? difficulty}) {
    final ratings = {...state.ratings};
    if (difficulty != null) {
      ratings[t.stepId] = state.ratingOf(t.stepId).updateWith(t, difficulty);
    }
    state = TrialLogState(trials: [...state.trials, t], ratings: ratings);
  }
}

final trialLogProvider = NotifierProvider<TrialLog, TrialLogState>(
  TrialLog.new,
);

/// Identificator aleator de sesiune (pseudonim, fără legătură cu copilul): 128 de biți în hex.
String newSessionId([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
