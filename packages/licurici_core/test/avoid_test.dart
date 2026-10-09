import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('categoriile se traduc în imagini; necunoscutele se ignoră', () {
    expect(avoidedEmojis(['caini']), containsAll(['🐶', '🐕']));
    expect(avoidedEmojis(['nu-exista']), isEmpty);
    expect(avoidItems.map((i) => i.id).toSet(), hasLength(avoidItems.length));
  });

  test('nicio rundă rămasă nu arată ceva de evitat, în niciun joc cu alegere', () {
    final avoid = avoidedEmojis(['caini', 'pisici', 'insecte', 'fete-furioase', 'baloane']);
    var removed = 0;
    for (final g in allGames) {
      for (var tier = 1; tier <= 10; tier += 3) {
        final lesson = g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(tier)));
        final kept = withoutAvoided(lesson, avoid);
        removed += lesson.rounds.length - kept.rounds.length;
        for (final r in kept.rounds) {
          expect(showsAvoided(r, avoid), isFalse, reason: g.id);
        }
      }
    }
    // Filtrul chiar lucrează: în conținut există rundele cu aceste imagini.
    expect(removed, greaterThan(0));
  });

  test('variantele cu selector de variantă (U+FE0F) sunt recunoscute', () {
    final r = ChoiceRound(prompt: 'Care e păianjenul?', choices: const [Choice(art: '🕷️', correct: true), Choice(art: '🍎')]);
    expect(showsAvoided(r, avoidedEmojis(['insecte'])), isTrue);
    expect(showsAvoided(r, avoidedEmojis(['caini'])), isFalse);
  });
}
