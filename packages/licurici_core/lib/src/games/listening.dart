/// Ce ai auzit? (COM4, fratele lui „Primul sunet”; discriminarea auditivă pe **perechi minimale**):
/// Licurici spune un cuvânt; copilul alege poza. La început celelalte poze sunt cuvinte care
/// sună cu totul altfel; apoi apare perechea care diferă **doar prin primul sunet**
/// (câine/pâine, mere/pere, casă/masă, sac/lac, zar/dar) — paradigma clasică din logopedie.
/// Încercarea păstrează perechea (`stimulusId` = `pereche-câine-pâine`), ca specialistul să
/// vadă ce contraste confundă copilul (matricea de confuzii).
library;

import '../game.dart';
import '../grades.dart';

/// Un cuvânt rostit și poza lui.
class HeardWord {
  const HeardWord(this.word, this.emoji);

  final String word;
  final String emoji;
}

/// Perechile minimale (diferă doar prin primul sunet).
const minimalPairs = [
  (HeardWord('câine', '🐶'), HeardWord('pâine', '🍞')),
  (HeardWord('mere', '🍎'), HeardWord('pere', '🍐')),
  (HeardWord('casă', '🏠'), HeardWord('masă', '🍽️')),
  (HeardWord('sac', '🎒'), HeardWord('lac', '🏞️')),
  (HeardWord('zar', '🎲'), HeardWord('dar', '🎁')),
];

/// Cuvinte care nu seamănă cu cele din perechi (distractorii de la început).
const _farWords = [
  HeardWord('urs', '🐻'),
  HeardWord('foc', '🔥'),
  HeardWord('pom', '🌳'),
  HeardWord('bec', '💡'),
  HeardWord('tren', '🚂'),
  HeardWord('vacă', '🐄'),
  HeardWord('lalea', '🌷'),
  HeardWord('balon', '🎈'),
];

class CeAiAuzitGame extends ChoiceGame {
  const CeAiAuzitGame()
      : super(
          id: 'ce-ai-auzit',
          name: 'Ce ai auzit?',
          emoji: '👂',
          description: 'Ascultă cuvântul și alege poza',
          subject: Subject.romana,
          gradeCodes: 'G1234',
        );

  static const listen = 'Ascultă bine:';

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final rounds = <ChoiceRound>[];
    for (var i = 0; i < 8; i++) {
      final (a, b) = ctx.pick(minimalPairs);
      final flip = ctx.random.nextBool();
      final target = flip ? b : a, twin = flip ? a : b;
      final far = ctx.sample(_farWords, 2);
      final options = switch (tier) {
        1 || 2 => [target, far[0]], // sună cu totul altfel
        3 || 4 => [target, twin], // perechea minimală, doar două poze
        _ => [target, twin, ...far], // perechea printre alte poze
      }..shuffle(ctx.random);
      rounds.add(ChoiceRound(
        prompt: 'Ce ai auzit?',
        speak: [listen, target.word],
        hint: 'Mai ascultă o dată primul sunet.',
        fixedChoices: true,
        stimulusId: 'pereche-${a.word}-${b.word}',
        choices: [
          for (final o in options) Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == target),
        ],
      ));
    }
    return Lesson(title: name, instruction: 'Ascultă cuvântul și atinge poza.', rounds: rounds);
  }
}
