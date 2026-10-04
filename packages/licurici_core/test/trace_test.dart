import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

const aspect = 16 / 9;

/// Urmărește drumul cu degetul exact pe mijloc (pași mici), cu un decalaj opțional.
TraceTracker follow(TracePath path, double width, {double offsetY = 0}) {
  final t = TraceTracker(path, width: width, aspect: aspect);
  final first = path.points.first;
  expect(t.down(first.x, first.y + offsetY), isTrue);
  for (var i = 1; i < path.points.length; i++) {
    final a = path.points[i - 1], b = path.points[i];
    for (var k = 1; k <= 3; k++) {
      t.move(a.x + (b.x - a.x) * k / 3, a.y + (b.y - a.y) * k / 3 + offsetY);
    }
  }
  t.up();
  return t;
}

void main() {
  const game = TraceGame();

  test('același seed → aceleași drumuri; toate punctele în zona de joc', () {
    for (var level = 1; level <= 15; level++) {
      for (var seed = 0; seed < 20; seed++) {
        final a = game.generate(level, seed: seed), b = game.generate(level, seed: seed);
        expect(a.paths.length, a.axes.paths);
        for (final (i, p) in a.paths.indexed) {
          expect(p.points, b.paths[i].points);
          expect(a.axes.shapes, contains(p.shape));
          for (final q in p.points) {
            expect(q.x, inInclusiveRange(0.08, 0.92));
            expect(q.y, inInclusiveRange(0.08, 0.92));
          }
          // Pornește din stânga și ajunge în dreapta (sensul scrisului).
          expect(p.points.first.x, lessThan(0.3));
          expect(p.points.last.x, greaterThan(0.7));
        }
      }
    }
  });

  test('dificultatea: drumul se îngustează, ghidajul dispare, formele se complică', () {
    TraceAxes? prev;
    for (var level = 1; level <= 30; level++) {
      final ax = game.axesFor(level);
      if (prev != null) {
        expect(ax.width, lessThanOrEqualTo(prev.width));
        expect(ax.guide.index, greaterThanOrEqualTo(prev.guide.index));
        expect(ax.paths, greaterThanOrEqualTo(prev.paths));
      }
      expect(ax.width, greaterThanOrEqualTo(0.1 - 1e-9));
      prev = ax;
    }
    expect(game.axesFor(1).shapes, [TraceShape.line]);
    expect(game.axesFor(12).shapes, contains(TraceShape.loop));
  });

  test('urmărit pe mijloc: ajunge la capăt, fără ieșiri, abatere ~0 — pe toate formele', () {
    for (final shape in TraceShape.values) {
      final path = TracePath(
        index: 0,
        shape: shape,
        points: TraceGame.shapePoints(shape, Random(3), level: 8),
        trip: traceTrips.first,
      );
      final t = follow(path, 0.12);
      expect(t.done, isTrue, reason: shape.name);
      expect(t.exits, 0, reason: shape.name);
      expect(t.meanDeviation, lessThan(0.05), reason: shape.name);
      expect(t.result().clean, isTrue);
    }
  });

  test('puțin pe lângă mijloc e încă pe drum, dar abaterea crește', () {
    final path = game.generate(1, seed: 1).paths.first;
    final t = follow(path, 0.24, offsetY: 0.06);
    expect(t.done, isTrue);
    expect(t.exits, 0);
    expect(t.meanDeviation, closeTo(0.25, 0.05));
  });

  test('ieșirea de pe drum se numără o dată, iar personajul așteaptă', () {
    final path = game.generate(1, seed: 2).paths.first; // linie orizontală
    final t = TraceTracker(path, width: 0.2, aspect: aspect);
    final p = path.points;
    t.down(p[0].x, p[0].y);
    t.move(p[10].x, p[10].y);
    final before = t.progress;
    // Degetul o ia mult în sus: nu înaintează.
    t.move(p[20].x, p[20].y - 0.4);
    t.move(p[30].x, p[30].y - 0.4);
    expect(t.progress, before);
    expect(t.exits, 1);
    // Revine pe drum lângă personaj și continuă.
    t.move(p[12].x, p[12].y);
    expect(t.progress, greaterThan(before));
    expect(t.exits, 1);
  });

  test('nu se poate sări peste drum: atingerea departe de personaj nu-l prinde', () {
    final path = game.generate(1, seed: 4).paths.first;
    final t = TraceTracker(path, width: 0.2, aspect: aspect);
    expect(t.down(path.points.last.x, path.points.last.y), isFalse);
    t.move(path.points.last.x, path.points.last.y);
    expect(t.progress, 0);
    // Nici trăgând direct spre capăt din start (fereastra de căutare e scurtă).
    t.down(path.points.first.x, path.points.first.y);
    t.move(path.points.last.x, path.points.last.y);
    expect(t.done, isFalse);
  });

  test('stele și nivelul următor după drumurile curate', () {
    final level = game.generate(3, seed: 5);
    TraceResult res(int clean) => TraceResult(level, [
          for (final (i, p) in level.paths.indexed)
            TraceRun(path: p, completed: true, exits: i < clean ? 0 : 2, meanDeviation: 0.2),
        ]);
    expect(res(level.paths.length).stars, 3);
    expect(res(level.paths.length).suggestedNextLevel(3), 4);
    expect(res(0).stars, 1);
    expect(res(0).suggestedNextLevel(3), 2);
    expect(res(0).suggestedNextLevel(1), 1);
  });

  test('înregistrarea: o încercare pe drum, cu ieșirile ca încercări', () {
    final level = game.generate(2, seed: 6);
    final rec = SessionRecorder(childId: 'c');
    rec.traceLevel(TraceResult(level, [
      TraceRun(path: level.paths[0], completed: true, exits: 0, meanDeviation: 0.1, ms: 4000),
      TraceRun(path: level.paths[1], completed: true, exits: 2, meanDeviation: 0.4),
    ]));
    final trials = rec.trials;
    expect(trials, hasLength(2));
    expect(trials.first.correct, isTrue);
    expect(trials.last.attempts, 3);
    expect(trials.first.stepId, 'MOT1');
    expect(catalogEntry('traseaza')!.domain, Domain.mot);
    expect(catalogEntry('traseaza')!.route, '/traseaza');
  });
}
