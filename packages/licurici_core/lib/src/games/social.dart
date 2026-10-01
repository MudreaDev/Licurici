/// Jocurile de cogniție socială pe traseul EMO (plan §3.2): emoția din situație (EMO3),
/// strategii de reglare (EMO4), perspectivă / teoria minții (EMO5), situații sociale (EMO6).
/// Fiecare joc își crește dificultatea pe axe (catalog §2), nu doar numărul de variante.
library;

import '../game.dart';
import '../grades.dart';
import 'social_content.dart';

String _fill(String template, Character c) => template.replaceAll('{n}', c.name);

/// Ce simte? (EMO3) — situație → emoție. Axe: emoțiile disponibile (de bază → toate),
/// direcția (situație → emoție, apoi de la tier 4 și emoție → cauză), nr. variante.
class CeSimteGame extends ChoiceGame {
  const CeSimteGame()
      : super(
          id: 'ce-simte',
          name: 'Ce simte?',
          emoji: '❓',
          description: 'Ghicește cum se simte personajul',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final pool = feltEmotions.where((e) => e.minTier <= tier).toList();
    return Lesson(
      title: name,
      instruction: 'Ascultă ce s-a întâmplat și alege.',
      rounds: [
        for (var i = 0; i < 8; i++)
          tier >= 4 && i.isOdd ? _causeRound(ctx, pool) : _feelingRound(ctx, pool),
      ],
    );
  }

  ChoiceRound _feelingRound(GameContext ctx, List<FeltEmotion> pool) {
    final c = ctx.pick(characters);
    final target = ctx.pick(pool);
    final scene = _fill(ctx.pick(target.situations), c);
    final others = pool.where((e) => !emotionsClash(e.key, target.key)).toList();
    final options = [target, ...ctx.sample(others, 4)]..shuffle(ctx.random);
    final question = 'Cum se simte ${c.name}?';
    return ChoiceRound(
      prompt: question,
      speak: [scene, question],
      visuals: [EmojiVisual(c.emoji), SceneVisual(scene)],
      hint: 'Gândește-te cum te-ai simți tu.',
      choices: [
        for (final o in options) Choice(label: o.label(c), art: o.emoji, id: o.key, correct: o == target),
      ],
    );
  }

  ChoiceRound _causeRound(GameContext ctx, List<FeltEmotion> pool) {
    final c = ctx.pick(characters);
    final target = ctx.pick(pool);
    // Cauzele altor emoții grele pot fi și ele plauzibile (turnul dărâmat întristează și el):
    // pentru o emoție grea, distractorii vin doar din emoțiile plăcute sau neutre.
    final others = pool
        .where((e) => !emotionsClash(e.key, target.key))
        .where((e) => !(hardEmotions.contains(target.key) && hardEmotions.contains(e.key)))
        .toList();
    final wrong = [for (final e in ctx.sample(others, 4)) ctx.pick(e.situations)];
    final right = ctx.pick(target.situations);
    final options = [right, ...wrong]..shuffle(ctx.random);
    final question = 'De ce este ${c.name} ${target.label(c).toLowerCase()}?';
    return ChoiceRound(
      prompt: question,
      visuals: [EmojiVisual(target.emoji)],
      hint: 'Caută ce te-ar face și pe tine ${target.label(c).toLowerCase()}.',
      choices: [for (final o in options) Choice(label: _fill(o, c), correct: o == right)],
    );
  }
}

/// Ce mă ajută? (EMO4) — strategii de reglare emoțională. Axe: emoția e spusă (tier 1–3) sau
/// trebuie dedusă din situație (tier 4+), nr. variante.
class CeMaAjutaGame extends ChoiceGame {
  const CeMaAjutaGame()
      : super(
          id: 'ce-ma-ajuta',
          name: 'Ce mă ajută?',
          emoji: '🤗',
          description: 'Alege ce ajută când te simți greu',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege ce îl poate ajuta pe personaj.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx, implicit: ctx.difficulty.tier >= 4 && i.isOdd)],
      );

  ChoiceRound _round(GameContext ctx, {required bool implicit}) {
    final c = ctx.pick(characters);
    final key = ctx.pick(helpfulStrategies.keys.toList());
    final emotion = feltEmotions.firstWhere((e) => e.key == key);
    final good = ctx.pick(helpfulStrategies[key]!);
    final options = [good, ...ctx.sample(unhelpfulStrategies, 4)]..shuffle(ctx.random);
    final scene = implicit
        ? _fill(ctx.pick(emotion.situations), c)
        : '${c.name} este ${emotion.label(c).toLowerCase()}.';
    final question = 'Ce ${c.acc} poate ajuta?';
    return ChoiceRound(
      prompt: question,
      speak: [scene, question],
      visuals: [EmojiVisual(implicit ? c.emoji : emotion.emoji), SceneVisual(scene)],
      hint: 'Alege ceva care face bine și nu rănește pe nimeni.',
      choices: [
        for (final o in options) Choice(label: o.label, art: o.emoji, correct: o == good),
      ],
    );
  }
}

