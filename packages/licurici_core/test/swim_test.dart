import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  SwimPose at(double t, {SwimStyle style = SwimStyle.fish, int ms = 2200, double dx = 0.3, double dy = 0.05}) =>
      swimPose(t, style: style, visibleMs: ms, driftX: dx, driftY: dy, phase: 0.7);

  test('drumul total și durata rămân ale nivelului: progresul merge de la 0 la 1, fără întoarceri', () {
    for (final style in SwimStyle.values) {
      for (final ms in [900, 1500, 2200, 4000]) {
        expect(at(0, style: style, ms: ms).progress, closeTo(0, 1e-9));
        expect(at(1, style: style, ms: ms).progress, closeTo(1, 1e-9));
        var last = -1.0;
        for (var i = 0; i <= 200; i++) {
          final p = at(i / 200, style: style, ms: ms).progress;
          expect(p, greaterThanOrEqualTo(last - 1e-12), reason: '$style $ms ms');
          last = p;
        }
      }
    }
  });

  test('înoată în reprize: viteza variază (împinge, apoi alunecă)', () {
    final thrusts = [for (var i = 0; i <= 100; i++) at(i / 100).thrust];
    expect(thrusts.reduce(max), greaterThan(0.9));
    expect(thrusts.reduce(min), lessThan(0.1));
  });

  test('corpul urmează mersul, cu înclinarea limitată; capul stă, coada bate', () {
    for (var i = 0; i <= 100; i++) {
      final p = at(i / 100, dy: 0.4);
      expect(p.tilt.abs(), lessThanOrEqualTo(0.35));
      expect(bodyWave(0, p).abs(), lessThan(1e-9));
    }
    final tail = [for (var i = 0; i <= 100; i++) bodyWave(1, at(i / 100))];
    expect(tail.reduce(max), greaterThan(0.04));
    expect(tail.reduce(min), lessThan(-0.04));
  });

  test('stilul după vietate: peștii unduiesc, caracatița pulsează, crabul pășește', () {
    expect(swimStyleFor('🐟'), SwimStyle.fish);
    expect(swimStyleFor('🐠'), SwimStyle.fish);
    expect(swimStyleFor('🐙'), SwimStyle.jet);
    expect(swimStyleFor('🦀'), SwimStyle.scuttle);
    final squash = [for (var i = 0; i <= 100; i++) at(i / 100, style: SwimStyle.jet).squash];
    expect(squash.reduce(min), lessThan(0.85));
    expect(squash.reduce(max), closeTo(1, 0.02));
  });
}
