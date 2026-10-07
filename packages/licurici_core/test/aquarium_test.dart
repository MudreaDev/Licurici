import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

SwimmingFish _fish(String id, Point<double> at) =>
    SwimmingFish(id: id, species: 'clovn', length: 0.2, cruise: 0.12, at: at);

double _dist(Point<double> a, Point<double> b) => a.distanceTo(b);

void main() {
  group('volumul peștelui', () {
    for (final s in fishSpecies) {
      test('${s.id}: silueta, grosimea și lumina au sens', () {
        final b = FishBody.compute(s, width: 250);
        expect(b.height, 150);
        var inside = 0;
        var maxT = 0.0;
        for (var i = 0; i < b.coverage.length; i++) {
          if (b.coverage[i] == 1) inside++;
          maxT = max(maxT, b.thickness[i]);
          if (b.coverage[i] == 0) expect(b.thickness[i], 0);
          expect(b.light[i], inInclusiveRange(-1, 1));
        }
        // Peștele ocupă o parte rezonabilă din casetă.
        expect(inside / b.coverage.length, inInclusiveRange(0.2, 0.75));
        expect(maxT, closeTo(1, 0.05));
        // Colțurile casetei sunt în afara peștelui.
        expect(b.coverage[0], 0);
        expect(b.coverage[b.coverage.length - 1], 0);
        // Ochiul e pe corp, în partea groasă.
        final (eye, _) = s.eye;
        final i = (eye.y / 4).round() * b.width + (eye.x / 4).round();
        expect(b.coverage[i], 1);
        expect(b.thickness[i], greaterThan(0.3));
      });
    }

    test('spatele e luminat, burta e în umbră', () {
      final s = fishSpeciesById('balon')!;
      final b = FishBody.compute(s, width: 250);
      double at(double x, double y) => b.light[(y / 4).round() * b.width + (x / 4).round()];
      expect(at(500, 150), greaterThan(at(500, 460)));
    });
  });

  group('acvariul', () {
    test('peștii rămân în apă, oricât ar înota', () {
      final a = Aquarium(width: 1.6, seed: 3);
      for (var i = 0; i < 6; i++) {
        a.add(_fish('f$i', Point(0.2 + i * 0.2, 0.5)));
      }
      for (var t = 0; t < 60 * 120; t++) {
        a.step(1 / 60);
        if (t % 300 == 0) a.tap(Point(0.8, 0.5));
        for (final f in a.fish) {
          expect(f.pos.x, inInclusiveRange(0, a.width));
          expect(f.pos.y, inInclusiveRange(Aquarium.top, Aquarium.bottom));
          expect(f.facing, inInclusiveRange(-1, 1));
        }
      }
    });

    test('la atingere, peștii din apropiere fug de deget', () {
      final a = Aquarium(width: 1.6, seed: 1);
      final near = _fish('aproape', const Point(0.85, 0.5));
      final far = _fish('departe', const Point(1.5, 0.3));
      a
        ..add(near)
        ..add(far);
      final tap = const Point(0.8, 0.5);
      final before = _dist(near.pos, tap);
      a.tap(tap);
      expect(near.mode, FishMode.flee);
      expect(far.mode, isNot(FishMode.flee));
      for (var i = 0; i < 30; i++) {
        a.step(1 / 60);
      }
      expect(_dist(near.pos, tap), greaterThan(before + 0.1));
    });

    test('la apăsare lungă se adună în jurul degetului, apoi pleacă', () {
      final a = Aquarium(width: 1.6, seed: 2);
      for (var i = 0; i < 5; i++) {
        a.add(_fish('f$i', Point(0.15 + i * 0.3, 0.2 + (i % 2) * 0.5)));
      }
      const finger = Point(0.8, 0.5);
      for (var t = 0; t < 60 * 8; t++) {
        a
          ..gather(finger)
          ..step(1 / 60);
      }
      for (final f in a.fish) {
        expect(f.mode, FishMode.gather);
        expect(_dist(f.pos, finger), lessThan(0.25));
      }
      a.release();
      expect(a.fish.every((f) => f.mode != FishMode.gather), isTrue);
    });

    test('mâncarea cade și e mâncată; evenimentul spune cine a mâncat', () {
      final a = Aquarium(width: 1.6, seed: 5);
      a
        ..add(_fish('a', const Point(0.4, 0.5)))
        ..add(_fish('b', const Point(1.2, 0.5)))
        ..feed(0.8, flakes: 4);
      final ate = <String>{};
      for (var t = 0; t < 60 * 30 && a.food.isNotEmpty; t++) {
        a.step(1 / 60);
        for (final e in a.drainEvents()) {
          if (e is FishAte) ate.add(e.fishId);
        }
      }
      expect(a.food, isEmpty);
      expect(ate, isNotEmpty);
    });

    test('peștele privește în direcția în care înoată', () {
      final a = Aquarium(width: 1.6, seed: 9);
      final f = _fish('x', const Point(1.2, 0.5));
      a.add(f);
      f.target = const Point(0.2, 0.5);
      for (var t = 0; t < 60; t++) {
        a.step(1 / 60);
        f.target = const Point(0.2, 0.5);
      }
      expect(f.facing, -1);
      expect(f.mouth.x, lessThan(f.pos.x));
    });

    test('peștele nou intră de sus, în apă', () {
      final a = Aquarium(width: 1.6);
      final f = _fish('nou', const Point(0.8, 0.5));
      a.add(f, diveIn: true);
      expect(f.pos.y, lessThan(0));
      for (var t = 0; t < 120; t++) {
        a.step(1 / 60);
      }
      expect(f.pos.y, greaterThan(Aquarium.top));
    });
  });
}
