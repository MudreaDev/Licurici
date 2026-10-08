import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('fiecare semn: trăsături dese, cu pas egal, fără salturi', () {
    for (final g in [...digitGlyphs, ...letterGlyphs]) {
      expect(g.strokes, isNotEmpty, reason: g.char);
      for (final s in g.strokes) {
        expect(s.length, greaterThan(5), reason: g.char);
        for (var i = 1; i < s.length; i++) {
          expect(s[i - 1].distanceTo(s[i]), lessThan(0.02), reason: '${g.char}: salt la $i');
        }
      }
      final b = g.bounds;
      expect(b.bottom - b.top, greaterThan(0.9), reason: g.char);
    }
  });

  test('ordinea scrisului: liniile verticale de sus în jos, „O” pornește de sus spre stânga', () {
    final i = glyphFor('I')!.strokes.single;
    expect(i.first.y, lessThan(i.last.y));
    final o = glyphFor('O')!.strokes.single;
    expect(o.first.y, closeTo(0, 0.01));
    expect(o[5].x, lessThan(o.first.x)); // spre stânga
    final t = glyphFor('T')!.strokes;
    expect(t.first.first.y, closeTo(0, 0.01)); // întâi bara de sus
    expect(t.first.first.x, lessThan(t.first.last.x)); // de la stânga la dreapta
  });

  test('urmărirea unei litere întregi, trăsătură cu trăsătură, pe mijlocul drumului', () {
    final paths = glyphFor('A')!.fit(1.6);
    final runs = <TraceRun>[];
    for (final p in paths) {
      final tr = TraceTracker(p, width: 0.12, aspect: 1.6);
      expect(tr.down(p.points.first.x, p.points.first.y), isTrue);
      for (final q in p.points) {
        tr.move(q.x, q.y);
      }
      expect(tr.done, isTrue);
      runs.add(tr.result());
    }
    final run = WritingRun(glyphFor('A')!, runs);
    expect(run.clean, isTrue);
    // În zona de joc, semnul e în ecran.
    for (final p in paths) {
      for (final q in p.points) {
        expect(q.x, inInclusiveRange(0, 1));
        expect(q.y, inInclusiveRange(0, 1));
      }
    }
  });

  test('nivelurile: seturi noi pe rând, drum tot mai îngust, ajutorul dispare; fără repetări', () {
    for (final game in writingGames) {
      final a = game.axesFor(1), b = game.axesFor(12);
      expect(b.pool.length, greaterThan(a.pool.length));
      expect(b.width, lessThan(a.width));
      expect(a.guide, TraceGuide.dots);
      expect(b.guide, TraceGuide.none);
      for (final level in [1, 2, 3, 5, 8, 12]) {
        final l = game.generate(level, seed: level);
        expect(l.glyphs.length, l.axes.glyphs);
        expect(l.glyphs.map((g) => g.char).toSet().length, l.glyphs.length);
        expect(l.glyphs.every((g) => l.axes.pool.contains(g.char)), isTrue);
        final again = game.generate(level, seed: level);
        expect(again.glyphs.map((g) => g.char), l.glyphs.map((g) => g.char));
      }
    }
    expect(writeDigits.generate(1, seed: 1).glyphs.every((g) => '1074'.contains(g.char)), isTrue);
  });

  test('rezultatul se înregistrează pe treapta jocului; jocurile sunt în catalog', () {
    final level = writeLetters.generate(1, seed: 2);
    final runs = [
      for (final (i, g) in level.glyphs.indexed)
        WritingRun(g, [
          for (final p in g.fit(1.5)) TraceRun(path: p, completed: true, exits: i == 0 ? 2 : 0, meanDeviation: 0.1),
        ]),
    ];
    final res = WritingResult(level, runs);
    expect(res.accuracy, closeTo((runs.length - 1) / runs.length, 1e-9));
    final rec = SessionRecorder(childId: 'c')..writingLevel(res);
    expect(rec.trials.length, runs.length);
    expect(rec.trials.first.stepId, 'PAC-L4');
    expect(rec.trials.first.offTargetTaps, 2);
    expect(rec.trials.first.promptLevel, PromptLevel.p3);
    final cifre = catalog.firstWhere((e) => e.id == 'scriem-cifrele');
    expect(cifre.route, '/scrie/scriem-cifrele');
    expect(cifre.domain, Domain.pac);
  });
}
