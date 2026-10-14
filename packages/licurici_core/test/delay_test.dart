import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const g = DelayGame();

  test('așteptarea crește (5 s → 30 s), câștigul scade (3 → 2); ofertele variază puțin', () {
    expect(g.waitMsFor(1), 5000);
    expect(g.waitMsFor(9), 30000);
    expect(g.laterFor(5), 3);
    expect(g.laterFor(6), 2);
    final l = g.generate(3, seed: 1);
    expect(l.offers, hasLength(DelayGame.count));
    for (final o in l.offers) {
      expect(o.waitMs, inInclusiveRange(g.waitMsFor(3) * 0.85, g.waitMsFor(3) * 1.15));
    }
  });

  test('stele, rata de așteptare, nivelul următor și înregistrarea', () {
    final l = g.generate(1, seed: 2);
    final r = DelayResult(l, [
      DelayChoice(l.offers[0], waited: true, completed: true, waitedMs: 5000),
      DelayChoice(l.offers[1], waited: false, completed: false),
      DelayChoice(l.offers[2], waited: true, completed: false, waitedMs: 2000),
      DelayChoice(l.offers[3], waited: true, completed: true, waitedMs: 5000),
    ]);
    expect(r.starsWon, 3 + 1 + 1 + 3);
    expect(r.completedRate, 0.5);
    expect(r.suggestedNextLevel(1), 1);
    final rec = SessionRecorder(childId: 'c')..delayLevel(r);
    expect([for (final t in rec.trials) t.stimulusId], ['asteapta', 'acum', 'a-renuntat', 'asteapta']);
    expect(rec.trials.first.stepId, 'FEX1b');
    expect(catalogEntry('acum-sau-mai-mult')!.domain, Domain.fex);
  });
}
