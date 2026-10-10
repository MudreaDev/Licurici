/// Progresul copilului pe trepte, calculat din sesiunile salvate (plan §3, §3.5 b):
/// stăpânire (criteriu pe sesiuni), rating Elo, ultima exersare. Intrarea pentru
/// [SessionPlanner] — „Drumul de azi”.
library;

import 'development.dart';
import 'report.dart';
import 'session.dart';
import 'trial.dart';

List<StepProgress> progressFromSessions(
  List<SessionRecord> sessions, {
  MasteryCriterion criterion = const MasteryCriterion(),
  EloRating elo = const EloRating(),
}) {
  final ordered = List.of(sessions)..sort((a, b) => a.start.compareTo(b.start));
  final perStep = <String, List<(SessionRecord, List<Trial>)>>{};
  for (final s in ordered) {
    final byStep = <String, List<Trial>>{};
    for (final t in s.trials) {
      byStep.putIfAbsent(t.stepId, () => []).add(t);
    }
    for (final e in byStep.entries) {
      perStep.putIfAbsent(e.key, () => []).add((s, e.value));
    }
  }
  return [
    for (final e in perStep.entries)
      if (stepById(e.key) != null) _progress(e.key, e.value, criterion, elo),
  ];
}

StepProgress _progress(
  String stepId,
  List<(SessionRecord, List<Trial>)> history,
  MasteryCriterion criterion,
  EloRating elo,
) {
  var rating = EloRating.start;
  DateTime? masteredAt;
  for (var i = 0; i < history.length; i++) {
    for (final t in history[i].$2) {
      rating = elo.update(rating, t.ratingDifficulty, correct: t.correct, prompt: t.promptLevel);
    }
    final upTo = [for (final h in history.take(i + 1)) h.$2];
    if (masteredAt == null && criterion.evaluate(upTo).mastered) masteredAt = history[i].$1.end;
  }
  final last = history.last.$2.last.at;
  final gameTrials = <String, int>{};
  final gameLastPlayed = <String, DateTime>{};
  for (final (_, trials) in history) {
    for (final t in trials) {
      gameTrials[t.gameId] = (gameTrials[t.gameId] ?? 0) + 1;
      final seen = gameLastPlayed[t.gameId];
      if (seen == null || t.at.isAfter(seen)) gameLastPlayed[t.gameId] = t.at;
    }
  }
  // Doar sesiunile cu destule încercări pe treaptă spun ceva despre cât de greu i-a fost.
  final meaningful = [
    for (final (_, trials) in history)
      if (trials.length >= minTrialsForIndependence) TrialStats(trials).independence,
  ];
  return StepProgress(
    stepId: stepId,
    mastered: masteredAt != null,
    rating: rating,
    masteredAt: masteredAt,
    lastPracticed: last,
    recentIndependence: meaningful.length > 3 ? meaningful.sublist(meaningful.length - 3) : meaningful,
    gameTrials: gameTrials,
    gameLastPlayed: gameLastPlayed,
  );
}

/// Sub atâtea încercări pe treaptă într-o sesiune, independența ei nu se ia în seamă.
const minTrialsForIndependence = 4;

/// Nivelul de pornire estimat din rating-ul treptelor jocului (dificultate adaptivă pe abilități):
/// cel mai mare nivel cu ~80% șanse de reușită, minus unul — prudent, ca jocul nou să înceapă cu
/// reușite. null = nimic de folosit (nicio treaptă a jocului cu rating, sau estimarea ≤ nivelul 1).
int? skillLevel(String gameId, Map<String, double> ratings, {EloRating elo = const EloRating()}) {
  double? best;
  for (final s in stepsForGame(gameId)) {
    final r = ratings[s.id];
    if (r != null && (best == null || r > best)) best = r;
  }
  if (best == null) return null;
  final level = elo.levelFor(best) - 1;
  return level >= 2 ? level : null;
}

/// Obiectivele implicite când nu există un plan de la specialist: pe fiecare arie cu jocuri,
/// prima treaptă încă nestăpânită (în ordinea traseului). Treptele deja stăpânite rămân în
/// listă pentru încălzire, menținere și final.
List<StepProgress> defaultObjectives(List<StepProgress> known, Set<String> availableGames) {
  final byId = {for (final p in known) p.stepId: p};
  final out = <StepProgress>[...known.where((p) => p.mastered)];
  for (final ladder in ladders) {
    for (final step in ladder.steps) {
      if (!step.games.any(availableGames.contains)) continue;
      final p = byId[step.id];
      if (p != null && p.mastered) continue;
      out.add(p ?? StepProgress(stepId: step.id));
      break;
    }
  }
  return out;
}
