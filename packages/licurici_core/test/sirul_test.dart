import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SirulGame();

  test(
    'fiecare rundă: șirul respectă modelul, răspunsul e elementul următor',
    () {
      for (var tier = 1; tier <= 6; tier++) {
        for (var seed = 0; seed < 30; seed++) {
          final lesson = game.generate(
            GameContext(
              difficulty: Difficulty(tier),
              grade: Grade.clasa1,
              random: Random(seed),
            ),
          );
          for (final r in lesson.rounds) {
            final v = r.visuals.single as PatternVisual;
            final full = [...v.items, v.answer];
            // Există o perioadă p (lungimea modelului) care explică tot șirul.
            final period = [for (var p = 2; p <= 4; p++) p].firstWhere(
              (p) => [
                for (var i = p; i < full.length; i++) full[i] == full[i - p],
              ].every((x) => x),
              orElse: () => -1,
            );
            expect(period, greaterThan(0), reason: '$full');
            expect(v.items.length, greaterThanOrEqualTo(4));
            expect(r.choices.where((c) => c.correct).single.art, v.answer);
            expect(
              r.choices.map((c) => c.art).toSet(),
              hasLength(r.choices.length),
            );
          }
        }
      }
    },
  );

  test('primele runde sunt modelul cel mai simplu (AB)', () {
    final lesson = game.generate(
      GameContext(
        difficulty: const Difficulty(5),
        grade: Grade.clasa1,
        random: Random(1),
      ),
    );
    final first = lesson.rounds.first.visuals.single as PatternVisual;
    expect({...first.items, first.answer}, hasLength(2));
  });

  test('în catalog: aria COG', () {
    expect(catalogEntry('continua-sirul')!.domain, Domain.cog);
  });
}
