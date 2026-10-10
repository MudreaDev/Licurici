// Cât durează calculul de pe ecranul principal (progresul pe trepte + „Drumul de azi”) pe un
// istoric mare, ca cel de la finalul retenției (24 de luni). Pentru README §20 și cercetare §08:
//
//   dart run tool/bench_progress.dart
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';

void main() {
  for (final sessions in [30, 120, 500]) {
    final history = _history(sessions, Random(1));
    final trials = history.fold<int>(0, (n, s) => n + s.trials.length);
    final games = {for (final l in ladders) for (final s in l.steps) ...s.games};
    // Încălzire (JIT), apoi media pe 20 de rulări.
    for (var i = 0; i < 3; i++) {
      _run(history, games);
    }
    final sw = Stopwatch()..start();
    const runs = 20;
    for (var i = 0; i < runs; i++) {
      _run(history, games);
    }
    final ms = sw.elapsedMicroseconds / runs / 1000;
    print('$sessions sesiuni, $trials încercări: ${ms.toStringAsFixed(1)} ms');
  }
}

SessionPlan _run(List<SessionRecord> history, Set<String> games) {
  final progress = progressFromSessions(history);
  return const SessionPlanner().plan(
    progress: defaultObjectives(progress, games),
    allowedGames: games,
    now: DateTime.utc(2028, 10, 1),
    random: Random(7),
  );
}

/// Sesiuni de ~40 de încercări pe 4–5 trepte, ca o sesiune reală de 15–20 de minute.
List<SessionRecord> _history(int n, Random r) {
  final steps = [for (final l in ladders) for (final s in l.steps) if (s.games.isNotEmpty) s];
  return [
    for (var i = 0; i < n; i++)
      () {
        final start = DateTime.utc(2026, 10, 1).add(Duration(days: i));
        final picked = [for (var k = 0; k < 5; k++) steps[r.nextInt(steps.length)]];
        return SessionRecord(
          id: 's$i',
          childId: 'c',
          start: start,
          end: start.add(const Duration(minutes: 18)),
          trials: [
            for (final (k, s) in picked.indexed)
              for (var j = 0; j < 8; j++)
                Trial(
                  stepId: s.id,
                  gameId: s.games[r.nextInt(s.games.length)],
                  correct: r.nextDouble() < 0.75,
                  promptLevel: PromptLevel.values[r.nextInt(3)],
                  level: 1 + r.nextInt(8),
                  stimulusSet: 'set${r.nextInt(3)}',
                  at: start.add(Duration(seconds: 25 * (k * 8 + j))),
                ),
          ],
        );
      }(),
  ];
}
