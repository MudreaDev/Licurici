import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('numele locurilor din dulap', () {
    expect(PozitiiGame.place(2, 1, 0, 0), 'sus');
    expect(PozitiiGame.place(2, 1, 1, 0), 'jos');
    expect(PozitiiGame.place(1, 2, 0, 0), 'în stânga');
    expect(PozitiiGame.place(1, 2, 0, 1), 'în dreapta');
    expect(PozitiiGame.place(3, 3, 1, 1), 'în mijloc');
    expect(PozitiiGame.place(3, 3, 0, 2), 'sus, în dreapta');
    expect(PozitiiGame.place(3, 3, 2, 0), 'jos, în stânga');
  });

  test('răspunsul corect e obiectul din locul întrebat; trepte: sus/jos → stânga/dreapta → cruce → 3 × 3', () {
    for (final (tier, rows, cols) in [(1, 2, 1), (3, 1, 2), (6, 3, 3), (9, 3, 3)]) {
      final ctx = GameContext(difficulty: Difficulty(tier), grade: Grade.parseCodes('G').first, random: Random(tier));
      for (final r in const PozitiiGame().generate(ctx).rounds) {
        final shelf = r.visuals.single as ShelfVisual;
        expect((shelf.rows, shelf.cols), (rows, cols));
        final t = shelf.target!;
        final where = PozitiiGame.place(rows, cols, t ~/ cols, t % cols);
        expect(r.prompt, 'Ce e $where?');
        final right = r.choices.singleWhere((c) => c.correct);
        expect(right.art, shelf.cells[t]);
        // Toate variantele sunt în dulap.
        expect(r.choices.every((c) => shelf.cells.values.contains(c.art)), isTrue);
      }
    }
  });
}
