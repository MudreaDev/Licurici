import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('contururile formelor sunt închise și în jurul centrului', () {
    for (final (w, _) in hiddenShapes) {
      final pts = shapeOutline(w, const Point(0.5, 0.5), 0.4, 0.2);
      expect(pts.first.distanceTo(pts.last), lessThan(1e-6), reason: w);
      for (final p in pts) {
        expect(p.distanceTo(const Point(0.5, 0.5)), lessThan(0.4), reason: w);
      }
    }
  });

  test('desenul: forma țintă e cea corectă, liniile rămân în casetă, mai multe linii la tier mare', () {
    for (final tier in [1, 3, 6, 12]) {
      for (var seed = 0; seed < 20; seed++) {
        final ctx = GameContext(difficulty: Difficulty(tier), grade: Grade.parseCodes('1').first, random: Random(seed));
        for (final r in const FormaAscunsaGame().generate(ctx).rounds) {
          final v = r.visuals.single as HiddenShapeVisual;
          expect(v.lines.length, tier <= 1 ? 2 : (tier <= 3 ? 4 : (tier <= 6 ? 6 : 9)));
          for (final l in v.lines) {
            for (final p in l) {
              expect(p.x, inInclusiveRange(0, 1));
              expect(p.y, inInclusiveRange(0, 1));
            }
          }
          final right = r.choices.singleWhere((c) => c.correct);
          expect(r.stimulusId, right.id);
          // Ținta e conturul închis al formei alese.
          final t = v.lines[v.target];
          expect(t.first.distanceTo(t.last), lessThan(1e-6));
        }
      }
    }
  });
}
