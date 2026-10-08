/// Jocurile de potrivire vizuală (POT) și limbaj receptiv (LRC), mecanica `choice`.
/// Toate folosesc aceeași bancă de obiecte, cele mai multe cu ilustrații pictate.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';

/// Grupele obiectelor: distractorii din aceeași grupă seamănă mai mult (axa „asemănare”).
enum ObjectGroupKind { fructe, mancare, natura, jucarii, lucruri, animaleCasa, animaleSalbatice, gaze }

/// Un obiect al băncii: imaginea, numele articulat („mărul”) și grupa.
class ObjectWord {
  const ObjectWord(this.emoji, this.word, this.group, {this.familiar = false});

  final String emoji;

  /// Forma articulată, cum se rostește în „Arată mărul”.
  final String word;
  final ObjectGroupKind group;

  /// Printre primele cuvinte ale unui copil mic (LRC1: doar acestea, 2 variante).
  final bool familiar;
}

const objectWords = [
  ObjectWord('🍎', 'mărul', ObjectGroupKind.fructe, familiar: true),
  ObjectWord('🍌', 'banana', ObjectGroupKind.fructe, familiar: true),
  ObjectWord('🍓', 'căpșuna', ObjectGroupKind.fructe),
  ObjectWord('🍒', 'cireșele', ObjectGroupKind.fructe),
  ObjectWord('🍉', 'pepenele', ObjectGroupKind.fructe),
  ObjectWord('🥕', 'morcovul', ObjectGroupKind.mancare),
  ObjectWord('🍞', 'pâinea', ObjectGroupKind.mancare, familiar: true),
  ObjectWord('🥚', 'oul', ObjectGroupKind.mancare),
  ObjectWord('🥛', 'laptele', ObjectGroupKind.mancare, familiar: true),
  ObjectWord('🍭', 'acadeaua', ObjectGroupKind.mancare),
  ObjectWord('🌸', 'floarea', ObjectGroupKind.natura, familiar: true),
  ObjectWord('🌳', 'copacul', ObjectGroupKind.natura),
  ObjectWord('🍂', 'frunza', ObjectGroupKind.natura),
  ObjectWord('☀️', 'soarele', ObjectGroupKind.natura, familiar: true),
  ObjectWord('🌙', 'luna', ObjectGroupKind.natura),
  ObjectWord('☁️', 'norul', ObjectGroupKind.natura),
  ObjectWord('🌈', 'curcubeul', ObjectGroupKind.natura),
  ObjectWord('⭐', 'steaua', ObjectGroupKind.natura),
  ObjectWord('❄️', 'fulgul de nea', ObjectGroupKind.natura),
  ObjectWord('⚽', 'mingea', ObjectGroupKind.jucarii, familiar: true),
  ObjectWord('🎈', 'balonul', ObjectGroupKind.jucarii, familiar: true),
  ObjectWord('🧸', 'ursulețul', ObjectGroupKind.jucarii, familiar: true),
  ObjectWord('🥁', 'toba', ObjectGroupKind.jucarii),
  ObjectWord('🎁', 'cadoul', ObjectGroupKind.jucarii),
  ObjectWord('🚗', 'mașina', ObjectGroupKind.lucruri, familiar: true),
  ObjectWord('🏠', 'casa', ObjectGroupKind.lucruri, familiar: true),
  ObjectWord('📖', 'cartea', ObjectGroupKind.lucruri),
  ObjectWord('🧼', 'săpunul', ObjectGroupKind.lucruri),
  ObjectWord('🧦', 'șosetele', ObjectGroupKind.lucruri),
  ObjectWord('🐶', 'câinele', ObjectGroupKind.animaleCasa, familiar: true),
  ObjectWord('🐱', 'pisica', ObjectGroupKind.animaleCasa, familiar: true),
  ObjectWord('🐄', 'vaca', ObjectGroupKind.animaleCasa),
  ObjectWord('🐎', 'calul', ObjectGroupKind.animaleCasa),
  ObjectWord('🐑', 'oaia', ObjectGroupKind.animaleCasa),
  ObjectWord('🐖', 'porcul', ObjectGroupKind.animaleCasa),
  ObjectWord('🐥', 'puiul', ObjectGroupKind.animaleCasa),
  ObjectWord('🦆', 'rața', ObjectGroupKind.animaleCasa),
  ObjectWord('🐓', 'cocoșul', ObjectGroupKind.animaleCasa),
  ObjectWord('🐇', 'iepurașul', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🐻', 'ursul', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🦊', 'vulpea', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🐿️', 'veverița', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🦉', 'bufnița', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🦒', 'girafa', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🦓', 'zebra', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🐘', 'elefantul', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🐢', 'broasca țestoasă', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🐬', 'delfinul', ObjectGroupKind.animaleSalbatice),
  ObjectWord('🦋', 'fluturele', ObjectGroupKind.gaze),
  ObjectWord('🐝', 'albina', ObjectGroupKind.gaze),
  ObjectWord('🐛', 'omida', ObjectGroupKind.gaze),
];

/// Grupele pe înțelesul copilului (în indiciul de la „Intrusul”).
const _groupNames = {
  ObjectGroupKind.fructe: 'fructe',
  ObjectGroupKind.mancare: 'mâncare',
  ObjectGroupKind.natura: 'natură',
  ObjectGroupKind.jucarii: 'jucării',
  ObjectGroupKind.lucruri: 'lucruri din casă',
  ObjectGroupKind.animaleCasa: 'animale de la fermă',
  ObjectGroupKind.animaleSalbatice: 'animale sălbatice',
  ObjectGroupKind.gaze: 'gâze',
};

/// Variantele greșite: la început din alte grupe (ușor de deosebit), apoi din aceeași grupă
/// (asemănare semantică / vizuală mai mare — catalog #9, #14).
List<ObjectWord> _distractors(GameContext ctx, ObjectWord target, List<ObjectWord> pool, {required bool similar}) {
  final others = pool.where((o) => o.emoji != target.emoji).toList();
  final same = others.where((o) => o.group == target.group).toList();
  final different = others.where((o) => o.group != target.group).toList();
  if (!similar) return ctx.sample(different, 4);
  final picked = ctx.sample(same, 4);
  return [...picked, ...ctx.sample(different, 4 - picked.length)];
}

/// Runde fără aceeași țintă de două ori la rând (copilul nu „învață poziția”).
List<T> _targets<T>(GameContext ctx, List<T> pool, int n) {
  final out = <T>[];
  while (out.length < n) {
    out.addAll(ctx.sample(pool, pool.length).where((t) => out.isEmpty || t != out.last));
  }
  return out.take(n).toList();
}

/// Potrivește (POT1–2, catalog #9): vezi un obiect, găsește-l pe cel la fel. Tier 1 = două
/// variante (POT1), apoi 3 → 5 (POT2); de la tier 4 distractorii vin din aceeași grupă.
class PotrivesteGame extends ChoiceGame {
  const PotrivesteGame()
      : super(
          id: 'potriveste',
          name: 'Potrivește',
          emoji: '🧩',
          description: 'Găsește obiectul la fel',
          subject: Subject.forme,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final similar = ctx.difficulty.tier >= 4;
    return Lesson(
      title: name,
      instruction: 'Găsește obiectul care e la fel.',
      rounds: [
        for (final t in _targets(ctx, objectWords, 8))
          ChoiceRound(
            prompt: 'Găsește la fel',
            speak: const ['Găsește la fel.'],
            visuals: [EmojiVisual(t.emoji)],
            hint: 'Caută-l pe cel care arată exact la fel.',
            choices: [
              for (final o in [t, ..._distractors(ctx, t, objectWords, similar: similar)]..shuffle(ctx.random))
                Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == t),
            ],
          ),
      ],
    );
  }
}

