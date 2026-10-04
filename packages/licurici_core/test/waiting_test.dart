import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = WaitGame();

  test('așteptarea crește, tentațiile apar de la nivelul 4', () {
    WaitAxes? prev;
    for (var l = 1; l <= 30; l++) {
      final ax = game.axesFor(l);
      expect(ax.minWaitMs, lessThanOrEqualTo(ax.maxWaitMs));
      if (prev != null) {
        expect(ax.maxWaitMs, greaterThanOrEqualTo(prev.maxWaitMs));
        expect(ax.flickers, greaterThanOrEqualTo(prev.flickers));
      }
      prev = ax;
    }
    expect(game.axesFor(3).flickers, 0);
    expect(game.axesFor(4).flickers, 1);
    expect(game.axesFor(40).maxWaitMs, 6000);
  });

  test('licăririle sunt înainte de verde, distanțate, niciodată chiar lângă verde', () {
    for (var level = 1; level <= 15; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.trials, hasLength(l.axes.trials));
        for (final t in l.trials) {
          expect(t.waitMs, inInclusiveRange(l.axes.minWaitMs, l.axes.maxWaitMs));
          for (final (i, f) in t.flickersAtMs.indexed) {
            expect(f + WaitLevel.flickerMs, lessThanOrEqualTo(t.waitMs - 600));
            if (i > 0) expect(f - t.flickersAtMs[i - 1], greaterThanOrEqualTo(700));
          }
        }
      }
    }
  });

  test('rezultat: anticipările strică încercarea; cea mai lungă așteptare reușită', () {
    final l = game.generate(5, seed: 3);
    final res = WaitResult(l, [
      WaitResponse(l.trials[0], rtMs: 400),
      WaitResponse(l.trials[1], anticipations: 2, rtMs: 300),
      WaitResponse(l.trials[2]),
    ]);
    expect(res.anticipations, 2);
    expect(res.accuracy, closeTo(1 / 3, 1e-9));
    expect(res.longestWaitMs, l.trials[0].waitMs);
    final rec = SessionRecorder(childId: 'c')..waitLevel(res);
    expect(rec.trials[1].offTargetTaps, 2);
    expect(rec.trials.first.stepId, 'FEX1');
    expect(catalogEntry('semaforul')!.domain, Domain.fex);
  });
}
