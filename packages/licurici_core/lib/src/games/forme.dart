/// Jocurile de forme, culori și logică (mecanica `choice`).
library;

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

/// Culori — nume ↔ culoare, alternat (port din `culori.js`).
class CuloriGame extends ChoiceGame {
  const CuloriGame()
      : super(
          id: 'culori',
          name: 'Culori',
          emoji: '🎨',
          description: 'Învață culorile',
          subject: Subject.forme,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege culoarea potrivită.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx, i.isEven)],
      );

  ChoiceRound _round(GameContext ctx, bool colorToName) {
    final target = ctx.pick(content.colors);
    final options = [
      target,
      ...ctx.sample(content.colors.where((c) => c != target).toList(), 4),
    ]..shuffle(ctx.random);
    if (colorToName) {
      return ChoiceRound(
        prompt: 'Ce culoare este?',
        visuals: [ColorVisual(target.argb)],
        hint: 'Aceasta este culoarea ${target.name}.',
        choices: [for (final o in options) Choice(label: o.name, correct: o == target)],
      );
    }
    return ChoiceRound(
      prompt: 'Alege culoarea:',
      speak: [target.name],
      visuals: [TextVisual(target.name)],
      hint: '${target.name} arată așa.',
      choices: [
        for (final o in options) Choice(color: o.argb, speak: o.name, correct: o == target),
      ],
    );
  }
}

/// Forme — formă ↔ nume, alternat (port din `forme.js`).
class FormeGame extends ChoiceGame {
  const FormeGame()
      : super(
          id: 'forme',
          name: 'Forme',
          emoji: '🔷',
          description: 'Învață formele',
          subject: Subject.forme,
          gradeCodes: 'G12',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege forma potrivită.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx, i.isEven)],
      );

  ChoiceRound _round(GameContext ctx, bool shapeToName) {
    final target = ctx.pick(content.shapes);
    final options = [
      target,
      ...ctx.sample(content.shapes.where((s) => s != target).toList(), 4),
    ]..shuffle(ctx.random);
    if (shapeToName) {
      return ChoiceRound(
        prompt: 'Ce formă este?',
        visuals: [EmojiVisual(target.emoji)],
        hint: 'Aceasta este ${target.word}.',
        choices: [for (final o in options) Choice(label: o.word, correct: o == target)],
      );
    }
    return ChoiceRound(
      prompt: 'Alege forma:',
      speak: [target.word],
      visuals: [TextVisual(target.word)],
      hint: '${target.word} arată așa.',
      choices: [
        for (final o in options) Choice(art: o.emoji, speak: o.word, correct: o == target),
      ],
    );
  }
}