/// Arată-mi (LRC1–2, catalog #14): „Arată mingea”. Tier 1–2 = doar cuvinte foarte cunoscute
/// (LRC1), apoi toată banca (LRC2); de la tier 4 distractori din aceeași grupă (confuzii
/// semantice, măsurate prin `id`).
class ArataMiGame extends ChoiceGame {
  const ArataMiGame()
      : super(
          id: 'arata-mi',
          name: 'Arată-mi',
          emoji: '👆',
          description: 'Ascultă și arată obiectul',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final pool = tier <= 2 ? objectWords.where((o) => o.familiar).toList() : objectWords;
    return Lesson(
      title: name,
      instruction: 'Ascultă și arată.',
      rounds: [
        for (final t in _targets(ctx, pool, 8))
          ChoiceRound(
            prompt: 'Arată ${t.word}',
            speak: ['Arată ${t.word}'],
            visuals: [TextVisual(t.word)],
            hint: 'Acesta este ${t.word}.',
            choices: [
              for (final o in [t, ..._distractors(ctx, t, pool, similar: tier >= 4)]..shuffle(ctx.random))
                Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == t),
            ],
          ),
      ],
    );
  }
}

class _BodyPart {
  const _BodyPart(this.emoji, this.word);
  final String emoji;
  final String word;
}

