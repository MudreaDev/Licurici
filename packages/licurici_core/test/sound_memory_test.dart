import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SoundMemoryGame();

  test('fiecare sursă are exact cartea ei cu sunet; la fermă doar animale de fermă', () {
    for (var level = 1; level <= 8; level++) {
      final axes = game.axesFor(level);
      for (var seed = 0; seed < 30; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.cards, hasLength(axes.pairs * 2));
        for (final c in l.cards) {
          expect(l.cards.where((o) => o.matches(c)), hasLength(1));
        }
        if (axes.farmOnly) expect(l.cards.every((c) => c.source.farm), isTrue);
      }
    }
    expect(game.axesFor(3).sourcesUp, isTrue);
    expect(game.axesFor(4).sourcesUp, isFalse);
  });

  test('imaginile evitate nu apar', () {
    final l = game.generate(7, seed: 1, avoid: {'🐶', '🐱'});
    expect(l.cards.any((c) => c.source.emoji == '🐶' || c.source.emoji == '🐱'), isFalse);
  });

  test('rezultat: pereche corectă, stele și încercările salvate', () {
    final l = game.generate(2, seed: 4);
    final cards = l.cards;
    final moves = <SoundMove>[];
    // O greșeală (două sunete sau sunet + alt animal), apoi toate perechile din prima.
    final s0 = cards.indexWhere((c) => c.isSound);
    final wrong = cards.indexWhere((c) => !c.matches(cards[s0]) && c != cards[s0]);
    moves.add(SoundMove(s0, wrong, ms: 900));
    for (var i = 0; i < cards.length; i++) {
      if (!cards[i].isSound) continue;
      moves.add(SoundMove(i, cards.indexWhere((c) => c.matches(cards[i])), ms: 800));
    }
    final r = SoundMemoryResult(l, moves);
    expect(r.complete, isTrue);
    expect(r.matches, l.pairs);
    expect(r.stars, 2); // 4 mutări / 3 perechi, cu animalele la vedere
    final rec = SessionRecorder(childId: 'c')..soundMemoryLevel(r);
    expect(rec.trials.first.correct, isFalse);
    expect(rec.trials.first.targetId, startsWith('sunet:'));
    expect(rec.trials.first.stepId, 'COM1');
    expect(rec.trials.skip(1).every((t) => t.correct), isTrue);
  });
}
