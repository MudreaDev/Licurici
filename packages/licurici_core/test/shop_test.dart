import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = ShopGame();

  test('tot ce e pe listă e pe raft, o singură dată; lista și raftul cresc', () {
    for (var level = 1; level <= 14; level++) {
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        for (final r in l.rounds) {
          expect(r.list, hasLength(game.listFor(level)));
          expect(r.shelf, hasLength(game.shelfFor(level)));
          expect(r.shelf.toSet(), hasLength(r.shelf.length));
          expect(r.shelf.toSet().containsAll(r.list), isTrue);
        }
      }
    }
    expect(game.listFor(1), 1);
    expect(game.listFor(40), 5);
  });

  test('înregistrarea', () {
    final l = game.generate(3, seed: 1);
    final rec = SessionRecorder(childId: 'c')
      ..shopLevel(ShopResult(l, [ShopTrip(l.rounds[0], extra: 0, ms: 5000), ShopTrip(l.rounds[1], extra: 2)]));
    expect(rec.trials.last.offTargetTaps, 2);
    expect(rec.trials.first.correct, isTrue);
    expect(catalogEntry('la-magazin')!.domain, Domain.aut);
  });
}