const _body = [
  _BodyPart('👁️', 'ochiul'),
  _BodyPart('👂', 'urechea'),
  _BodyPart('👃', 'nasul'),
  _BodyPart('👄', 'gura'),
  _BodyPart('🖐️', 'mâna'),
  _BodyPart('🦵', 'piciorul'),
  _BodyPart('🦶', 'talpa'),
  _BodyPart('🦷', 'dintele'),
  _BodyPart('👅', 'limba'),
  _BodyPart('💪', 'brațul'),
];

/// Corpul meu (LRC3, catalog #40 → treapta LRC3): „Arată nasul”.
class CorpulGame extends ChoiceGame {
  const CorpulGame()
      : super(
          id: 'corpul',
          name: 'Corpul meu',
          emoji: '👃',
          description: 'Arată părțile corpului',
          subject: Subject.stiinte,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Ascultă și arată.',
        rounds: [
          for (final t in _targets(ctx, _body, 8))
            ChoiceRound(
              prompt: 'Arată ${t.word}',
              speak: ['Arată ${t.word}'],
              visuals: [TextVisual(t.word)],
              hint: 'Acesta este ${t.word}.',
              choices: [
                for (final o in [t, ...ctx.sample(_body.where((b) => b != t).toList(), 4)]..shuffle(ctx.random))
                  Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == t),
              ],
            ),
        ],
      );
}

/// Intrusul (POT6, catalog #26): mai multe obiecte din aceeași grupă și unul din altă grupă.
/// Mai adânc = mai multe obiecte printre care se ascunde intrusul (port din `intrusul.js`).
class IntrusulGame extends ChoiceGame {
  const IntrusulGame()
      : super(
          id: 'intrusul',
          name: 'Intrusul',
          emoji: '🔎',
          description: 'Găsește ce nu se potrivește',
          subject: Subject.forme,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final same = (1 + ctx.difficulty.tier).clamp(2, 4);
    final groups = [
      for (final g in ObjectGroupKind.values)
        if (objectWords.where((o) => o.group == g).length >= same) g,
    ];
    return Lesson(
      title: name,
      instruction: 'Alege obiectul care nu se potrivește.',
      rounds: [
        for (final g in _targets(ctx, groups, 8)) _round(ctx, g, same),
      ],
    );
  }

  ChoiceRound _round(GameContext ctx, ObjectGroupKind g, int same) {
    final members = ctx.sample(objectWords.where((o) => o.group == g).toList(), same);
    // Fructele și mâncarea, animalele de casă și cele sălbatice sunt prea apropiate pentru
    // un intrus clar: intrusul vine dintr-o grupă evident diferită.
    bool close(ObjectGroupKind a, ObjectGroupKind b) =>
        a == b ||
        {a, b}.containsAll({ObjectGroupKind.fructe, ObjectGroupKind.mancare}) ||
        {a, b}.containsAll({ObjectGroupKind.animaleCasa, ObjectGroupKind.animaleSalbatice}) ||
        {a, b}.containsAll({ObjectGroupKind.animaleSalbatice, ObjectGroupKind.gaze}) ||
        {a, b}.containsAll({ObjectGroupKind.animaleCasa, ObjectGroupKind.gaze}) ||
        {a, b}.containsAll({ObjectGroupKind.jucarii, ObjectGroupKind.lucruri});
    final intruder = ctx.pick(objectWords.where((o) => !close(o.group, g)).toList());
    return ChoiceRound(
      prompt: 'Care nu se potrivește?',
      fixedChoices: true,
      hint: 'Celelalte sunt ${_groupNames[g]}. ${_cap(intruder.word)} nu.',
      choices: [
        for (final o in [...members, intruder]..shuffle(ctx.random))
          Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == intruder),
      ],
    );
  }
}

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

