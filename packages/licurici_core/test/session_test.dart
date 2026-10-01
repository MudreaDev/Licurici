import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1);
  const planner = SessionPlanner();
  final allGames = {'emotii', 'ce-simte', 'ce-ma-ajuta', 'cine-stie', 'situatii', 'pescarul', 'numaram'};

  SessionPlan plan(List<StepProgress> p, {Set<String>? allowed, int seed = 1}) =>
      planner.plan(progress: p, allowedGames: allowed ?? allGames, now: now, random: Random(seed));

  test('încălzire pe ceva stăpânit, ținte în ordinea ratingului, final pe succes', () {
    final p = plan([
      StepProgress(stepId: 'EMO2', mastered: true, masteredAt: now.subtract(const Duration(days: 3))),
      const StepProgress(stepId: 'EMO4', rating: 1100),
      const StepProgress(stepId: 'EMO3', rating: 950),
      StepProgress(stepId: 'PAC-N2', mastered: true, masteredAt: now.subtract(const Duration(days: 1))),
    ]);
    final kinds = p.activities.map((a) => a.kind).toList();
    expect(kinds.first, ActivityKind.warmUp);
    expect(kinds.last, ActivityKind.finale);
    final targets = p.activities.where((a) => a.kind == ActivityKind.target).toList();
    expect(targets.map((a) => a.stepId), ['EMO3', 'EMO4']);
    // Materialul cunoscut amestecat vine din aceeași arie (EMO2 pentru EMO3).
    expect(targets.first.mixStepId, 'EMO2');
    expect(targets.first.knownMix, closeTo(0.3, 1e-9));
    expect(p.schedule, hasLength(p.activities.length));
  });

  test('doar jocurile alocate apar; treptele fără joc alocat sunt sărite', () {
    final p = plan(
      [const StepProgress(stepId: 'EMO3'), const StepProgress(stepId: 'FEX2')],
      allowed: {'pescarul'},
    );
    expect(p.schedule, ['pescarul']);
  });

  test('verificare de menținere la ~7 și ~30 de zile', () {
    StepProgress m(int daysAgo) => StepProgress(
          stepId: 'EMO2',
          mastered: true,
          masteredAt: now.subtract(Duration(days: daysAgo)),
        );
    bool hasMaintenance(int d) =>
        plan([m(d), const StepProgress(stepId: 'EMO3')]).activities.any((a) => a.kind == ActivityKind.maintenance);
    expect(hasMaintenance(7), isTrue);
    expect(hasMaintenance(31), isTrue);
    expect(hasMaintenance(15), isFalse);
    expect(hasMaintenance(1), isFalse);
  });

  test('fără nimic stăpânit: doar ținte, fără amestec', () {
    final p = plan([const StepProgress(stepId: 'EMO3'), const StepProgress(stepId: 'FEX2')]);
    expect(p.activities.every((a) => a.kind == ActivityKind.target), isTrue);
    expect(p.activities.every((a) => a.knownMix == 0), isTrue);
  });

  test('nimic de jucat → plan gol', () {
    expect(plan(const [], allowed: {}).isEmpty, isTrue);
  });
}
