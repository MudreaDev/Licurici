/// Jocurile de raționament (mecanica `choice`), aria Cogniție.
library;

import '../game.dart';
import '../grades.dart';

/// Imaginile din care se fac șirurile (toate au ilustrații pictate sau OpenMoji clare).
const _patternArt = [
  '🍎',
  '🍌',
  '🍓',
  '🐶',
  '🐱',
  '🐇',
  '⭐',
  '🌸',
  '🎈',
  '⚽',
  '🧸',
  '🍒',
  '🦋',
  '🐢',
];

/// Continuă șirul (COG5, catalog #28): modele AB → ABB/AAB → ABC → AABB. Copilul alege ce
/// urmează. Ușor la început (două variante, model AB), apoi tipuri de model mai lungi.
class SirulGame extends ChoiceGame {
  const SirulGame()
    : super(
        id: 'continua-sirul',
        name: 'Continuă șirul',
        emoji: '🧩',
        description: 'Ce urmează în șir?',
        subject: Subject.forme,
        gradeCodes: 'G12',
      );

  /// Modelele, de la simplu la complex (literele = poziții distincte).
  static const units = ['AB', 'ABB', 'AAB', 'ABC', 'AABB', 'ABCD'];

  @override
  Lesson generate(GameContext ctx) {
    final rounds = ctx.difficulty.roundCount;
    // Câte tipuri de model sunt deschise la acest nivel (tier 1 → AB, AAB…; tier mare → toate).
    final open = (1 + ctx.difficulty.tier).clamp(1, units.length);
    return Lesson(
      title: name,
      instruction: 'Alege ce urmează în șir.',
      rounds: [
        for (var i = 0; i < rounds; i++)
          // Primele runde sunt mereu cele mai simple (încălzire).
          _round(ctx, units[i < 2 ? 0 : ctx.random.nextInt(open)]),
      ],
    );
  }

  ChoiceRound _round(GameContext ctx, String unit) {
    final letters = unit.split('').toSet().toList();
    final art = ctx.sample(_patternArt, letters.length);
    final map = {for (final (i, l) in letters.indexed) l: art[i]};
    // Modelul se vede de două ori întreg, apoi o parte din a treia repetare.
    final shownLength = unit.length * 2 + ctx.random.nextInt(unit.length);
    final seq = [
      for (var i = 0; i <= shownLength; i++) map[unit[i % unit.length]]!,
    ];
    final answer = seq.removeLast();
    final options = <String>{answer, ...map.values};
    for (final e in ctx.sample(_patternArt, _patternArt.length)) {
      if (options.length >= ctx.difficulty.optionCount) break;
      options.add(e);
    }
    final choices =
        (options.take(ctx.difficulty.optionCount).toList()..shuffle(ctx.random))
            .map((e) => Choice(art: e, correct: e == answer, id: e))
            .toList();
    if (!choices.any((c) => c.correct)) {
      choices[ctx.random.nextInt(choices.length)] = Choice(
        art: answer,
        correct: true,
        id: answer,
      );
    }
    return ChoiceRound(
      prompt: 'Ce urmează în șir?',
      visuals: [PatternVisual(seq, answer: answer)],
      hint: 'Privește cum se repetă.',
      choices: choices,
    );
  }
}