/// Umbre (POT3, catalog #10): obiect ↔ umbra lui, alternat. „Găsește umbra” (variantele sunt
/// siluete) și „Al cui e umbra?” (stimulul e o siluetă, variantele colorate). De la tier 4,
/// distractorii sunt din aceeași grupă — siluete mai asemănătoare (figură–fond).
class UmbreGame extends ChoiceGame {
  const UmbreGame()
      : super(
          id: 'umbre',
          name: 'Umbre',
          emoji: '👤',
          description: 'Găsește umbra potrivită',
          subject: Subject.forme,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final similar = ctx.difficulty.tier >= 4;
    return Lesson(
      title: name,
      instruction: 'Potrivește obiectul cu umbra lui.',
      rounds: [
        for (final (i, t) in _targets(ctx, objectWords, 8).indexed)
          if (i.isEven)
            ChoiceRound(
              prompt: 'Găsește umbra',
              speak: ['Găsește umbra.'],
              visuals: [EmojiVisual(t.emoji)],
              hint: 'Umbra are aceeași formă ca ${t.word}.',
              choices: [
                for (final o in [t, ..._distractors(ctx, t, objectWords, similar: similar)]
                  ..shuffle(ctx.random))
                  Choice(art: o.emoji, id: o.word, silhouette: true, speak: o.word, correct: o == t),
              ],
            )
          else
            ChoiceRound(
              prompt: 'Al cui e umbra?',
              speak: ['Al cui e umbra?'],
              visuals: [SilhouetteVisual(t.emoji)],
              hint: 'Este umbra: ${t.word}.',
              choices: [
                for (final o in [t, ..._distractors(ctx, t, objectWords, similar: similar)]
                  ..shuffle(ctx.random))
                  Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == t),
              ],
            ),
      ],
    );
  }
}

class _Sized {
  const _Sized(this.emoji, this.word, {this.feminine = false});
  final String emoji;
  final String word;
  final bool feminine;

  String adjective(bool big) => big ? 'mare' : (feminine ? 'mică' : 'mic');
}

const _sizedObjects = [
  _Sized('🍎', 'mărul'),
  _Sized('⚽', 'mingea', feminine: true),
  _Sized('🧸', 'ursulețul'),
  _Sized('🎈', 'balonul'),
  _Sized('🐶', 'câinele'),
  _Sized('🐱', 'pisica', feminine: true),
  _Sized('🚗', 'mașina', feminine: true),
  _Sized('🏠', 'casa', feminine: true),
  _Sized('⭐', 'steaua', feminine: true),
  _Sized('🐘', 'elefantul'),
];

class _Colored {
  const _Colored(this.emoji, this.word, this.color);
  final String emoji;
  final String word;

  /// Culoarea, acordată cu obiectul („cartea verde”, „cercul roșu”).
  final String color;

  String get phrase => '$word $color';
}

const _coloredObjects = [
  _Colored('📕', 'cartea', 'roșie'),
  _Colored('📗', 'cartea', 'verde'),
  _Colored('📘', 'cartea', 'albastră'),
  _Colored('📙', 'cartea', 'portocalie'),
  _Colored('🔴', 'cercul', 'roșu'),
  _Colored('🔵', 'cercul', 'albastru'),
  _Colored('🟢', 'cercul', 'verde'),
  _Colored('🟡', 'cercul', 'galben'),
  _Colored('🟥', 'pătratul', 'roșu'),
  _Colored('🟦', 'pătratul', 'albastru'),
  _Colored('🟩', 'pătratul', 'verde'),
  _Colored('🟨', 'pătratul', 'galben'),
];

/// Culoarea fără acord (pentru a găsi „același roșu” la alt obiect).
String _colorRoot(String c) => switch (c) {
      'roșie' || 'roșu' => 'rosu',
      'albastră' || 'albastru' => 'albastru',
      'galbenă' || 'galben' => 'galben',
      _ => c,
    };

/// Mare, mic, roșu (LRC4, catalog #16 `mingea-rosie`): instrucțiuni cu un atribut —
/// „Arată mărul mic”, „Arată cartea verde”. Tier 1–3: doar mărimea, același obiect mare / mic.
/// De la tier 4 și culoarea, iar distractorii au **doar unul** dintre atribute corect
/// (alt obiect cu aceeași mărime / culoare, același obiect cu altă mărime / culoare).
class AtributeGame extends ChoiceGame {
  const AtributeGame()
      : super(
          id: 'mingea-rosie',
          name: 'Mare, mic, roșu',
          emoji: '📕',
          description: 'Ascultă cum e și arată',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    return Lesson(
      title: name,
      instruction: 'Ascultă bine cum este și arată.',
      rounds: [
        for (var i = 0; i < 8; i++)
          if (tier < 4 || i.isEven) _sizeRound(ctx, tier) else _colorRound(ctx),
      ],
    );
  }

