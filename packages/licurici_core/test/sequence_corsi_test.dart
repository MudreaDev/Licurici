import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SpatialSpanGame();

  test('florile sunt împrăștiate, în zonă, depărtate între ele; licuricii identici', () {
    for (final level in [1, 6, 12, 20]) {
      final l = game.generate(level, seed: level);
      final pos = l.positions!;
      expect(pos.length, l.axes.pads);
      for (var i = 0; i < pos.length; i++) {
        expect(pos[i].x, inInclusiveRange(0.05, 0.95));
        expect(pos[i].y, inInclusiveRange(0.1, 0.9));
        for (var j = i + 1; j < pos.length; j++) {
          expect(pos[i].distanceTo(pos[j]), greaterThanOrEqualTo(0.16));
        }
      }
      expect(l.pads.map((p) => p.argb).toSet().length, 1);
      expect(l.axes.withSound, isFalse);
      expect(l.sequence.length, l.axes.length);
      for (var i = 1; i < l.sequence.length; i++) {
        expect(l.sequence[i], isNot(l.sequence[i - 1]));
      }
    }
  });

  test('chiar dacă nu încap întâmplător, fiecare floare are un loc', () {
    final pos = SpatialSpanGame.scatter(15, Random(1));
    expect(pos.length, 15);
  });

  test('e în catalog, pe aria Memorie și răbdare', () {
    final e = catalog.firstWhere((e) => e.id == 'licuricii');
    expect(e.route, '/secventa/licuricii');
    expect(e.domain, Domain.fex);
  });
}
