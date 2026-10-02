/// Modelul jocurilor: fiecare joc = `GameSpec` (metadate + generator de runde) peste o
/// mecanică reutilizabilă (README §15, ADR-19). Totul e Dart pur: stratul UI doar desenează.
library;

import 'dart:math';

import 'difficulty.dart';
import 'grades.dart';

enum Mechanic { choice, dragDrop, memoryCards, sequence, trace, puzzle, maze, freePlay, explore }

/// Contextul în care se generează o lecție. [random] e injectat → generare deterministă în teste.
class GameContext {
  GameContext({required this.difficulty, required this.grade, Random? random})
      : random = random ?? Random();

  final Difficulty difficulty;
  final Grade grade;
  final Random random;

  int intBetween(int lo, int hi) => lo + random.nextInt(hi - lo + 1);
  T pick<T>(List<T> items) => items[random.nextInt(items.length)];

  /// [count] elemente distincte, în ordine aleatoare.
  List<T> sample<T>(List<T> items, int count) =>
      (List.of(items)..shuffle(random)).take(count).toList();
}

// ---------------------------------------------------------------- stimuli (ce se arată)

/// Ce se afișează în zona de întrebare. UI-ul alege widget-ul și animația după tip.
sealed class Visual {
  const Visual();
}

/// Un emoji mare (transformat în ilustrație OpenMoji de UI).
class EmojiVisual extends Visual {
  const EmojiVisual(this.emoji);
  final String emoji;
}

/// Grupuri de obiecte numărabile, opțional cu operator între ele (ex. 🍎🍎 + 🍎).
class ObjectsVisual extends Visual {
  const ObjectsVisual(this.groups, {this.operator});
  final List<ObjectGroup> groups;
  final String? operator;

  int get total => groups.fold(0, (s, g) => s + g.count);
}

class ObjectGroup {
  const ObjectGroup(this.emoji, this.count);
  final String emoji;
  final int count;
}

/// O pată de culoare.
class ColorVisual extends Visual {
  const ColorVisual(this.argb);
  final int argb;
}

/// Un text mare (ex. numele culorii) sau o ecuație.
class TextVisual extends Visual {
  const TextVisual(this.text, {this.isEquation = false});
  final String text;
  final bool isEquation;
}

/// Un șir de imagini cu un loc gol la capăt („ce urmează?”). [answer] apare în locul gol
/// după răspunsul corect.
class PatternVisual extends Visual {
  const PatternVisual(this.items, {required this.answer});
  final List<String> items;
  final String answer;
}

/// O scenă scurtă descrisă în cuvinte („Un copil a primit un cadou.”).
class SceneVisual extends Visual {
  const SceneVisual(this.text);
  final String text;
}

// ---------------------------------------------------------------- răspunsuri

/// O variantă de răspuns: text și/sau ilustrație și/sau culoare și/sau un grup de obiecte.
class Choice {
  const Choice({
    this.label,
    this.art,
    this.color,
    this.objects,
    this.correct = false,
    this.speak,
    this.id,
  })
      : assert(label != null || art != null || color != null || objects != null, 'variantă goală');

  final String? label;
  final String? art;
  final int? color;

  /// Un grup de obiecte numărabile (ex. „Comparăm”: varianta ESTE grupa de mere).
  final ObjectGroup? objects;
  final bool correct;

  /// Ce se rostește la atingere (implicit [label]).
  final String? speak;

  String? get spoken => speak ?? label;

  /// Identificatorul stabil al stimulului (ex. cheia emoției `trist`), pentru matricea de
  /// confuzii. Implicit: eticheta / ilustrația / culoarea / cantitatea.
  final String? id;

  String get key =>
      id ?? label?.toLowerCase() ?? art ?? color?.toRadixString(16) ?? '${objects?.count}';

  @override
  String toString() => 'Choice(${label ?? art ?? color}${correct ? ', corect' : ''})';
}

/// O rundă de tip „alege răspunsul”.
class ChoiceRound {
  ChoiceRound({
    required this.prompt,
    required this.choices,
    this.visuals = const [],
    List<String>? speak,
    this.hint,
    this.fixedChoices = false,
  })  : speak = speak ?? [prompt],
        assert(choices.any((c) => c.correct), 'o rundă are cel puțin un răspuns corect');

  final String prompt;
  final List<Visual> visuals;
  final List<Choice> choices;