  ChoiceRound _sizeRound(GameContext ctx, int tier) {
    final t = ctx.pick(_sizedObjects);
    final big = ctx.random.nextBool();
    final other = ctx.pick(_sizedObjects.where((o) => o != t).toList());
    Choice option(_Sized o, bool isBig, {bool correct = false}) {
      final phrase = '${o.word} ${o.adjective(isBig)}';
      return Choice(art: o.emoji, scale: isBig ? 1 : 0.5, id: phrase, speak: phrase, correct: correct);
    }

    final phrase = '${t.word} ${t.adjective(big)}';
    return ChoiceRound(
      prompt: 'Arată $phrase',
      speak: ['Arată $phrase'],
      visuals: [TextVisual(phrase)],
      hint: 'Acesta este $phrase.',
      fixedChoices: true,
      choices: [
        option(t, big, correct: true),
        option(t, !big),
        if (tier >= 2) option(other, big),
        if (tier >= 3) option(other, !big),
      ]..shuffle(ctx.random),
    );
  }

  ChoiceRound _colorRound(GameContext ctx) {
    final t = ctx.pick(_coloredObjects);
    final sameFamily = _coloredObjects.where((o) => o.word == t.word && o != t).toList();
    final sameColor = _coloredObjects
        .where((o) => o.word != t.word && _colorRoot(o.color) == _colorRoot(t.color))
        .toList();
    final options = [t, ...ctx.sample(sameFamily, 2), ...ctx.sample(sameColor, 1)]
      ..shuffle(ctx.random);
    return ChoiceRound(
      prompt: 'Arată ${t.phrase}',
      speak: ['Arată ${t.phrase}'],
      visuals: [TextVisual(t.phrase)],
      hint: 'Aceasta este ${t.phrase}.',
      fixedChoices: true,
      choices: [
        for (final o in options) Choice(art: o.emoji, id: o.phrase, speak: o.phrase, correct: o == t),
      ],
    );
  }
}

class _Sound {
  const _Sound(this.emoji, this.who, this.sound, {this.farm = false});
  final String emoji;

  /// Cine face sunetul (articulat).
  final String who;

  /// Sunetul, cum îl spune vocea („miau”).
  final String sound;

  /// Animal de la fermă (distractorii asemănători vin tot de aici).
  final bool farm;
}

const _sounds = [
  _Sound('🐶', 'câinele', 'ham, ham', farm: true),
  _Sound('🐱', 'pisica', 'miau', farm: true),
  _Sound('🐄', 'vaca', 'muuu', farm: true),
  _Sound('🐑', 'oaia', 'beee', farm: true),
  _Sound('🦆', 'rața', 'mac, mac', farm: true),
  _Sound('🐓', 'cocoșul', 'cucurigu', farm: true),
  _Sound('🐖', 'porcul', 'guiț, guiț', farm: true),
  _Sound('🐥', 'puiul', 'piu, piu', farm: true),
  _Sound('🐎', 'calul', 'ihahaha', farm: true),
  _Sound('🐝', 'albina', 'bzzz'),
  _Sound('🦉', 'bufnița', 'uhu, uhu'),
  _Sound('🐍', 'șarpele', 'sss'),
  _Sound('🚗', 'mașina', 'tuuut, tuuut'),
  _Sound('🥁', 'toba', 'bum, bum'),
];

/// Ce se aude? (COM1, catalog #22): vocea spune un sunet („Cine face miau?”), copilul alege
/// cine îl face. Asocierea sunet → sursă, înaintea discriminării sunetelor reale. Tier 1–3:
/// distractori din alte categorii; de la tier 4, tot animale de la fermă (mai apropiate).
class CeSeAudeGame extends ChoiceGame {
  const CeSeAudeGame()
      : super(
          id: 'ce-se-aude',
          name: 'Ce se aude?',
          emoji: '👂',
          description: 'Cine face sunetul?',
          subject: Subject.stiinte,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final similar = ctx.difficulty.tier >= 4;
    return Lesson(
      title: name,
      instruction: 'Ascultă sunetul și arată cine îl face.',
      rounds: [
        for (final t in _targets(ctx, _sounds, 8))
          ChoiceRound(
            prompt: 'Cine face „${t.sound}”?',
            speak: ['Cine face ${t.sound}?'],
            visuals: const [EmojiVisual('👂')],
            hint: '${_cap(t.who)} face ${t.sound}.',
            choices: [
              for (final o in [
                t,
                ...ctx.sample(
                  _sounds
                      .where((o) => o != t && (!similar || !t.farm || o.farm))
                      .toList(),
                  4,
                ),
              ]..shuffle(ctx.random))
                Choice(art: o.emoji, id: o.who, speak: o.sound, correct: o == t),
            ],
          ),
      ],
    );
  }
}

