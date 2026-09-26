/// Jocurile de limba română (mecanica `choice`).
library;

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

/// Alfabetul — trei tipuri de întrebări, alternate (port din `alfabetul.js`):
/// obiect → literă de început, literă → obiect, literă MARE → literă mică.
class AlfabetulGame extends ChoiceGame {
  const AlfabetulGame()
      : super(
          id: 'alfabetul',
          name: 'Alfabetul',
          emoji: '🔤',
          description: 'Învață literele',
          subject: Subject.romana,
          gradeCodes: 'G12',
        );

  static final List<String> _letters = content.alphabet.map((a) => a.letter).toSet().toList();

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege litera potrivită.',
        rounds: [for (var i = 0; i < 9; i++) _round(ctx, i % 3)],
      );

  ChoiceRound _round(GameContext ctx, int kind) {
    final entry = ctx.pick(content.alphabet);
    switch (kind) {
      case 0: // obiect → literă
        final options = [entry.letter, ...ctx.sample(_letters.where((l) => l != entry.letter).toList(), 4)]
          ..shuffle(ctx.random);
        return ChoiceRound(
          prompt: 'Cu ce literă începe?',
          speak: ['Cu ce literă începe ${entry.word}?'],
          visuals: [EmojiVisual(entry.emoji), TextVisual(entry.word)],
          hint: '„${entry.word}” începe cu litera ${entry.letter}.',
          choices: [for (final l in options) Choice(label: l, correct: l == entry.letter)],
        );
      case 1: // literă → obiect
        final others = ctx.sample(content.alphabet.where((a) => a.letter != entry.letter).toList(), 4);
        final options = [entry, ...others]..shuffle(ctx.random);
        return ChoiceRound(
          prompt: 'Ce începe cu litera:',
          speak: ['Alege obiectul care începe cu litera ${entry.letter}.'],
          visuals: [TextVisual(entry.letter)],
          hint: '„${entry.word}” începe cu ${entry.letter}.',
          choices: [
            for (final o in options) Choice(art: o.emoji, speak: o.word, correct: o == entry),
          ],
        );
      default: // literă MARE → literă mică
        final lower = entry.letter.toLowerCase();
        final options = [
          lower,
          ...ctx.sample(_letters.where((l) => l != entry.letter).map((l) => l.toLowerCase()).toList(), 4),
        ]..shuffle(ctx.random);
        return ChoiceRound(
          prompt: 'Găsește litera mică:',
          speak: ['Găsește aceeași literă, dar mică.'],
          visuals: [TextVisual(entry.letter)],
          hint: 'Litera mică pentru ${entry.letter} este $lower.',
          choices: [for (final l in options) Choice(label: l, correct: l == lower)],
        );
    }
  }
}

/// Opuse — cuvântul cu sens opus (port din `opuse.js`).
class OpuseGame extends ChoiceGame {
  const OpuseGame()
      : super(
          id: 'opuse',
          name: 'Opuse',
          emoji: '↔️',
          description: 'Găsește opusul',
          subject: Subject.romana,
          gradeCodes: 'G1234',
        );

  static final List<content.Word> _all = [
    for (final p in content.opposites) ...[p.a, p.b],
  ];

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege cuvântul cu sens opus.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final pair = ctx.pick(content.opposites);
    final showA = ctx.random.nextBool();
    final shown = showA ? pair.a : pair.b;
    final answer = showA ? pair.b : pair.a;
    // Distractorii nu au aceeași ilustrație cu cuvântul arătat (ex. ☀️ „cald” și „zi”).
    final pool = _all.where((w) => w != shown && w != answer && w.emoji != answer.emoji).toList();
    final options = [answer, ...ctx.sample(pool, 4)]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: 'Care e opusul?',
      speak: ['Care e opusul?', shown.word],
      visuals: [EmojiVisual(shown.emoji), TextVisual(shown.word)],
      hint: 'Opusul lui „${shown.word}” este „${answer.word}”.',
      choices: [
        for (final o in options) Choice(label: o.word, art: o.emoji, correct: o == answer),
      ],
    );
  }
}
