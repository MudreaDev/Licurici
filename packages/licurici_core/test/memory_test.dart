import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = MemoryGame();

  test('nivelul: fiecare imagine apare de exact două ori; reproductibil din seed', () {
    final a = game.generate(5, seed: 42);
    final b = game.generate(5, seed: 42);
    expect(a.cards, b.cards);
    expect(a.cards, hasLength(a.pairs * 2));
    for (final face in a.art) {
      expect(a.cards.where((c) => c == face), hasLength(2));
    }
  });

  test('axele: 2 → 10 perechi, apoi doar animale (mai asemănătoare)', () {
    expect(game.axesFor(1).pairs, 2);
    expect(game.axesFor(13).pairs, 10);
    expect(game.axesFor(40).pairs, 10);
    expect(game.axesFor(1).similar, isFalse);
    expect(game.axesFor(8).similar, isTrue);
    // Grila e mereu landscape: cel puțin la fel de lată cât de înaltă.
    for (var l = 1; l <= 13; l++) {
      final ax = game.axesFor(l);
      final rows = (ax.pairs * 2 / ax.columns).ceil();
      expect(ax.columns, greaterThanOrEqualTo(rows), reason: 'nivelul $l');
    }
  });

  /// Indicii celor două cărți cu aceeași față.
  (int, int) pairOf(MemoryLevel level, String face) {
    final i = level.cards.indexOf(face);
    return (i, level.cards.indexOf(face, i + 1));
  }

  test('joc perfect (fiecare pereche din prima): 3 stele, nivelul crește', () {
    final level = game.generate(3, seed: 1);
    final moves = [
      for (final face in level.art)
        MemoryMove(pairOf(level, face).$1, pairOf(level, face).$2),
    ];
    final r = MemoryResult(level, moves);
    expect(r.complete, isTrue);
    expect(r.movesPerPair, 1);
    expect(r.uselessRepeats, 0);
    expect(r.stars, 3);
    expect(r.suggestedNextLevel(3), 4);
  });

  test('întoarcerile repetate inutile: cartea și perechea ei erau deja văzute', () {
    final level = game.generate(1, seed: 3); // 2 perechi
    final faces = level.art.toList();
    final (a1, a2) = pairOf(level, faces[0]);
    final (b1, b2) = pairOf(level, faces[1]);
    final r = MemoryResult(level, [
      MemoryMove(a1, b1), // vede A și B — nimic inutil, prima dată
      MemoryMove(a2, b2), // vede și perechile: A2 și B2 sunt noi — încă nimic inutil
      MemoryMove(a1, b2), // ambele cărți erau văzute, cu perechile lor: 2 repetări inutile
      MemoryMove(a1, a2),
      MemoryMove(b1, b2),
    ]);
    expect(r.complete, isTrue);
    expect(r.uselessRepeats, 2);
    expect(r.stars, 1);
  });

  test('înregistrare: o încercare pe mutare, confuzia = cele două imagini', () {
    final level = game.generate(1, seed: 3);
    final faces = level.art.toList();
    final (a1, a2) = pairOf(level, faces[0]);
    final (b1, b2) = pairOf(level, faces[1]);
    final rec = SessionRecorder(childId: 'c', clock: () => DateTime(2026, 10, 3));
    rec.memoryLevel(MemoryResult(level, [
      MemoryMove(a1, b1, ms: 900),
      MemoryMove(a1, a2),
      MemoryMove(b1, b2),
    ]));
    final t = rec.trials;
    expect(t, hasLength(3));
    expect(t.first.correct, isFalse);
    expect(t.first.stepId, 'FEX5');
    expect(t.first.targetId, faces[0]);
    expect(t.first.chosenId, faces[1]);
    expect(t.first.latencyMs, 900);
    expect(t[1].correct, isTrue);
    expect(t[1].chosenId, isNull);
  });

  test('în catalog: aria FEX, ruta /perechi', () {
    final e = catalogEntry('perechi')!;
    expect(e.domain, Domain.fex);
    expect(e.route, '/perechi');
  });
}