class _Weather {
  const _Weather(this.id, this.emoji, this.when, this.wear);
  final String id;
  final String emoji;

  /// „Afară plouă.”
  final String when;

  /// Ce se potrivește (emoji → nume articulat).
  final Map<String, String> wear;
}

const _weathers = [
  _Weather('ploaie', '🌧️', 'Afară plouă.', {'☂️': 'umbrela', '🥾': 'cizmele', '🧥': 'geaca'}),
  _Weather('zapada', '❄️', 'Afară ninge.', {'🧤': 'mănușile', '🧣': 'fularul', '🧥': 'geaca', '🥾': 'cizmele'}),
  _Weather('soare', '☀️', 'Afară e cald și soare.', {'🩳': 'pantalonii scurți', '🕶️': 'ochelarii de soare', '👒': 'pălăria'}),
];

/// Ce îmbrac? (AUT3, catalog #45 `ne-imbracam`, varianta „alege”): vremea de afară → ce haină
/// se potrivește. Distractorii sunt haine pentru altă vreme (ex. fular când e cald). Tier 1–2:
/// două variante, apoi trei-patru.
class CeImbracGame extends ChoiceGame {
  const CeImbracGame()
      : super(
          id: 'ce-imbrac',
          name: 'Ce îmbrac?',
          emoji: '🧥',
          description: 'Alege haina potrivită vremii',
          subject: Subject.stiinte,
          gradeCodes: 'G12',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Uită-te ce vreme e și alege ce îmbraci.',
        rounds: [
          for (final w in _targets(ctx, _weathers, 8)) _round(ctx, w),
        ],
      );

  ChoiceRound _round(GameContext ctx, _Weather w) {
    final good = ctx.pick(w.wear.entries.toList());
    // Distractori: haine potrivite DOAR pentru altă vreme.
    final wrong = {
      for (final o in _weathers.where((x) => x != w))
        for (final e in o.wear.entries)
          if (!w.wear.containsKey(e.key)) e.key: e.value,
    }.entries.toList();
    final options = [good, ...ctx.sample(wrong, 4)]..shuffle(ctx.random);
    return ChoiceRound(
      prompt: 'Ce îmbraci?',
      speak: [w.when, 'Ce îmbraci?'],
      visuals: [EmojiVisual(w.emoji), SceneVisual(w.when)],
      hint: 'Când ${w.when.substring(6).replaceAll('.', '')}, iei ${good.value}.',
      choices: [
        for (final o in options) Choice(art: o.key, id: o.value, speak: o.value, correct: o == good),
      ],
    );
  }
}


/// Sunetul de început al unui cuvânt (litera mare), sau null când nu e un sunet simplu
/// (ce/ci, ge/gi, che/chi, ghe/ghi — se citesc altfel decât litera).
String? firstSound(String word) {
  final w = word.toLowerCase();
  if (RegExp(r'^(c|g)h?[ei]').hasMatch(w)) return null;
  return w[0].toUpperCase();
}

/// Perechi de sunete apropiate (se confundă ușor) — distractorii grei.
const _closeSounds = {
  'M': 'N', 'N': 'M', 'B': 'P', 'P': 'B', 'D': 'T', 'T': 'D',
  'F': 'V', 'V': 'F', 'S': 'Ș', 'Ș': 'S', 'C': 'G', 'G': 'C',
};

/// Primul sunet (COM4, catalog #23): „Ce începe cu M?” — copilul alege poza al cărei nume
/// începe cu sunetul cerut. Conștiința fonologică, pregătirea citirii. Tier 1–2: două poze;
/// de la tier 4 un distractor începe cu un sunet apropiat (m/n, b/p, d/t…).
class PrimulSunetGame extends ChoiceGame {
  const PrimulSunetGame()
      : super(
          id: 'primul-sunet',
          name: 'Primul sunet',
          emoji: '🅰️',
          description: 'Cu ce sunet începe?',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) {
    final pool = objectWords.where((o) => firstSound(o.word) != null).toList();
    final close = ctx.difficulty.tier >= 4;
    return Lesson(
      title: name,
      instruction: 'Alege ce începe cu sunetul.',
      rounds: [for (final t in _targets(ctx, pool, 8)) _round(ctx, t, pool, close: close)],
    );
  }

