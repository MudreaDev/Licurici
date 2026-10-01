/// Jocurile despre emoții, comunicare și viața de zi cu zi (mecanica `choice`).
library;

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

/// Emoții — față → emoție, situație → față (port din `emotii.js`).
class EmotiiGame extends ChoiceGame {
  const EmotiiGame()
      : super(
          id: 'emotii',
          name: 'Emoții',
          emoji: '😊',
          description: 'Recunoaște cum se simt oamenii',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege răspunsul potrivit.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx, i.isEven)],
      );

  ChoiceRound _round(GameContext ctx, bool faceToLabel) {
    final target = ctx.pick(content.emotions);
    // Fără emoții „vecine” ca distractori (ex. fericit/mândru) — un singur răspuns bun.
    final distractors = content.emotions
        .where((e) => e != target && !target.similar.contains(e.key) && !e.similar.contains(target.key))
        .toList();
    final options = [target, ...ctx.sample(distractors, 4)]..shuffle(ctx.random);
    if (faceToLabel) {
      return ChoiceRound(
        prompt: 'Cum se simte?',
        visuals: [EmojiVisual(target.emoji)],
        hint: 'Fața asta arată „${target.label.toLowerCase()}”.',
        choices: [for (final o in options) Choice(label: o.label, id: o.key, correct: o == target)],
      );
    }
    final situation = ctx.pick(target.contexts);
    return ChoiceRound(
      prompt: 'Cum se simte?',
      speak: ['Cum se simte un copil care $situation?'],
      visuals: [SceneVisual('Un copil $situation.')],
      hint: 'Când $situation, te simți ${target.label.toLowerCase()}.',
      choices: [
        for (final o in options) Choice(label: o.label, art: o.emoji, id: o.key, correct: o == target),
      ],
    );
  }
}

/// Da sau nu? — înțelegerea conceptului da/nu (joc nou, după categoria „Yes or No” din
/// AutiSpark). Vezi un obiect și o întrebare; răspunsul e „da” cam jumătate din timp.
/// Mereu exact două variante, în aceeași ordine (Da stânga, Nu dreapta) — predictibil.
class DaNuGame extends ChoiceGame {
  const DaNuGame()
      : super(
          id: 'da-nu',
          name: 'Da sau nu?',
          emoji: '✅',
          description: 'Răspunde cu da sau nu',
          subject: Subject.emotii,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    // Exact jumătate „da” (rotunjit în jos), în ordine amestecată — nici previzibil, nici
    // dezechilibrat. Generăm direct câte runde cere tier-ul, ca tăierea să nu strice echilibrul.
    final n = ctx.difficulty.roundCount;
    final answers = [for (var i = 0; i < n; i++) i < n ~/ 2]..shuffle(ctx.random);
    return Lesson(
      title: name,
      instruction: 'Ascultă întrebarea și răspunde.',
      rounds: [for (final yes in answers) _round(ctx, yes)],
    );
  }

  ChoiceRound _round(GameContext ctx, bool yes) {
    final shown = ctx.pick(content.alphabet);
    final asked = yes
        ? shown
        : ctx.pick(content.alphabet.where((a) => a.emoji != shown.emoji).toList());
    return ChoiceRound(
      prompt: 'Este ${asked.word}?',
      speak: ['Este ${asked.word}?'],
      visuals: [EmojiVisual(shown.emoji)],
      fixedChoices: true,
      hint: yes ? 'Da, este ${shown.word}.' : 'Nu, este ${shown.word}.',
      choices: [
        Choice(label: 'Da', art: '✅', speak: 'da', correct: yes),
        Choice(label: 'Nu', art: '❌', speak: 'nu', correct: !yes),
      ],
    );
  }
}
