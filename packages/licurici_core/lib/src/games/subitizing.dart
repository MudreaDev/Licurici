/// Câte sunt? (PAC-N1, subitizarea): obiectele se arată doar o clipă, prea scurt ca să fie
/// numărate unul câte unul; copilul alege câte au fost. Recunoașterea dintr-o privire a
/// cantităților mici (1–4, „subitizare”) e unul dintre cei mai buni predictori ai înțelegerii
/// numerelor; peste 4–5, copiii trec la estimare.
///
/// Axe: cât de multe (1–3 → 1–5 → 3–7 → 4–9) și cât timp se văd (2 s → 0,5 s). Fiecare
/// încercare păstrează cantitatea (`stimulusId` = `n-<câte>`), ca specialistul să vadă unde
/// se oprește subitizarea copilului.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';
import 'content.dart';

class CateSuntGame extends ChoiceGame {
  const CateSuntGame()
      : super(
          id: 'cate-sunt',
          name: 'Câte sunt?',
          emoji: '🎲',
          description: 'Privește o clipă și spune câte au fost',
          subject: Subject.matematica,
          gradeCodes: 'G1234',
        );

  /// Cea mai mică și cea mai mare cantitate la [tier].
  static (int, int) rangeFor(int tier) => switch (tier) {
        1 || 2 => (1, 3),
        3 || 4 => (1, 5),
        5 || 6 => (3, 7),
        _ => (4, 9),
      };

  /// Cât se văd obiectele (milisecunde) la [tier].
  static int showMsFor(int tier) => max(500, 2200 - 250 * tier);

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final (lo, hi) = rangeFor(tier);
    final ms = showMsFor(tier);
    var last = -1;
    final rounds = <ChoiceRound>[];
    for (var i = 0; i < 8; i++) {
      var n = ctx.intBetween(lo, hi);
      // Nu de două ori la rând aceeași cantitate.
      if (n == last) n = n == hi ? lo : n + 1;
      last = n;
      final item = ctx.pick(mathItems);
      rounds.add(ChoiceRound(
        prompt: 'Câte au fost?',
        speak: ['Privește repede!'],
        visuals: [ObjectsVisual([ObjectGroup(item, n)])],
        hint: 'Mai privește o dată.',
        showMs: ms,
        stimulusId: 'n-$n',
        choices: [for (final k in numberChoices(ctx, n, 1, max(hi, 5))) Choice(label: '$k', correct: k == n)],
      ));
    }
    return Lesson(title: name, instruction: 'Privește o clipă. Câte au fost?', rounds: rounds);
  }
}