  ChoiceRound _round(GameContext ctx, ObjectWord t, List<ObjectWord> pool, {required bool close}) {
    final sound = firstSound(t.word)!;
    final others = pool.where((o) => firstSound(o.word) != sound).toList()..shuffle(ctx.random);
    final near = close
        ? others.where((o) => firstSound(o.word) == _closeSounds[sound]).take(1).toList()
        : <ObjectWord>[];
    // Distractori cu sunete diferite între ei (fără două poze cu același început).
    final seen = {sound, ...near.map((o) => firstSound(o.word)!)};
    final rest = <ObjectWord>[];
    for (final o in others) {
      if (rest.length + near.length >= 4) break;
      if (seen.add(firstSound(o.word)!)) rest.add(o);
    }
    return ChoiceRound(
      prompt: 'Ce începe cu $sound?',
      speak: ['Ce începe cu $sound?'],
      visuals: [TextVisual(sound)],
      hint: '${_cap(t.word)} începe cu $sound.',
      choices: [
        for (final o in [t, ...near, ...rest]..shuffle(ctx.random))
          Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == t),
      ],
    );
  }
}


/// Unde e ursulețul? (LRC6, catalog #17 `unde-e-ursul`): „Arată ursulețul sub masă.” Variantele
/// sunt mici scene cu același obiect în locuri diferite față de același reper. Tier 1–2: pe / sub
/// (două variante); tier 3–4: + în, lângă; de la tier 5: + deasupra (pe vs deasupra — apropiate).
class UndeEUrsulGame extends ChoiceGame {
  const UndeEUrsulGame()
      : super(
          id: 'unde-e-ursul',
          name: 'Unde e ursulețul?',
          emoji: '🧸',
          description: 'Pe, sub, în, lângă',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  static const _things = [('🧸', 'ursulețul'), ('⚽', 'mingea'), ('🐱', 'pisica'), ('🐶', 'cățelul'), ('🍎', 'mărul')];

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final relations = tier <= 2
        ? const [Relation.pe, Relation.sub]
        : (tier <= 4
            ? const [Relation.pe, Relation.sub, Relation.inauntru, Relation.langa]
            : Relation.values);
    return Lesson(
      title: name,
      instruction: 'Ascultă unde e și arată.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, relations)],
    );
  }

  ChoiceRound _round(GameContext ctx, List<Relation> relations) {
    final (emoji, word) = ctx.pick(_things);
    final target = ctx.pick(relations);
    // „În” doar la cutie (în masă nu se poate); „sub cutie” sună ciudat, deci la cutie fără „sub”.
    bool fits(Relation r, Landmark l) =>
        l == Landmark.cutie ? r != Relation.sub : r != Relation.inauntru;
    // Reperul la care ținta are sens și rămân cel puțin două variante.
    final landmarks = [
      for (final l in Landmark.values)
        if (fits(target, l) && relations.where((r) => fits(r, l)).length >= 2) l,
    ];
    final landmark = ctx.pick(landmarks);
    // Câte variante: 2 (tier mic) → 4, cât permite reperul.
    final want = min(relations.length, 4);
    final options = [
      target,
      ...ctx.sample(relations.where((r) => r != target && fits(r, landmark)).toList(), want - 1),
    ]..shuffle(ctx.random);
    final phrase = '$word ${target.word} ${landmark.word}';
    return ChoiceRound(
      prompt: 'Arată $phrase',
      speak: ['Arată $phrase'],
      hint: 'Uite: $phrase.',
      stimulusId: target.name,
      fixedChoices: true,
      choices: [
        for (final r in options)
          Choice(
            placement: Placement(emoji, r, landmark),
            id: r.name,
            speak: '${r.word} ${landmark.word}',
            correct: r == target,
          ),
      ],
    );
  }
}


