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
          expect(f.pos.y, inInclusiveRange(Aquarium.top, Aquarium.floorAt(f.z)));
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
      final tap = const Point(0.75, 0.5);
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
      for (var t = 0; t < 90; t++) {
        f
          ..target = const Point(0.2, 0.5)
          ..targetZ = f.z;
        a.step(1 / 60);
      }
      expect(f.facing, closeTo(-1, 0.05));
      expect(f.mouth.x, lessThan(f.pos.x));
    });

    test('peștele-balon se umflă când e atins, apoi se dezumflă; ceilalți nu', () {
      final a = Aquarium(width: 1.6, seed: 4);
      final balon = SwimmingFish(id: 'b', species: 'balon', length: 0.2, cruise: 0.1, at: const Point(0.8, 0.5));
      final clovn = _fish('c', const Point(0.9, 0.5));
      a
        ..add(balon)
        ..add(clovn)
        ..tap(const Point(0.85, 0.5));
      expect(balon.puff, 1);
      expect(clovn.puff, 0);
      for (var t = 0; t < 60; t++) {
        a.step(1 / 60);
      }
      expect(balon.puff, greaterThan(0.6)); // încă umflat după 1 s
      for (var t = 0; t < 60 * 5; t++) {
        a.step(1 / 60);
      }
      expect(balon.puff, 0);
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

    test('adâncimea: fuge spre fundal, vine la geam când e chemat, rămâne în acvariu', () {
      final a = Aquarium(width: 1.6, seed: 8);
      final f = _fish('z', const Point(0.85, 0.5))..z = 0.2;
      a.add(f);
      a.tap(const Point(0.75, 0.5));
      for (var t = 0; t < 40; t++) {
        a.step(1 / 60);
      }
      expect(f.z, greaterThan(0.3));
      expect(f.scale, lessThan(depthScale(0.2)));
      for (var t = 0; t < 60 * 6; t++) {
        a
          ..gather(const Point(0.8, 0.5))
          ..step(1 / 60);
        expect(f.z, inInclusiveRange(0, 1));
      }
      expect(f.z, lessThan(0.2));
    });

    test('virajul: coada rămâne în urmă (viteza de rotire), apoi se liniștește', () {
      final a = Aquarium(width: 1.6, seed: 6);
      final f = _fish('v', const Point(0.8, 0.5));
      a.add(f);
      var maxRate = 0.0;
      for (var t = 0; t < 60 * 3; t++) {
        f
          ..target = const Point(0.2, 0.5)
          ..targetZ = f.z;
        a.step(1 / 60);
        maxRate = max(maxRate, f.turnRate.abs());
      }
      expect(maxRate, greaterThan(1));
      expect(f.turnRate.abs(), lessThan(0.3));
      expect(f.thrust, inInclusiveRange(0, 1));
    });

    test('atins chiar pe el, peștele se învârte bucuros (nu fuge); vecinii fug', () {
      final a = Aquarium(width: 1.6, seed: 2);
      final hit = _fish('atins', const Point(0.8, 0.5));
      final near = _fish('vecin', const Point(1.0, 0.5));
      a
        ..add(hit)
        ..add(near)
        ..tap(const Point(0.8, 0.5));
      expect(hit.mode, FishMode.spin);
      expect(near.mode, FishMode.flee);
      expect(a.drainEvents().whereType<FishTickled>().single.fishId, 'atins');
      final yaw0 = hit.yaw;
      var turned = 0.0;
      for (var t = 0; t < 45; t++) {
        final before = hit.yaw;
        a.step(1 / 60);
        var d = hit.yaw - before;
        if (d > pi) d -= 2 * pi;
        if (d < -pi) d += 2 * pi;
        turned += d;
      }
      expect(turned.abs(), greaterThan(pi)); // o întoarcere mare, nu un tremur
      expect(yaw0, isNotNull);
      for (var t = 0; t < 60; t++) {
        a.step(1 / 60);
      }
      expect(hit.mode, isNot(FishMode.spin));
    });

    test('caută pe fund: coboară, ciugulește (capul în jos), apoi pleacă', () {
      final a = Aquarium(width: 1.6, seed: 11);
      final f = _fish('f', const Point(0.8, 0.5))..z = 0.4;
      a.add(f);
      a.forage(f); // ca și cum ar fi ales singur
      var pecks = 0;
      var maxNod = 0.0;
      for (var t = 0; t < 60 * 9; t++) {
        a.step(1 / 60);
        pecks += a.drainEvents().whereType<FishPecked>().length;
        maxNod = max(maxNod, f.nod);
        expect(f.pos.y, lessThanOrEqualTo(Aquarium.floorAt(f.z)));
      }
      expect(pecks, greaterThan(1));
      expect(maxNod, greaterThan(0.3));
      expect(f.mode, isNot(FishMode.forage));
    });

    test('un pește se poate alătura altuia: înoată în urma lui o vreme, apoi pleacă singur', () {
      final a = Aquarium(width: 1.6, seed: 12);
      final lead = _fish('a', const Point(0.4, 0.5));
      final follower = _fish('b', const Point(1.2, 0.4));
      a
        ..add(lead)
        ..add(follower);
      a.follow(follower, lead); // ca și cum ar fi ales singur
      for (var t = 0; t < 60 * 5; t++) {
        a.step(1 / 60);
      }
      expect(follower.buddy, same(lead));
      expect(follower.pos.distanceTo(lead.pos), lessThan(0.45));
      // O atingere lângă el îl desparte.
      a.tap(follower.pos + const Point(0.1, 0));
      expect(follower.buddy, isNull);
    });
  });
}
