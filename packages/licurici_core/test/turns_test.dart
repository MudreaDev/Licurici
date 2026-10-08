import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = TurnGame();

  test('nivelurile: așteptare tot mai lungă, turn mai înalt, apoi dat rândul și ezitări', () {
    final a = game.axesFor(1), b = game.axesFor(12);
    expect(a.childFirst, isTrue);
    expect(b.childFirst, isFalse);
    expect(b.waitMs, greaterThan(a.waitMs));
    expect(b.blocks, greaterThan(a.blocks));
    expect(a.blocks.isEven, isTrue);
    expect(a.passTurn, isFalse);
    expect(b.passTurn, isTrue);
    expect(b.hesitate, isTrue);
  });

  test('cuburile alternează: calde pentru copil, reci pentru Licurici', () {
    for (final level in [1, 6]) {
      final l = game.generate(level, seed: 2);
      for (final tower in l.colors) {
        expect(tower.length, l.axes.blocks);
        for (final (i, c) in tower.indexed) {
          expect(game.childPlaces(l, i) ? childBlockColors : licuriciBlockColors, contains(c));
        }
      }
    }
  });

  test('rezultatul: atingerile în rândul celuilalt și rândul dat cu ajutor nu sunt „curate”', () {
    final level = game.generate(6, seed: 1);
    final res = TurnResult(level, const [
      TurnCycle(earlyTaps: 0, placeMs: 900),
      TurnCycle(earlyTaps: 2, placeMs: 700),
      TurnCycle(earlyTaps: 0, placeMs: 800, passPrompted: true),
      TurnCycle(earlyTaps: 0, placeMs: 1000),
    ]);
    expect(res.accuracy, 0.5);
    expect(res.earlyTaps, 2);
    final rec = SessionRecorder(childId: 'c')..turnLevel(res);
    expect(rec.trials.length, 4);
    expect(rec.trials[1].offTargetTaps, 2);
    expect(rec.trials[2].promptLevel, PromptLevel.p2);
    expect(rec.trials.first.stepId, 'EMO7');
    expect(catalog.firstWhere((e) => e.id == 'pe-rand').domain, Domain.emo);
  });
}
