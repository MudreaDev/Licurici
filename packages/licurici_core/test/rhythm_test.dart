import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = RhythmGame();

  test('ritmurile: bătăile cresc, apar pauze lungi, apoi a doua tobă', () {
    expect(game.axesFor(1).beats, 2);
    expect(game.axesFor(40).beats, 6);
    for (var level = 1; level <= 14; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        for (final p in l.patterns) {
          expect(p.beats, hasLength(l.axes.beats));
          expect(p.beats.first.atMs, 0);
          final gaps = [for (var i = 1; i < p.beats.length; i++) p.beats[i].atMs - p.beats[i - 1].atMs];
          expect(gaps.every((g) => g == RhythmGame.step || g == RhythmGame.step * 2), isTrue);
          if (!l.axes.uneven) expect(gaps.every((g) => g == RhythmGame.step), isTrue);
          if (l.axes.uneven) expect(gaps.any((g) => g > RhythmGame.step), isTrue);
          if (l.axes.drums == 1) expect(p.beats.every((b) => b.drum == 0), isTrue);
          if (l.axes.drums == 2) expect(p.beats.map((b) => b.drum).toSet(), hasLength(2));
        }
      }
    }
  });

  test('comparația: ritm păstrat cu toleranță; bătăi lipsă sau toba greșită = incorect', () {
    const p = RhythmPattern([RhythmBeat(0, 0), RhythmBeat(600, 0), RhythmBeat(1800, 1)]);
    RhythmPlay play(List<(int, int)> t) => RhythmPlay(p, [for (final (a, d) in t) RhythmBeat(a, d)]);
    expect(play([(0, 0), (650, 0), (1750, 1)]).correct, isTrue);
    expect(play([(0, 0), (650, 0), (1750, 1)]).timingErrorMs, 75);
    expect(play([(0, 0), (600, 0)]).correct, isFalse);
    expect(play([(0, 0), (600, 0)]).timingErrorMs, isNull);
    expect(play([(0, 0), (600, 1), (1800, 1)]).correct, isFalse);
    // Lung–scurt bătut egal: forma ritmului se pierde.
    expect(play([(0, 0), (600, 0), (1200, 1)]).correct, isFalse);
    expect(p.code, 'xx.o');
  });

  test('rezultatul și înregistrarea', () {
    final l = game.generate(5, seed: 2);
    final ok = RhythmPlay(l.patterns[0], l.patterns[0].beats, startMs: 800);
    final bad = RhythmPlay(l.patterns[1], l.patterns[1].beats.take(1).toList(), replays: 1);
    final r = RhythmResult(l, [ok, bad]);
    expect(r.accuracy, 0.5);
    expect(r.longest, l.axes.beats);
    final rec = SessionRecorder(childId: 'c')..rhythmLevel(r);
    expect(rec.trials.first.stepId, 'IMI4');
    expect(rec.trials.last.promptLevel, PromptLevel.p4);
    expect(catalogEntry('toba-magica')!.domain, Domain.imi);
  });
}