/// Sus, jos, stânga, dreapta (LRC6b, catalog #37 `pozitii`): un dulap cu obiecte în
/// compartimente; „Ce e sus?” — copilul arată obiectul. Stânga și dreapta sunt ale copilului
/// (cum se uită la ecran). Tier 1–2: sus / jos (2 rafturi); tier 3–4: stânga / dreapta;
/// tier 5–6: crucea (sus, jos, stânga, dreapta, mijloc); de la tier 7: dulapul 3 × 3, cu
/// colțurile („sus, în stânga”).
class PozitiiGame extends ChoiceGame {
  const PozitiiGame()
      : super(
          id: 'pozitii',
          name: 'Sus, jos, stânga, dreapta',
          emoji: '↔️',
          description: 'Ce e sus? Ce e în stânga?',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  /// Numele locului din dulapul [rows] × [cols], pentru compartimentul ([r], [c]).
  static String place(int rows, int cols, int r, int c) {
    final v = rows == 1 ? '' : (r == 0 ? 'sus' : (r == rows - 1 ? 'jos' : ''));
    final h = cols == 1 ? '' : (c == 0 ? 'în stânga' : (c == cols - 1 ? 'în dreapta' : ''));
    if (v.isEmpty && h.isEmpty) return 'în mijloc';
    if (v.isEmpty) return h;
    if (h.isEmpty) return v;
    return '$v, $h';
  }

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    return Lesson(
      title: name,
      instruction: 'Ascultă și arată.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, tier, i)],
    );
  }

  ChoiceRound _round(GameContext ctx, int tier, int i) {
    final (rows, cols, cells) = switch (tier) {
      <= 2 => (2, 1, [0, 1]),
      <= 4 => (1, 2, [0, 1]),
      // La trecere amestecăm și rundele vechi (sus / jos) printre cele noi.
      <= 6 => i.isEven ? (3, 3, [1, 3, 4, 5, 7]) : (3, 3, [1, 3, 5, 7]),
      _ => (3, 3, ctx.sample([0, 1, 2, 3, 4, 5, 6, 7, 8], 6)),
    };
    final things = ctx.sample(objectWords, cells.length);
    final map = {for (final (k, cell) in cells.indexed) cell: things[k].emoji};
    final target = ctx.pick(cells);
    final where = place(rows, cols, target ~/ cols, target % cols);
    // Variantele: obiectul întrebat + altele din dulap (cel mult 4 în total).
    final others = ctx.sample([for (final c in cells) if (c != target) c], min(3, cells.length - 1));
    return ChoiceRound(
      prompt: 'Ce e $where?',
      speak: ['Ce e $where?'],
      hint: 'Uite ce e $where.',
      stimulusId: where,
      fixedChoices: true,
      visuals: [ShelfVisual(rows, cols, map, target: target)],
      choices: [
        for (final c in [target, ...others]..shuffle(ctx.random))
          Choice(
            art: map[c],
            id: place(rows, cols, c ~/ cols, c % cols),
            speak: things[cells.indexOf(c)].word,
            correct: c == target,
          ),
      ],
    );
  }
}

/// Acțiunile pentru „Ce face?”: iconița (ilustrația pictată `actions/…` în aplicație) și
/// verbul („doarme”).
const actions = [
  ('🛌', 'doarme'),
  ('🥣', 'mănâncă'),
  ('🥤', 'bea'),
  ('🏃', 'aleargă'),
  ('📚', 'citește'),
  ('🖍️', 'desenează'),
  ('🎤', 'cântă'),
  ('👐', 'se spală pe mâini'),
];

/// Ce face? (LRC3b, catalog #15 `ce-face`): „Cine doarme?” — copilul arată imaginea cu
/// acțiunea. Verbe receptive. Tier 1–2: două variante, apoi până la cinci.
class CeFaceGame extends ChoiceGame {
  const CeFaceGame()
      : super(
          id: 'ce-face',
          name: 'Ce face?',
          emoji: '🏃',
          description: 'Arată cine doarme, cine mănâncă',
          subject: Subject.romana,
          gradeCodes: 'G1',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Ascultă și arată.',
        rounds: [
          for (final (emoji, verb) in _targets(ctx, actions, 8))
            ChoiceRound(
              prompt: 'Cine $verb?',
              speak: ['Cine $verb?'],
              hint: 'Copilul acesta $verb.',
              choices: [
                for (final (e, v) in [
                  (emoji, verb),
                  ...ctx.sample(actions.where((a) => a.$1 != emoji).toList(), 4),
                ]..shuffle(ctx.random))
                  Choice(art: e, id: v, speak: v, correct: e == emoji),
              ],
            ),
        ],
      );
}