  /// Fragmentele rostite în ordine (ex. ['Cât fac', '2', 'plus', '3']).
  final List<String> speak;

  /// Indiciu neutru arătat după greșeli (învățare fără eroare).
  final String? hint;

  /// Jocurile al căror text presupune un număr fix de variante nu sunt tăiate.
  final bool fixedChoices;

  ChoiceRound copyWith({List<Choice>? choices}) => ChoiceRound(
        prompt: prompt,
        visuals: visuals,
        choices: choices ?? this.choices,
        speak: speak,
        hint: hint,
        fixedChoices: fixedChoices,
      );
}

class Lesson {
  const Lesson({required this.title, required this.rounds, this.instruction});

  final String title;
  final String? instruction;
  final List<ChoiceRound> rounds;

  /// Toate ilustrațiile (emoji → OpenMoji) folosite în lecție, ca UI-ul să le pre-încarce
  /// înainte de prima rundă (fără imagini care apar „cu întârziere” în timpul animațiilor).
  Set<String> get art => {
        for (final r in rounds) ...[
          for (final c in r.choices) ...[
            if (c.art != null) c.art!,
            if (c.objects != null) c.objects!.emoji,
          ],
          for (final v in r.visuals)
            ...switch (v) {
              EmojiVisual(:final emoji) => [emoji],
              ObjectsVisual(:final groups) => groups.map((g) => g.emoji),
              PatternVisual(:final items, :final answer) => [...items, answer],
              _ => const <String>[],
            },
        ],
      };
}

// ---------------------------------------------------------------- jocuri

abstract class GameSpec {
  const GameSpec();

  String get id;
  String get name;
  String get emoji;
  String get description;
  Subject get subject;
  Set<Grade> get grades;
  Mechanic get mechanic;

  /// Jocurile care au nevoie de toate rundele generate.
  bool get fixedRounds => false;

  /// Generează GENEROS (până la 5 variante, mai multe runde); motorul taie după tier.
  Lesson generate(GameContext ctx);

  /// Lecția gata de jucat: generată + scalată după dificultate.
  Lesson build(GameContext ctx) => scaleLesson(generate(ctx), this, ctx);
}

/// Baza jocurilor „alege răspunsul”: metadatele vin prin constructor (fără repetiție în
/// fiecare joc). Clasele: codul compact `G1234` (G = grădiniță).
abstract class ChoiceGame extends GameSpec {
  const ChoiceGame({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.subject,
    required this.gradeCodes,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String emoji;
  @override
  final String description;
  @override
  final Subject subject;
  final String gradeCodes;

  @override
  Set<Grade> get grades => Grade.parseCodes(gradeCodes);

  @override
  Mechanic get mechanic => Mechanic.choice;
}

/// Aplică scalarea universală a motorului (port din `engine.js`):
/// taie rundele la `roundCount` și variantele la `optionCount`, păstrând mereu corectul.
Lesson scaleLesson(Lesson lesson, GameSpec spec, GameContext ctx) {
  final d = ctx.difficulty;
  final rounds = spec.fixedRounds ? lesson.rounds : lesson.rounds.take(d.roundCount).toList();
  return Lesson(
    title: lesson.title,
    instruction: lesson.instruction,
    rounds: [for (final r in rounds) _trimRound(r, d.optionCount, ctx.random)],
  );
}

ChoiceRound _trimRound(ChoiceRound r, int optN, Random random) {
  if (r.fixedChoices || r.choices.length <= optN) return r;
  final correct = r.choices.where((c) => c.correct).toList();
  final wrong = r.choices.where((c) => !c.correct).toList()..shuffle(random);
  final keepWrong = max(1, optN - correct.length);
  return r.copyWith(choices: [...correct, ...wrong.take(keepWrong)]..shuffle(random));
}

/// Variante numerice: corectul + vecini apropiați, unici, în [lo, hi] (port din `_math.js`).
List<int> numberChoices(GameContext ctx, int correct, int lo, int hi, {int count = 5}) {
  final set = <int>{correct};
  var guard = 0;
  while (set.length < count && guard++ < 80) {
    final delta = (ctx.random.nextBool() ? -1 : 1) * ctx.intBetween(1, 3);
    final d = correct + delta;
    if (d >= lo && d <= hi) set.add(d);
  }
  for (var x = lo; set.length < count && x <= hi; x++) {
    set.add(x);
  }
  return set.toList()..shuffle(ctx.random);
}
