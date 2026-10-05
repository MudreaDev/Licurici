import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SpotDiffGame();

  test('exact k diferențe, iar în rest scenele sunt identice', () {
    for (var level = 1; level <= 14; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        for (final s in l.scenes) {
          expect(s.differences, hasLength(game.differencesFor(level)));
          final cells = {...s.left.keys, ...s.right.keys};
          for (final c in cells) {
            expect(c, lessThan(s.cols * s.rows));
            final same = s.left[c] == s.right[c];
            expect(same, !s.differences.containsKey(c), reason: 'celula $c');
          }
          for (final MapEntry(key: c, value: k) in s.differences.entries) {
            switch (k) {
              case DiffKind.missing:
                expect(s.right.containsKey(c), isFalse);
              case DiffKind.extra:
                expect(s.left.containsKey(c), isFalse);
              case DiffKind.replaced:
                expect(s.left.containsKey(c) && s.right.containsKey(c), isTrue);
            }
          }
          // Fără obiecte duble în aceeași scenă (ar încurca).
          expect(s.right.values.toSet(), hasLength(s.right.length));
        }
      }
    }
  });

  test('înregistrarea', () {
    final l = game.generate(5, seed: 1);
    final rec = SessionRecorder(childId: 'c')
      ..diffLevel(DiffResult(l, [DiffSolve(l.scenes[0], wrongTaps: 0, ms: 9000), DiffSolve(l.scenes[1], wrongTaps: 4)]));
    expect(rec.trials.first.correct, isTrue);
    expect(rec.trials.last.offTargetTaps, 4);
    expect(catalogEntry('diferente')!.domain, Domain.pot);
  });
}
