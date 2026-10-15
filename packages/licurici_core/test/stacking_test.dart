import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const g = StackingGame();

  test('3 → 7 inele, pași tot mai mici, o singură culoare de la nivelul 6; tava nu e în ordine', () {
    expect(g.axesFor(1).rings, 3);
    expect(g.axesFor(5).rings, 7);
    expect(g.axesFor(1).step, greaterThan(g.axesFor(7).step));
    expect(g.axesFor(5).sameColor, isFalse);
    expect(g.axesFor(6).sameColor, isTrue);
    for (var level = 1; level <= 9; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = g.generate(level, seed: seed);
        expect(l.towers, hasLength(StackingGame.towers));
        for (final t in l.towers) {
          expect({for (final r in t.tray) r.rank}, {for (var i = 0; i < l.axes.rings; i++) i});
          expect([for (var i = 0; i < t.size; i++) t.tray[i].rank == i].every((x) => x), isFalse);
          // Cel mai mare are lățimea 1, fiecare următor e mai îngust cu pasul nivelului.
          for (final r in t.tray) {
            expect(r.width, closeTo(1 - l.axes.step * r.rank, 1e-9));
          }
          if (l.axes.sameColor) expect({for (final r in t.tray) r.color}, hasLength(1));
        }
      }
    }
  });

  test('rezultatul: stele, nivelul următor și înregistrarea', () {
    final l = g.generate(2, seed: 1);
    final r = StackingResult(l, [
      StackBuild(l.towers[0], wrong: 0, ms: 4000),
      StackBuild(l.towers[1], wrong: 2, ms: 9000),
      StackBuild(l.towers[2], wrong: 0, ms: 5000),
    ]);
    expect(r.stars, 3);
    expect(r.suggestedNextLevel(2), 2);
    final rec = SessionRecorder(childId: 'c')..stackingLevel(r);
    expect(rec.trials.map((t) => t.correct), [true, false, true]);
    expect(rec.trials[1].attempts, 3);
    expect(rec.trials.first.stepId, 'COG4');
    expect(catalogEntry('turnul')!.domain, Domain.cog);
  });
}
