import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('labirint perfect: toate celulele legate, pereți simetrici, exact cols*rows−1 treceri', () {
    for (var seed = 0; seed < 50; seed++) {
      final m = Maze.generate(6, 4, Random(seed));
      var passages = 0;
      for (var i = 0; i < m.walls.length; i++) {
        for (final d in MazeDir.values) {
          final n = m.step(i, d);
          if (n != null) {
            passages++;
            expect(m.step(n, d.opposite), i);
          }
        }
        expect(m.path(0, i), isNotEmpty);
      }
      expect(passages ~/ 2, m.cols * m.rows - 1);
      // Marginea exterioară e închisă.
      for (var c = 0; c < m.cols; c++) {
        expect(m.open(m.index(c, 0), MazeDir.up), isFalse);
        expect(m.open(m.index(c, m.rows - 1), MazeDir.down), isFalse);
      }
    }
  });

  test('mersul: doar pe culoare, fără teleportare; drumul cel mai scurt = eficiență 1', () {
    final m = Maze.generate(5, 3, Random(7));
    final w = MazeWalker(m);
    final best = m.path(0, w.goal);
    for (final i in best.skip(1)) {
      expect(w.toward(i), isTrue);
    }
    expect(w.done, isTrue);
    expect(w.efficiency, 1);
    expect(w.bumps, 0);
    final w2 = MazeWalker(m);
    expect(w2.toward(w2.goal), m.path(0, w2.goal).length <= 4);
  });

  test('lovirea unui perete se numără', () {
    final m = Maze.generate(4, 3, Random(3));
    final w = MazeWalker(m);
    // O vecină a startului închisă de perete.
    final blocked = [
      for (final d in [MazeDir.right, MazeDir.down])
        if (!m.open(0, d)) m.index(d.dx, d.dy),
    ];
    if (blocked.isNotEmpty) {
      final route = m.path(0, blocked.first);
      if (route.length > 4) {
        expect(w.toward(blocked.first), isFalse);
        expect(w.bumps, 1);
      }
    }
  });

  test('nivelurile cresc; înregistrarea', () {
    const g = MazeGame();
    expect(g.sizeFor(1), (3, 2));
    expect(g.sizeFor(30), (8, 5));
    final l = g.generate(3, seed: 1);
    expect(l.mazes, hasLength(3));
    final rec = SessionRecorder(childId: 'c')
      ..mazeLevel(MazeResult(l, [
        MazeRun(l.mazes[0], efficiency: 1, bumps: 0, planMs: 900),
        MazeRun(l.mazes[1], efficiency: 0.5, bumps: 3),
      ]));
    expect(rec.trials.first.correct, isTrue);
    expect(rec.trials.last.offTargetTaps, 3);
    expect(catalogEntry('labirint')!.domain, Domain.fex);
  });
}
