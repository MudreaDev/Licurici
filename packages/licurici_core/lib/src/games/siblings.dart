/// Jocurile „frate” cu alegere: același obiectiv ca un joc existent, pe alt material sau cu alt
/// fel de răspuns — ca stăpânirea să se poată verifica pe mai mult de un joc (generalizarea,
/// plan §4; docs/research/07-dificultate-adaptiva.md).
library;

import '../face.dart';
import '../game.dart';
import '../grades.dart';
import '../ordering.dart';
import 'social_content.dart';

/// Emoțiile din situații care au și o față desenată.
const _drawable = {
  'fericit': FaceEmotion.bucuros,
  'trist': FaceEmotion.trist,
  'suparat': FaceEmotion.suparat,
  'speriat': FaceEmotion.speriat,
  'surprins': FaceEmotion.surprins,
  'obosit': FaceEmotion.obosit,
  'calm': FaceEmotion.neutru,
};

/// Cum se simte? (EMO3, fratele lui „Ce simte?”): aceeași întâmplare, dar răspunsul e o **față**,
/// nu un cuvânt — fața aceleiași persoane cu emoții diferite (singurul lucru care se schimbă între
/// variante e expresia). Axe: câte variante (motorul), intensitatea expresiei (1 → 0,6: emoții tot
/// mai discrete), emoțiile „surprins” de la tier 3.
class CumSeSimteGame extends ChoiceGame {
  const CumSeSimteGame()
      : super(
          id: 'cum-se-simte',
          name: 'Cum se simte?',
          emoji: '🙂',
          description: 'Alege fața potrivită întâmplării',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final pool = [
      for (final e in feltEmotions)
        if (_drawable.containsKey(e.key) && e.minTier <= tier) e,
    ];
    // Expresii tot mai discrete pe măsură ce crește tier-ul (pragul de recunoaștere).
    final intensity = (1.05 - 0.07 * tier).clamp(0.6, 1.0);
    return Lesson(
      title: name,
      instruction: 'Ascultă ce s-a întâmplat și alege fața.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, pool, intensity)],
    );
  }

  ChoiceRound _round(GameContext ctx, List<FeltEmotion> pool, double intensity) {
    final c = ctx.pick(characters);
    final target = ctx.pick(pool);
    final scene = ctx.pick(target.situations).replaceAll('{n}', c.name);
    final look = FaceLook.random(ctx.random);
    final others = pool.where((e) => e != target && !emotionsClash(e.key, target.key)).toList();
    final options = [target, ...ctx.sample(others, 4)]..shuffle(ctx.random);
    final question = 'Cum se simte ${c.name}?';
    return ChoiceRound(
      prompt: question,
      speak: [scene, question],
      // Doar întâmplarea: persoana apare abia în variante (aceeași față, expresii diferite).
      visuals: [SceneVisual(scene)],
      hint: 'Gândește-te cum te-ai simți tu.',
      choices: [
        for (final o in options)
          Choice(
            art: FaceSpec(look, _drawable[o.key]!, intensity).art,
            id: o.key,
            speak: o.label(c),
            correct: o == target,
          ),
      ],
    );
  }
}

/// Ajută-l pe Licurici (AUT1–2, fratele lui „Pașii rutinei”): rutina se joacă pas cu pas — la
/// fiecare pas copilul alege doar ce urmează (în „Pașii rutinei” ordonează toată rutina deodată).
/// Axe: la tier mic, variantele greșite vin din alte rutine (ușor de deosebit); de la tier 4, din
/// aceeași rutină (pașii de mai târziu — trebuie știută ordinea); câte variante (motorul).
class AjutaLicuriciGame extends ChoiceGame {
  const AjutaLicuriciGame()
      : super(
          id: 'ajuta-l-pe-licurici',
          name: 'Ajută-l pe Licurici',
          emoji: '🧺',
          description: 'Alege ce face Licurici acum',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  static const question = 'Ce face Licurici acum?';

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final rounds = <ChoiceRound>[];
    final stories = [...routineStories]..shuffle(ctx.random);
    for (final story in stories) {
      // Pașii de la al doilea încolo: copilul vede ce s-a făcut deja și alege următorul.
      for (var k = 1; k < story.steps.length && rounds.length < 8; k++) {
        rounds.add(_round(ctx, story, k, sameRoutine: tier >= 4));
      }
      if (rounds.length >= 8) break;
    }
    return Lesson(title: name, instruction: 'Ajută-l pe Licurici. Alege ce urmează.', rounds: rounds);
  }

  ChoiceRound _round(GameContext ctx, OrderStory story, int k, {required bool sameRoutine}) {
    final next = story.steps[k];
    final later = story.steps.skip(k + 1).toList();
    // Pașii altor rutine, fără cei care apar și în aceasta, câte unul pe imagine.
    final seen = <String>{for (final y in story.steps) y.emoji};
    final elsewhere = [
      for (final s in routineStories)
        if (s != story)
          for (final x in s.steps)
            if (seen.add(x.emoji)) x,
    ];
    // Distractorii: din aceeași rutină (pași de mai târziu) sau din altele; completăm din celălalt
    // izvor dacă nu ajung.
    final first = sameRoutine ? later : elsewhere;
    final second = sameRoutine ? elsewhere : later;
    final wrong = [...ctx.sample(first, 4)];
    if (wrong.length < 4) wrong.addAll(ctx.sample(second.where((s) => !wrong.contains(s)).toList(), 4 - wrong.length));
    final options = [next, ...wrong]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: question,
      speak: [story.title, question],
      visuals: [PatternVisual([for (final s in story.steps.take(k)) s.emoji], answer: next.emoji)],
      hint: 'Uită-te la ce a făcut deja.',
      choices: [for (final o in options) Choice(art: o.emoji, id: o.emoji, speak: o.caption, correct: o == next)],
    );
  }
}
