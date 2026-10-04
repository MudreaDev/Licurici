import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = FeedGame();

  test('peștele: întâi mare și pe loc, apoi mai mic, mai rapid, mai mulți', () {
    expect(game.axesFor(1).speed, 0);
    expect(game.axesFor(1).fish, 1);
    expect(game.axesFor(9).fish, 3);
    FeedAxes? prev;
    for (var l = 1; l <= 30; l++) {
      final ax = game.axesFor(l);
      if (prev != null) {
        expect(ax.size, lessThanOrEqualTo(prev.size));
        expect(ax.speed, greaterThanOrEqualTo(prev.speed));
      }
      prev = ax;
    }
  });

  test('peștii înoată dus-întors fără să iasă din apă; benzi diferite', () {
    for (var level = 1; level <= 14; level++) {
      for (var seed = 0; seed < 20; seed++) {
        final l = game.generate(level, seed: seed);
        for (final r in l.rounds) {
          expect(r.hungry, inInclusiveRange(0, r.fish.length - 1));
          final ys = r.fish.map((f) => f.y).toList();
          for (var a = 0; a < ys.length; a++) {
            for (var b = a + 1; b < ys.length; b++) {
              expect((ys[a] - ys[b]).abs(), greaterThanOrEqualTo(0.25 - 1e-9));
            }
          }
          for (final f in r.fish) {
            for (var t = 0.0; t < 60; t += 0.7) {
              final p = f.at(t, l.axes.speed);
              expect(p.x, inInclusiveRange(0.12 - 1e-9, 0.88 + 1e-9));
            }
          }
        }
      }
    }
  });

  test('mișcarea e continuă (fără salturi) și se întoarce la margine', () {
    const f = FeedFish(art: '🐟', x: 0.8, y: 0.4, dir: 1, speedFactor: 1);
    var prev = f.at(0, 0.2);
    for (var t = 0.05; t < 20; t += 0.05) {
      final p = f.at(t, 0.2);
      expect((p.x - prev.x).abs(), lessThanOrEqualTo(0.2 * 0.05 + 1e-9));
      prev = p;
    }
    expect(f.heading(0, 0.2), 1);
    expect(f.heading(0.6, 0.2), -1); // a atins marginea din dreapta și s-a întors
  });

  test('rezultatul și înregistrarea', () {
    final l = game.generate(4, seed: 1);
    final r = FeedResult(l, [
      FeedAttempt(l.rounds[0], precision: 0.2, ms: 1500),
      FeedAttempt(l.rounds[1], precision: 0.6, misses: 2),
    ]);
    expect(r.accuracy, 0.5);
    expect(r.meanPrecision, closeTo(0.4, 1e-9));
    final rec = SessionRecorder(childId: 'c')..feedLevel(r);
    expect(rec.trials.last.attempts, 3);
    expect(rec.trials.first.stepId, 'MOT4');
    expect(catalogEntry('hraneste-pestii')!.domain, Domain.mot);
  });
}
