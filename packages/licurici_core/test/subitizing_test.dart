import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('Câte sunt?: cantitatea în interval, arătată tot mai scurt; nu de două ori la rând aceeași', () {
    expect(CateSuntGame.showMsFor(1), greaterThan(CateSuntGame.showMsFor(7)));
    expect(CateSuntGame.showMsFor(20), 500);
    for (var tier = 1; tier <= 8; tier++) {
      final (lo, hi) = CateSuntGame.rangeFor(tier);
      for (var seed = 0; seed < 20; seed++) {
        final lesson = const CateSuntGame().build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed)));
        int? last;
        for (final r in lesson.rounds) {
          final n = (r.visuals.single as ObjectsVisual).total;
          expect(n, inInclusiveRange(lo, hi));
          expect(n, isNot(last));
          last = n;
          expect(r.showMs, CateSuntGame.showMsFor(tier));
          expect(r.stimulusId, 'n-$n');
          expect(r.choices.singleWhere((c) => c.correct).label, '$n');
        }
      }
    }
    expect(catalogEntry('cate-sunt')!.domain, Domain.pac);
    expect(stepsForGame('cate-sunt').single.id, 'PAC-N1');
  });
}