/// Cine știe? (EMO5) — perspectivă, după sarcinile clasice de teoria minții, generate
/// combinatoriu (personaje × obiecte × locuri). Axe pe tier:
///  1–2: acces la informație („cine a văzut știe”);
///  3–4: credință falsă despre loc (Sally–Anne), alternată cu întrebarea de control „unde e acum?”;
///  5+:  conținut neașteptat („ce crede că e în cutia de creioane?”), plus cele de mai sus.
class CineStieGame extends ChoiceGame {
  const CineStieGame()
      : super(
          id: 'cine-stie',
          name: 'Cine știe?',
          emoji: '🧠',
          description: 'Ce știe și ce crede fiecare',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final rounds = <ChoiceRound>[];
    for (var i = 0; i < 8; i++) {
      if (tier <= 2) {
        rounds.add(_sawIt(ctx));
      } else if (tier <= 4) {
        rounds.add(i.isEven ? _falseBelief(ctx, control: i % 4 == 2) : _sawIt(ctx));
      } else {
        rounds.add(switch (i % 3) {
          0 => _falseBelief(ctx),
          1 => _trickBox(ctx),
          _ => _falseBelief(ctx, control: true),
        });
      }
    }
    return Lesson(title: name, instruction: 'Ascultă povestea și răspunde.', rounds: rounds);
  }

  (Character, Character) _pair(GameContext ctx) {
    final two = ctx.sample(characters, 2);
    return (two[0], two[1]);
  }

  int _places(GameContext ctx) => ctx.difficulty.optionCount.clamp(2, 3);

  ChoiceRound _sawIt(GameContext ctx) {
    final (a, b) = _pair(ctx);
    final thing = ctx.pick(hiddenThings);
    final place = ctx.pick(hidingPlaces);
    final story = [
      '${a.name} ascunde ${thing.def} ${place.inPhrase}.',
      '${b.name} doarme și nu vede.',
    ];
    const question = 'Cine știe unde este?';
    final options = [a, b]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: question,
      speak: [...story, question],
      visuals: [EmojiVisual(thing.emoji), SceneVisual(story.join(' '))],
      fixedChoices: true,
      hint: 'Știe cine a văzut.',
      choices: [
        for (final o in options) Choice(label: o.name, art: o.emoji, correct: o == a),
      ],
    );
  }

  ChoiceRound _falseBelief(GameContext ctx, {bool control = false}) {
    final (a, b) = _pair(ctx);
    final thing = ctx.pick(hiddenThings);
    final places = ctx.sample(hidingPlaces, _places(ctx));
    final first = places[0], moved = places[1];
    final story = [
      '${a.name} pune ${thing.def} ${first.inPhrase}.',
      '${a.name} iese din cameră.',
      '${b.name} mută ${thing.def} ${moved.inPhrase}.',
      '${a.name} se întoarce.',
    ];
    final question =
        control ? 'Unde este ${thing.def} acum?' : 'Unde va căuta ${a.name} ${thing.def}?';
    final correct = control ? moved : first;
    final options = List.of(places)..shuffle(ctx.random);
    return ChoiceRound(
      prompt: question,
      speak: [...story, question],
      visuals: [EmojiVisual(a.emoji), SceneVisual(story.join(' '))],
      fixedChoices: true,
      hint: control
          ? 'Uită-te unde a ajuns la final.'
          : '${a.name} nu a văzut când s-a mutat.',
      choices: [
        for (final o in options) Choice(label: o.label, art: o.emoji, correct: o == correct),
      ],
    );
  }

  ChoiceRound _trickBox(GameContext ctx) {
    final c = ctx.pick(characters);
    final box = ctx.pick(trickBoxes);
    final story = [
      'Aceasta este ${box.name}.',
      'Dar înăuntru sunt ${box.actual.toLowerCase()}!',
      '${c.name} vine acum și vede doar cutia închisă.',
    ];
    final question = 'Ce crede ${c.name} că este în cutie?';
    final options = [
      Choice(label: box.expected, art: box.expectedEmoji, correct: true),
      Choice(label: box.actual, art: box.actualEmoji),
    ]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: question,
      speak: [...story, question],
      visuals: [EmojiVisual(box.expectedEmoji), SceneVisual(story.join(' '))],
      fixedChoices: true,
      hint: '${c.name} nu a văzut înăuntru.',
      choices: options,
    );
  }
}

/// Situații (EMO6) — povești sociale cu alegeri (port extins din `social`). Axe: complexitatea
/// situației (zi cu zi → reguli de grup → a spune nu, a cere ajutor, siguranță), nr. variante.
class SituatiiGame extends ChoiceGame {
  const SituatiiGame()
      : super(
          id: 'situatii',
          name: 'Situații',
          emoji: '🤝',
          description: 'Ce e bine să faci?',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxLevel = ctx.difficulty.tier <= 2 ? 1 : (ctx.difficulty.tier <= 4 ? 2 : 3);
    final pool = socialScenarios.where((s) => s.level <= maxLevel).toList();
    return Lesson(
      title: name,
      instruction: 'Ascultă și alege ce e bine să faci.',
      rounds: [
        for (final s in ctx.sample(pool, 8))
          ChoiceRound(
            prompt: s.question,
            visuals: [SceneVisual(s.question)],
            hint: s.explain,
            choices: [
              for (final o in [s.good, ...s.bad]..shuffle(ctx.random))
                Choice(label: o, correct: o == s.good),
            ],
          ),
      ],
    );
  }
}
