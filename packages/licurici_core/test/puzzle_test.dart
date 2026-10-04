import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = PuzzleGame();

  test('piese: 2 → 4 → 6 → 9; modelul dispare la niveluri mari; tava nu e deja în ordine', () {
    expect(game.axesFor(1).toJson(), {'cols': 2, 'rows': 1, 'model': true, 'rounds': 3});
    expect(game.axesFor(2).cols * game.axesFor(2).rows, 4);
    expect(game.axesFor(4).cols * game.axesFor(4).rows, 6);
    expect(game.axesFor(9).cols * game.axesFor(9).rows, 9);
    expect(game.axesFor(9).model, isFalse);
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds.map((r) => r.image).toSet(), hasLength(l.rounds.length));
        for (final r in l.rounds) {
          expect(r.tray.map((p) => p.index).toSet(), {for (var i = 0; i < r.pieces; i++) i});
          expect([for (final (i, p) in r.tray.indexed) p.index == i].every((x) => x), isFalse);
          for (final p in r.tray) {
            expect(p.index, p.row * r.cols + p.col);
          }
        }
      }
    }
  });

  test('rezultat și înregistrare', () {
    final l = game.generate(4, seed: 1);
    final r = PuzzleResult(l, [
      PuzzleSolve(l.rounds[0], wrongMoves: 0, ms: 20000),
      PuzzleSolve(l.rounds[1], wrongMoves: 4),
    ]);
    expect(r.accuracy, 0.5);
    final rec = SessionRecorder(childId: 'c')..puzzleLevel(r);
    expect(rec.trials.last.attempts, 5);
    expect(rec.trials.first.difficulty, 6);
    expect(catalogEntry('puzzle')!.domain, Domain.pot);
  });
}
