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
      rating = elo.update(rating, t.difficulty ?? EloRating.start, correct: t.correct, prompt: t.promptLevel);
    }
    final upTo = [for (final h in history.take(i + 1)) h.$2];
    if (masteredAt == null && criterion.evaluate(upTo).mastered) masteredAt = history[i].$1.end;
  }
  final last = history.last.$2.last.at;
  return StepProgress(
    stepId: stepId,
    mastered: masteredAt != null,
    rating: rating,
    masteredAt: masteredAt,
    lastPracticed: last,
  );
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
