import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  group('Linia numerelor', () {
    const g = NumberLineGame();

    test('linia crește (10 → 20 → 100), reperele se răresc; numerele nu sunt pe capete sau repere', () {
      expect(g.axesFor(1).toJson(), {'max': 10, 'tick': 1});
      expect(g.axesFor(5).max, 20);
      expect(g.axesFor(8).toJson(), {'max': 100, 'tick': 0});
      for (var level = 1; level <= 9; level++) {
        for (var seed = 0; seed < 40; seed++) {
          final l = g.generate(level, seed: seed);
          final ts = [for (final r in l.rounds) r.target];
          expect(ts.toSet(), hasLength(ts.length));
          expect(ts.length, greaterThanOrEqualTo(5));
          for (final t in ts) {
            expect(t, inExclusiveRange(0, l.axes.max));
            if (l.axes.tick > 1) expect(t % l.axes.tick, isNot(0));
          }
        }
      }
    });

    test('PAE, toleranța de 10% și nivelul următor; încercările păstrează ținta și estimarea', () {
      final l = g.generate(6, seed: 2);
      final t = l.rounds.first.target;
      final r = NumberLineResult(l, [
        NumberLineMark(l.rounds[0], t + 5.0, latencyMs: 1200),
        NumberLineMark(l.rounds[1], l.rounds[1].target - 20.0),
      ]);
      expect(r.paeOf(r.marks[0]), closeTo(0.05, 1e-9));
      expect(r.isClose(r.marks[0]), isTrue);
      expect(r.isClose(r.marks[1]), isFalse);
      expect(r.pae, closeTo(0.125, 1e-9));
      expect(r.suggestedNextLevel(6), 6);
      final rec = SessionRecorder(childId: 'c')..numberLineLevel(r);
      expect(rec.trials.first.correct, isTrue);
      expect(rec.trials.first.targetId, '$t');
      expect(rec.trials.first.stepId, 'PAC-N5');
      expect(rec.trials.last.stimulusId, 'eroare-20');
      expect(catalogEntry('linia-numerelor')!.domain, Domain.pac);
    });
  });

  group('Atinge rapid', () {
    const g = FittsGame();

    test('bulele se micșorează și sar tot mai departe; încap pe teren', () {
      expect(g.sizeFor(1), greaterThan(g.sizeFor(9)));
      expect(g.sizeFor(20), closeTo(0.07, 1e-9));
      for (var level = 1; level <= 10; level++) {
        final l = g.generate(level, seed: level);
        expect(l.targets, hasLength(FittsGame.count + 1));
        for (final t in l.targets) {
          expect(t.x - t.size / 2, greaterThanOrEqualTo(-1e-9));
          expect(t.x + t.size / 2, lessThanOrEqualTo(FittsGame.aspect + 1e-9));
          expect(t.y + t.size / 2, lessThanOrEqualTo(1 + 1e-9));
        }
      }
    });

    test('ID = log2(D/W + 1), throughput și înregistrarea', () {
      final l = g.generate(3, seed: 7);
      final r = FittsResult(l, [const FittsHit(1, 500), const FittsHit(2, 700, misses: 1)]);
      final d = l.targets[1].distanceTo(l.targets[0]);
      expect(r.idOf(1), closeTo(log2(d / l.targets[1].size + 1), 1e-9));
      expect(r.throughput, greaterThan(0));
      expect(r.misses, 1);
      final rec = SessionRecorder(childId: 'c')..fittsLevel(r);
      expect(rec.trials.first.correct, isTrue);
      expect(rec.trials.last.offTargetTaps, 1);
      expect(rec.trials.first.stepId, 'MOT0');
      expect(catalogEntry('atinge-rapid')!.domain, Domain.mot);
    });
  });
}

double log2(double x) => log(x) / ln2;
