/// Nivelul copilului pe o treaptă = un rating Elo (plan §3.5 b, ADR-027), ca în Math Garden
/// (Klinkenberg et al., 2011). Fiecare nivel generat are o dificultate pe aceeași scară.
library;

import 'dart:math' as math;

import 'trial.dart';

class SkillRating {
  const SkillRating([this.value = initial, this.trials = 0]);

  factory SkillRating.fromJson(Map<String, Object?> j) =>
      SkillRating((j['value']! as num).toDouble(), j['trials'] as int? ?? 0);

  /// Pornirea: mijlocul scalei nivelurilor (vezi [DifficultyAxes.base]).
  static const initial = 1000.0;

  /// Scara logistică (ca la șah): 400 de puncte = raport de șanse 10:1.
  static const scale = 400.0;

  /// Ținta implicită: ~80% șanse de reușită (specialistul poate cere 90% la un copil sensibil la eșec).
  static const defaultSuccess = 0.8;

  /// Cât contează o reușită după nivelul de ajutor: cu model complet (P4) nu spune nimic despre
  /// abilitate; din prima, fără ajutor, contează integral.
  static const promptCredit = [1.0, 0.6, 0.4, 0.2, 0.0];

  final double value;
  final int trials;

  /// Probabilitatea estimată de reușită la un nivel de dificultate [difficulty].
  double expected(double difficulty) => 1 / (1 + math.pow(10, (difficulty - value) / scale));

  /// Dificultatea la care copilul reușește cu probabilitatea [success] (ex. 0.8).
  double targetDifficulty([double success = defaultSuccess]) {
    assert(success > 0 && success < 1);
    return value - scale * math.log(success / (1 - success)) / math.ln10;
  }

  /// Pasul de ajustare: mare la început (nu știm încă nivelul), apoi se stabilizează.
  double get k => 16 + 64 / (1 + trials / 10);

  /// Scorul unei încercări (0..1): corect × creditul ajutorului × penalizarea încercărilor repetate.
  static double scoreOf({required bool correct, PromptLevel prompt = PromptLevel.p0, int attempts = 1}) =>
      correct ? promptCredit[prompt.index] * (attempts <= 1 ? 1 : 0.7) : 0;

  SkillRating update(double difficulty, double score) {
    assert(score >= 0 && score <= 1);
    return SkillRating(value + k * (score - expected(difficulty)), trials + 1);
  }

  SkillRating updateWith(Trial t, double difficulty) =>
      update(difficulty, scoreOf(correct: t.correct, prompt: t.promptLevel, attempts: t.attempts));

  Map<String, Object?> toJson() => {'value': value, 'trials': trials};

  @override
  String toString() => 'SkillRating(${value.toStringAsFixed(0)}, $trials)';
}
