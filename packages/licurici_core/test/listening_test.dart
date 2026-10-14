import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('Ce ai auzit?: întâi cuvinte diferite, apoi perechea minimală; se rostește ținta', () {
    for (var tier = 1; tier <= 8; tier++) {
      for (var seed = 0; seed < 20; seed++) {
        final lesson = const CeAiAuzitGame().build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed)));
        for (final r in lesson.rounds) {
          final target = r.choices.singleWhere((c) => c.correct);
          expect(r.speak, [CeAiAuzitGame.listen, target.id]);
          final pair = minimalPairs.firstWhere((p) => p.$1.word == target.id || p.$2.word == target.id);
          final twin = pair.$1.word == target.id ? pair.$2.word : pair.$1.word;
          final ids = {for (final c in r.choices) c.id};
          if (tier <= 2) {
            expect(ids, isNot(contains(twin)), reason: 'la început, fără perechea minimală');
            expect(r.choices, hasLength(2));
          } else {
            expect(ids, contains(twin));
          }
          if (tier >= 5) expect(r.choices, hasLength(4));
          expect(r.stimulusId, 'pereche-${pair.$1.word}-${pair.$2.word}');
        }
      }
    }
    expect(stepsForGame('ce-ai-auzit').single.id, 'COM4');
  });
}
