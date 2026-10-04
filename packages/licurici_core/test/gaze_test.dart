import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = GazeGame();

  test('părțile sunt echilibrate, cel mult două la rând; obiecte diferite în fiecare rundă', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 60; seed++) {
        final l = game.generate(level, seed: seed);
        final sides = l.rounds.map((r) => r.side).toList();
        expect(sides.where((s) => s == 0), hasLength(l.rounds.length ~/ 2));
        for (var i = 2; i < sides.length; i++) {
          expect(sides[i] == sides[i - 1] && sides[i] == sides[i - 2], isFalse);
        }
        for (final r in l.rounds) {
          expect(r.objects[0].emoji, isNot(r.objects[1].emoji));
          if (l.axes.similar) expect(r.objects[0].group, r.objects[1].group);
        }
      }
    }
  });

  test('indiciul: gest + privire, apoi doar privire', () {
    expect(game.axesFor(1).cue, GazeCue.point);
    expect(game.axesFor(4).cue, GazeCue.look);
    expect(game.generate(1, seed: 1).question, 'Ce arată Licurici?');
    expect(game.generate(5, seed: 1).question, 'Unde se uită Licurici?');
  });

  test('înregistrarea: treapta după indiciu, partea aleasă la greșeală', () {
    final l = game.generate(5, seed: 3);
    final rec = SessionRecorder(childId: 'c')
      ..gazeLevel(GazeResult(l, [
        GazeAnswer(l.rounds[0], firstChoice: l.rounds[0].side, ms: 900),
        GazeAnswer(l.rounds[1], firstChoice: 1 - l.rounds[1].side, extraCue: true),
      ]));
    expect(rec.trials.first.stepId, 'ATN4');
    expect(rec.trials.first.independent, isTrue);
    expect(rec.trials.last.promptLevel, PromptLevel.p3);
    expect(rec.trials.last.chosenId, isNotNull);
    expect(catalogEntry('unde-se-uita')!.domain, Domain.atn);
  });
}
