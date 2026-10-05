/// Jocurile de matematică (mecanica `choice`). Numerele cresc cu tier-ul; obiectele
/// (sprijin vizual) apar doar cât numerele sunt mici — trecere de la concret la abstract.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

/// Numărăm — câte obiecte sunt? (port din `numaram.js`)
class NumaramGame extends ChoiceGame {
  const NumaramGame()
      : super(
          id: 'numaram',
          name: 'Numărăm',
          emoji: '🔢',
          description: 'Câte obiecte vezi?',
          subject: Subject.matematica,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxN = min(3 + ctx.difficulty.tier * 2, 20);
    return Lesson(
      title: name,
      instruction: 'Numără obiectele și alege numărul.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxN)],
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
        for (final n in numberChoices(ctx, count, 1, maxN)) Choice(label: '$n', correct: n == count),
      ],
    );
  }
}

/// Adunăm — adunare cu sprijin vizual cât numerele sunt mici (port din `adunam.js`).
class AdunamGame extends ChoiceGame {
  const AdunamGame()
      : super(
          id: 'adunam',
          name: 'Adunăm',
          emoji: '➕',
          description: 'Învață să aduni',
          subject: Subject.matematica,
          gradeCodes: '123',
        );

  @override
  Lesson generate(GameContext ctx) {
    final t = ctx.difficulty.tier;
    final maxTerm = min(3 + t * 3, 50);
    final maxSum = min(6 + t * 8, 100);
    return Lesson(
      title: name,
      instruction: 'Câte sunt în total?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxTerm, maxSum)],
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

/// Scădem — câte rămân (port din `scadem.js`). Obiectele luate sunt arătate separat,
/// după semnul minus, ca copilul să vadă ce „pleacă”.
class ScademGame extends ChoiceGame {
  const ScademGame()
      : super(
          id: 'scadem',
          name: 'Scădem',
          emoji: '➖',
          description: 'Învață să scazi',
          subject: Subject.matematica,
          gradeCodes: '123',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxA = min(6 + ctx.difficulty.tier * 6, 100);
    return Lesson(
      title: name,
      instruction: 'Câte rămân?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxA)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxA) {
    final a = ctx.intBetween(2, maxA);
    final b = ctx.intBetween(1, a - 1);
    final rest = a - b;
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Câte rămân?',
      speak: ['Cât fac', '$a', 'minus', '$b'],
      visuals: [
        if (a <= 20) ObjectsVisual([ObjectGroup(item, a), ObjectGroup(item, b)], operator: '−'),
        TextVisual('$a − $b = ?', isEquation: true),
      ],
      hint: 'Iei $b. Rămân $rest.',
      choices: [
        for (final n in numberChoices(ctx, rest, 0, maxA)) Choice(label: '$n', correct: n == rest),
      ],
    );
  }
}

/// Comparăm — unde sunt mai multe? (port din `comparam.js`). Variantele SUNT grupele,
/// deci nu se taie după tier (`fixedChoices`).
class ComparamGame extends ChoiceGame {
  const ComparamGame()
      : super(
          id: 'comparam',
          name: 'Comparăm',
          emoji: '⚖️',
          description: 'Mai mult sau mai puțin?',
          subject: Subject.matematica,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxN = min(3 + ctx.difficulty.tier * 2, 20);
    return Lesson(
      title: name,
      instruction: 'Alege unde sunt mai multe.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxN, equal: i % 3 == 2)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxN, {required bool equal}) {
    final a = ctx.intBetween(1, maxN);
    var b = equal ? a : ctx.intBetween(1, maxN);
    // O rundă „diferită” nu trebuie să iasă egală din întâmplare.
    while (!equal && b == a && maxN > 1) {
      b = ctx.intBetween(1, maxN);
    }
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Unde sunt mai multe?',
      fixedChoices: true,
      hint: a == b ? 'Sunt la fel de multe.' : 'Sunt mai multe în grupa ${a > b ? 'A' : 'B'}.',
      choices: [
        Choice(label: 'Grupa A', objects: ObjectGroup(item, a), correct: a > b),
        Choice(label: 'Grupa B', objects: ObjectGroup(item, b), correct: b > a),
        Choice(label: 'La fel', art: '🤝', correct: a == b),
      ],
    );
  }
}


/// Semnele < > = (port din `semne.js`): ce semn se potrivește între două numere. Numerele
/// cresc cu tier-ul; cât sunt mici, apar și obiectele (concret → abstract). O rundă din trei
/// are numere egale. Cele trei variante au mereu aceeași ordine (<, =, >) — predictibil.
class SemneGame extends ChoiceGame {
  const SemneGame()
      : super(
          id: 'semne',
          name: 'Semnele',
          emoji: '⚖️',
          description: 'Mai mic, egal sau mai mare?',
          subject: Subject.matematica,
          gradeCodes: '123',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxN = min(5 + ctx.difficulty.tier * 12, 1000);
    final n = ctx.difficulty.roundCount;
    return Lesson(
      title: name,
      instruction: 'Alege semnul potrivit.',
      rounds: [for (var i = 0; i < n; i++) _round(ctx, maxN, equal: i % 3 == 2)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxN, {required bool equal}) {
    final a = ctx.intBetween(1, maxN);
    var b = equal ? a : ctx.intBetween(1, maxN);
    if (!equal && b == a) b = a == maxN ? a - 1 : a + 1;
    final sign = a < b ? '<' : (a > b ? '>' : '=');
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Ce semn se potrivește?',
      speak: ['Ce semn se potrivește?'],
      visuals: [
        if (a <= 10 && b <= 10) ObjectsVisual([ObjectGroup(item, a), ObjectGroup(item, b)]),
        TextVisual('$a  ?  $b', isEquation: true),
      ],
      hint: '$a $sign $b',
      fixedChoices: true,
      stimulusId: sign == '=' ? 'egal' : 'diferit',
      choices: [
        Choice(label: '<', id: 'mai-mic', speak: 'mai mic', correct: sign == '<'),
        Choice(label: '=', id: 'egal', speak: 'egal', correct: sign == '='),
        Choice(label: '>', id: 'mai-mare', speak: 'mai mare', correct: sign == '>'),
      ],
    );
  }
}

/// Numărul lipsă (port din `lipsa.js`): completează egalitatea (3 + ? = 7). Cu obiecte cât
/// suma e mică; locul gol e uneori primul termen, alteori al doilea.
class LipsaGame extends ChoiceGame {
  const LipsaGame()
      : super(
          id: 'numarul-lipsa',
          name: 'Numărul lipsă',
          emoji: '❓',
          description: 'Ce număr lipsește?',
          subject: Subject.matematica,
          gradeCodes: '123',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxSum = min(6 + ctx.difficulty.tier * 6, 50);
    return Lesson(
      title: name,
      instruction: 'Ce număr lipsește?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxSum)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxSum) {
    final sum = ctx.intBetween(3, maxSum);
    final a = ctx.intBetween(1, sum - 1);
    final b = sum - a;
    final first = ctx.random.nextBool();
    final missing = first ? a : b;
    return ChoiceRound(
      prompt: 'Ce număr lipsește?',
      speak: ['Ce număr lipsește?'],
      visuals: [TextVisual(first ? '? + $b = $sum' : '$a + ? = $sum', isEquation: true)],
      hint: 'Numărul care lipsește este $missing.',
      choices: [
        for (final n in numberChoices(ctx, missing, 1, maxSum)) Choice(label: '$n', correct: n == missing),
      ],
    );
  }
}
