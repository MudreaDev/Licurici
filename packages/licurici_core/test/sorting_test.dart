import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SortGame();

  test('nivelul: grupe diferite, câte perechi pe grupă, reproductibil', () {
    final a = game.generate(6, seed: 9);
    expect(a.items.map((i) => i.emoji), game.generate(6, seed: 9).items.map((i) => i.emoji));
    expect(a.bins.map((b) => b.id).toSet(), hasLength(a.axes.bins));
    expect(a.items, hasLength(a.axes.items));
    for (final b in a.bins) {
      expect(a.items.where((i) => i.binId == b.id), hasLength(a.axes.perBin));
      for (final i in a.items.where((i) => i.binId == b.id)) {
        expect(b.items, contains(i.emoji));
      }
    }
    // Fiecare lucru apare o singură dată.
    expect(a.items.map((i) => i.emoji).toSet(), hasLength(a.items.length));
    expect([for (final (k, i) in a.items.indexed) i.index == k], everyElement(isTrue));
  });

  test('axele: 2 → 4 grupe, 2 → 4 lucruri pe grupă', () {
    expect(game.axesFor(1).items, 4);
    expect(game.axesFor(5).bins, 3);
    expect(game.axesFor(12).items, 16);
  });

  test('o categorie apare într-o singură grupă (nicio ambiguitate)', () {
    final all = [for (final c in sortCategories) ...c.items];
    expect(all.toSet(), hasLength(all.length));
  });

  test('scor și nivelul următor; înregistrarea cu confuzia între grupe', () {
    final level = game.generate(1, seed: 4);
    final other = level.bins.firstWhere((b) => b.id != level.items.first.binId).id;
    final placements = [
      SortPlacement(level.items.first, wrongDrops: 1, firstWrongBin: other, ms: 1500),
      for (final i in level.items.skip(1)) SortPlacement(i, ms: 800),
    ];
    final r = SortResult(level, placements);
    expect(r.accuracy, 0.75);
    expect(r.stars, 2);
    expect(r.suggestedNextLevel(1), 1);
    expect(SortResult(level, [for (final i in level.items) SortPlacement(i)]).suggestedNextLevel(1), 2);

    final rec = SessionRecorder(childId: 'c', clock: () => DateTime(2026, 10, 3));
    rec.sortLevel(r);
    final t = rec.trials;
    expect(t, hasLength(level.items.length));
    expect(t.first.stepId, 'COG3');
    expect(t.first.correct, isFalse);
    expect(t.first.attempts, 2);
    expect(t.first.targetId, level.items.first.binId);
    expect(t.first.chosenId, other);
    expect(t.first.promptLevel, PromptLevel.p2);
    expect(t[1].independent, isTrue);
  });

  test('în catalog: aria COG, ruta /sortam', () {
    final e = catalogEntry('sortam')!;
    expect(e.domain, Domain.cog);
    expect(e.route, '/sortam');
  });
}
