import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = CauseGame();

  test('de la un obiect mare în mijloc la șase, fără suprapuneri', () {
    final one = game.generate(1, seed: 1);
    expect(one.objects, hasLength(1));
    expect(one.objects.single.x, closeTo(0.5, 0.05));
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.objects, hasLength(game.countFor(level)));
        expect(l.objects.map((o) => o.object.emoji).toSet(), hasLength(l.objects.length));
        for (var a = 0; a < l.objects.length; a++) {
          final o = l.objects[a];
          expect(o.x, inExclusiveRange(0, 1));
          expect(o.y, inExclusiveRange(0, 1));
          for (var b = a + 1; b < l.objects.length; b++) {
            final p = l.objects[b];
            final dx = (o.x - p.x) * 16 / 9, dy = o.y - p.y;
            expect(dx * dx + dy * dy, greaterThan(l.size * l.size * 0.8), reason: 'se suprapun');
          }
        }
      }
    }
  });

  test('rezultat: proporția atingerilor țintite, explorarea, nivelul următor', () {
    final l = game.generate(3, seed: 2);
    final e = l.objects.map((o) => o.object.emoji).toList();
    final r = CauseResult(l, [
      CauseTouch(onObject: true, object: e[0]),
      const CauseTouch(onObject: false),
      CauseTouch(onObject: true, object: e[1], sinceLastMs: 900),
      CauseTouch(onObject: true, object: e[1], sinceLastMs: 700),
    ]);
    expect(r.intentional, 0.75);
    expect(r.explored, 2);
    expect(r.stars, 3);
    expect(r.suggestedNextLevel(3), 3);
    final rec = SessionRecorder(childId: 'c')..causeLevel(r);
    expect(rec.trials, hasLength(3));
    expect(rec.trials[1].offTargetTaps, 1);
    expect(rec.trials.first.stepId, 'COG1');
    expect(catalogEntry('atinge-si-vezi')!.domain, Domain.cog);
  });
}
