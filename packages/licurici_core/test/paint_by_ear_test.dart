import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = PaintGame();

  test('cererile se potrivesc planșei și paletei', () {
    for (var level = 1; level <= 8; level++) {
      final axes = game.axesFor(level);
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds, hasLength(PaintGame.rounds));
        for (final r in l.rounds) {
          expect(r.palette, hasLength(axes.colors));
          expect(r.slots, hasLength(axes.sized ? 2 : axes.objects));
          expect(r.tasks, hasLength(axes.pair ? 2 : 1));
          expect(r.tasks.every((t) => r.palette.contains(t.color) && t.slot < r.slots.length), isTrue);
          expect(r.tasks.map((t) => t.slot).toSet(), hasLength(r.tasks.length));
          if (axes.sized) expect(r.slots.map((s) => s.thing).toSet(), hasLength(1));
        }
        // Aceeași culoare nu se cere de două ori la rând.
        for (var i = 1; i < l.rounds.length; i++) {
          expect(l.rounds[i].tasks.first.color, isNot(l.rounds[i - 1].tasks.first.color));
        }
      }
    }
  });

  test('ce se rostește: culoarea, mărimea cu acordul ei, „și” la două colorări', () {
    expect(game.generate(1, seed: 1).rounds.first.speak.single, matches(RegExp(r'^Colorează \S+ cu \S+$')));
    expect(const PaintSlot(PaintThing('🚗', 'mașina', feminine: true), big: false).name, 'mașina mică');
    final r = game.generate(7, seed: 2).rounds.first;
    expect(r.speak, hasLength(3));
    expect(r.speak[1], 'și');
    expect(r.speak.first, anyOf(contains(' mare cu '), contains(' mic cu '), contains(' mică cu ')));
  });

  test('rezultat și încercările salvate', () {
    final l = game.generate(4, seed: 3);
    final answers = [for (final (i, r) in l.rounds.indexed) PaintAnswer(r, wrong: i < 3 ? 1 : 0, ms: 1500, firstWrong: i < 3 ? 'x:roșu' : null)];
    final result = PaintResult(l, answers);
    expect(result.stars, 1);
    expect(result.suggestedNextLevel(4), 3);
    final rec = SessionRecorder(childId: 'c')..paintLevel(result);
    expect(rec.trials, hasLength(PaintGame.rounds));
    expect(rec.trials.first.stepId, 'LRC4');
    expect(rec.trials.first.chosenId, 'x:roșu');
    expect(rec.trials.last.correct, isTrue);
  });
}
