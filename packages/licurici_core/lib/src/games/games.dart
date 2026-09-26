/// Primele jocuri portate din prototip (mecanica `choice`).
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

/// Numărăm — câte obiecte sunt? (port din `numaram.js`)
class NumaramGame extends GameSpec {
  const NumaramGame();

  @override
  String get id => 'numaram';
  @override
  String get name => 'Numărăm';
  @override
  String get emoji => '🔢';
  @override
  String get description => 'Câte obiecte vezi?';
  @override
  Subject get subject => Subject.matematica;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1');
  @override
  Mechanic get mechanic => Mechanic.choice;

  @override
  Lesson generate(GameContext ctx) {
    final maxN = min(3 + ctx.difficulty.tier * 2, 20);
    return Lesson(
      title: name,
      instruction: 'Numără obiectele și alege numărul.',
      rounds: [
        for (var i = 0; i < 8; i++) _round(ctx, maxN),
      ],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxN) {
    final count = ctx.intBetween(1, maxN);
    final item = ctx.pick(content.countItems);
    return ChoiceRound(
      prompt: 'Câte sunt?',
      speak: ['Câte obiecte sunt?'],
      visuals: [ObjectsVisual([ObjectGroup(item, count)])],
      hint: 'Numără unul câte unul. Sunt $count.',
      choices: [
        for (final n in numberChoices(ctx, count, 1, maxN))
          Choice(label: '$n', correct: n == count),
      ],
    );
  }
}

/// Adunăm — adunare cu sprijin vizual cât numerele sunt mici (port din `adunam.js`).
class AdunamGame extends GameSpec {
  const AdunamGame();

  @override
  String get id => 'adunam';
  @override
  String get name => 'Adunăm';
  @override
  String get emoji => '➕';
  @override
  String get description => 'Învață să aduni';
  @override
  Subject get subject => Subject.matematica;
  @override
  Set<Grade> get grades => Grade.parseCodes('123');
  @override
  Mechanic get mechanic => Mechanic.choice;

  @override
  Lesson generate(GameContext ctx) {
    final t = ctx.difficulty.tier;
    final maxTerm = min(3 + t * 3, 50);
    final maxSum = min(6 + t * 8, 100);
    return Lesson(
      title: name,
      instruction: 'Câte sunt în total?',
      rounds: [
        for (var i = 0; i < 8; i++) _round(ctx, maxTerm, maxSum),
      ],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxTerm, int maxSum) {
    final a = ctx.intBetween(1, maxTerm);
    final b = ctx.intBetween(1, min(maxTerm, maxSum - a));
    final sum = a + b;
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Cât fac?',
      speak: ['Cât fac', '$a', 'plus', '$b'],
      visuals: [
        // Concret → abstract: obiecte doar cât suma e mică.
        if (sum <= 20) ObjectsVisual([ObjectGroup(item, a), ObjectGroup(item, b)], operator: '+'),
        TextVisual('$a + $b = ?', isEquation: true),
      ],
      hint: 'Numără toate obiectele: sunt $sum.',
      choices: [
        for (final n in numberChoices(ctx, sum, 1, maxSum)) Choice(label: '$n', correct: n == sum),
      ],
    );
  }
}

/// Culori — nume ↔ culoare, alternat (port din `culori.js`).
class CuloriGame extends GameSpec {
  const CuloriGame();

  @override
  String get id => 'culori';
  @override
  String get name => 'Culori';
  @override
  String get emoji => '🎨';
  @override
  String get description => 'Învață culorile';
  @override
  Subject get subject => Subject.forme;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1');
  @override
  Mechanic get mechanic => Mechanic.choice;

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

/// Emoții — față → emoție, situație → față (port din `emotii.js`).
class EmotiiGame extends GameSpec {
  const EmotiiGame();

  @override
  String get id => 'emotii';
  @override
  String get name => 'Emoții';
  @override
  String get emoji => '😊';
  @override
  String get description => 'Recunoaște cum se simt oamenii';
  @override
  Subject get subject => Subject.emotii;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1234');
  @override
  Mechanic get mechanic => Mechanic.choice;

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
        choices: [for (final o in options) Choice(label: o.label, correct: o == target)],
      );
    }
    final situation = ctx.pick(target.contexts);
    return ChoiceRound(
      prompt: 'Cum se simte?',
      speak: ['Cum se simte un copil care $situation?'],
      visuals: [SceneVisual('Un copil $situation.')],
      hint: 'Când $situation, te simți ${target.label.toLowerCase()}.',
      choices: [
        for (final o in options) Choice(label: o.label, art: o.emoji, correct: o == target),
      ],
    );
  }
}

/// Registrul jocurilor (port din `registry.js`): adăugarea unui joc = o intrare aici.
const List<GameSpec> allGames = [
  NumaramGame(),
  AdunamGame(),
  CuloriGame(),
  EmotiiGame(),
];

GameSpec? gameById(String id) {
  for (final g in allGames) {
    if (g.id == id) return g;
  }
  return null;
}

/// Jocurile pentru o clasă, grupate pe materii (în ordinea din [Subject]).
Map<Subject, List<GameSpec>> gamesForGrade(Grade grade) => {
      for (final s in Subject.values)
        if (allGames.any((g) => g.subject == s && g.grades.contains(grade)))
          s: allGames.where((g) => g.subject == s && g.grades.contains(grade)).toList(),
    };
