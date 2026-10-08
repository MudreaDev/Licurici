import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = TrackGame();

  test('nivelurile cresc: mai mulți pești, mai asemănători, mai repede, mai mult', () {
    final a = game.axesFor(1), b = game.axesFor(12);
    expect(a.fish, 1);
    expect(b.fish, greaterThan(3));
    expect(a.similarity, TrackSimilarity.species);
    expect(b.similarity, TrackSimilarity.identical);
    expect(b.speed, greaterThan(a.speed));
    expect(b.swimMs, greaterThan(a.swimMs));
    expect(a.depth, isFalse);
    expect(b.depth, isTrue);
  });

  test('același seed → același nivel; drumurile rămân în zona de înot', () {
    for (final level in [1, 3, 6, 9, 15]) {
      final x = game.generate(level, seed: 7), y = game.generate(level, seed: 7);
      expect(x.trials.length, x.axes.trials);
      for (var t = 0; t < x.trials.length; t++) {
        final tr = x.trials[t];
        expect(tr.target, inInclusiveRange(0, tr.fish.length - 1));
        expect(tr.fish.length, x.axes.fish);
        expect(tr.target, y.trials[t].target);
        for (final f in tr.fish) {
          expect(f.path.length, x.axes.waypoints + 1);
          expect(trackSpecies, contains(f.species));
          for (final p in f.path) {
            expect(p.x, inInclusiveRange(0, 1));
            expect(p.y, inInclusiveRange(0, 1));
            expect(p.z, inInclusiveRange(0, 1));
          }
        }
      }
    }
  });

  test('asemănarea: modele diferite / același model în culori diferite / identici', () {
    final species = game.generate(4, seed: 1).trials.first.fish;
    expect(species.map((f) => f.species).toSet().length, species.length);
    final color = game.generate(7, seed: 1).trials.first.fish;
    expect(color.map((f) => f.species).toSet().length, 1);
    expect(color.map((f) => f.hue).toSet().length, color.length);
    final same = game.generate(11, seed: 1).trials.first.fish;
    expect(same.map((f) => (f.species, f.hue)).toSet().length, 1);
  });

  test('rezultatul: acuratețe, pierderi, omisiuni, nivelul următor; încercările se înregistrează', () {
    final level = game.generate(6, seed: 3);
    final rs = [
      for (final t in level.trials)
        TrackResponse(t, chosen: t.index < 4 ? t.target : (t.index == 4 ? (t.target + 1) % t.fish.length : null), rtMs: 900),
    ];
    final res = TrackResult(level, rs);
    expect(res.accuracy, closeTo(4 / 6, 1e-9));
    expect(res.lost, 1);
    expect(res.omissions, 1);
    expect(res.suggestedNextLevel(6), 6);
    final rec = SessionRecorder(childId: 'c');
    rec.trackLevel(res);
    expect(rec.trials.length, 6);
    expect(rec.trials.first.stepId, 'ATN2b');
    expect(rec.trials.where((t) => t.correct).length, 4);
  });

  test('jocul e în catalog, pe aria Atenție', () {
    final e = catalog.firstWhere((e) => e.id == 'urmareste-pestele');
    expect(e.kind, GameKind.track);
    expect(e.domain, Domain.atn);
    expect(e.route, '/urmareste-pestele');
  });
}
