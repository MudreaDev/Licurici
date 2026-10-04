/// Jocurile de potrivire vizuală (POT) și limbaj receptiv (LRC), mecanica `choice`.
/// Toate folosesc aceeași bancă de obiecte, cele mai multe cu ilustrații pictate.
library;

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
