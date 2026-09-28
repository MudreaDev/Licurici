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

/// Scriem corect — ortograme care se aud la fel (sau / s-au, la / l-a …). Mecanică inspirată de
/// jocurile de ortografie din seria „Să ne jucăm pe calculator” (Aidem Media), cu conținut propriu.
class OrtografieGame extends ChoiceGame {
  const OrtografieGame()
    : super(
        id: 'ortografie',
        name: 'Scriem corect',
        emoji: '✍️',
        description: 'sau sau s-au?',
        subject: Subject.romana,
        gradeCodes: '234',
      );

  @override
  Lesson generate(GameContext ctx) => Lesson(
    title: name,
    instruction: 'Alege cum se scrie cuvântul lipsă.',
    rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
  );

  ChoiceRound _round(GameContext ctx) {
    final o = ctx.pick(content.ortograme);
    final useA = ctx.random.nextBool();
    final answer = useA ? o.a : o.b;
    final sentence = ctx.pick(useA ? o.sentencesA : o.sentencesB);
    final options = [o.a, o.b]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: 'Cum se scrie?',
      // Formele se aud la fel, deci propoziția rostită completă nu dă răspunsul.
      speak: ['Cum se scrie?', sentence.replaceAll('___', answer)],
      visuals: [SceneVisual(sentence)],
      fixedChoices: true,
      hint: useA ? o.ruleA : o.ruleB,
      choices: [for (final w in options) Choice(label: w, correct: w == answer)],
    );
  }
}

/// Povești — ascultare și înțelegere pe povești românești din domeniul public (Creangă).
/// Ideea vine din poveștile interactive ale seriei Aidem Media („Punguța cu 2 bani”, „Ursul
/// păcălit de vulpe”); textele și întrebările sunt ale noastre.
class PovestiGame extends ChoiceGame {
  const PovestiGame()
    : super(
        id: 'povesti',
        name: 'Povești',
        emoji: '📖',
        description: 'Ascultă și răspunde',
        subject: Subject.romana,
        gradeCodes: 'G1234',
      );

  @override
  Lesson generate(GameContext ctx) {
    final story = ctx.pick(content.stories);
    final steps = story.steps;
    // Câte întrebări cere tier-ul; finalul poveștii e mereu inclus. Pașii săriți nu se pierd:
    // povestirea lor se spune înaintea următoarei întrebări.
    final n = ctx.difficulty.roundCount.clamp(1, steps.length);
    final asked = {
      ...ctx.sample([for (var i = 0; i < steps.length - 1; i++) i], n - 1),
      steps.length - 1,
    }.toList()..sort();
    final rounds = <ChoiceRound>[];
    var from = 0;
    for (final i in asked) {
      rounds.add(_round(ctx, [for (var j = from; j <= i; j++) steps[j].narration], steps[i]));
      from = i + 1;
    }
    return Lesson(
      title: '${story.title} — ${story.author}',
      instruction: 'Ascultă povestea și răspunde la întrebări.',
      rounds: rounds,
    );
  }

  ChoiceRound _round(GameContext ctx, List<String> narration, content.StoryStep step) {
    final options = [step.answer, ...ctx.sample(step.wrong, 4)]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: step.question,
      speak: [...narration, step.question],
      // Pe ecran doar pasul curent (textul rămâne scurt pe telefon); vocea le spune pe toate.
      visuals: [SceneVisual(narration.last)],
      hint: 'Răspunsul este: ${step.answer.label}.',
      choices: [for (final o in options) Choice(label: o.label, art: o.emoji, correct: identical(o, step.answer))],
    );
  }
}
