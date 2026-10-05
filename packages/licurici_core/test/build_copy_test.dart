import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = BuildGame();

  test('modelul se poate face din paletă; distractorii nu apar în model', () {
    for (var level = 1; level <= 12; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        for (final r in l.rounds) {
          expect(r.model, hasLength(r.cols * r.rows));
          expect(r.model.toSet().length, greaterThanOrEqualTo(2));
          expect(r.palette.toSet(), hasLength(r.palette.length));
          expect(r.palette.toSet().containsAll(r.model.toSet()), isTrue);
          final extra = r.palette.toSet().difference(r.model.toSet());
          expect(extra.length, lessThanOrEqualTo(l.axes.distractors));
        }
      }
    }
    expect(game.axesFor(1).hideModelMs, isNull);
    expect(game.axesFor(8).hideModelMs, isNotNull);
  });

  test('înregistrarea', () {
    final l = game.generate(7, seed: 1);
    final rec = SessionRecorder(childId: 'c')
      ..buildLevel(BuildResult(l, [BuildSolve(l.rounds[0], wrongMoves: 0), BuildSolve(l.rounds[1], wrongMoves: 5, peeked: true)]));
    expect(rec.trials.first.correct, isTrue);
    expect(rec.trials.last.promptLevel, PromptLevel.p3);
    expect(rec.trials.first.stimulusSet, 'din-memorie');
    expect(catalogEntry('construieste')!.domain, Domain.imi);
  });
}
