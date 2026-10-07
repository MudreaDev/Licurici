/// Restul jocurilor „școlare” portate din prototip (`legacy/electron/src/games/*.js`,
/// conținutul din `data/school.js`, `data/romana.js`, `data/istorie.js`), mecanica `choice`:
/// banii, tabla înmulțirii, problemele cu text, felul cuvântului, simbolurile țării, trecut
/// și prezent, personalitățile, engleza.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------------- matematică

/// Bani (port din `bani.js`): câți lei sunt? La început bancnote de 1, 2 și 5 lei, puține;
/// apoi și de 10, mai târziu de 20 și 50, și mai multe.
class BaniGame extends ChoiceGame {
  const BaniGame()
      : super(
          id: 'bani',
          name: 'Banii',
          emoji: '🪙',
          description: 'Câți lei sunt?',
          subject: Subject.timpBani,
          gradeCodes: '1234',
        );

  /// Bancnotele folosite la un nivel.
  static List<int> notesFor(int tier) => tier <= 2
      ? const [1, 2, 5]
      : tier <= 4
          ? const [1, 2, 5, 10]
          : const [1, 5, 10, 20, 50];

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final notes = notesFor(tier);
    final most = min(2 + tier ~/ 2, 6);
    return Lesson(
      title: name,
      instruction: 'Câți lei sunt în total?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, notes, most)],
    );
  }

  ChoiceRound _round(GameContext ctx, List<int> values, int most) {
    // Ordonate de la mare la mic, cum le numără un adult: întâi bancnotele mari.
    final notes = [for (var i = ctx.intBetween(2, most); i > 0; i--) ctx.pick(values)]..sort((a, b) => b - a);
    final total = notes.reduce((a, b) => a + b);
    return ChoiceRound(
      prompt: 'Câți lei sunt?',
      speak: ['Câți lei sunt?'],
      visuals: [MoneyVisual(notes)],
      hint: 'Adunăm: ${notes.join(' + ')} = $total lei.',
      stimulusId: notes.join('+'),
      choices: [
        for (final n in numberChoices(ctx, total, 1, total + 10)) Choice(label: '$n lei', id: '$n', correct: n == total),
      ],
    );
  }
}

/// Tabla înmulțirii (port din `tabla.js`): exercițiu rapid, doar ecuația. Factorii cresc
/// cu nivelul, până la 10 × 10.
class TablaGame extends ChoiceGame {
  const TablaGame()
      : super(
          id: 'tabla',
          name: 'Tabla înmulțirii',
          emoji: '✖️',
          description: 'Exercițiu rapid',
          subject: Subject.matematica,
          gradeCodes: '234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxF = min(2 + ctx.difficulty.tier, 10);
    return Lesson(
      title: name,
      instruction: 'Cât fac?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxF)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxF) {
    final a = ctx.intBetween(2, maxF), b = ctx.intBetween(2, maxF);
    final p = a * b;
    // Distractori „din tabla vecină”: a × (b ± 1), (a ± 1) × b — greșelile tipice.
    final set = <int>{p, a * (b + 1), (a + 1) * b, a * (b - 1), (a - 1) * b};
    for (final n in numberChoices(ctx, p, 1, 100)) {
      if (set.length >= 5) break;
      set.add(n);
    }
    final choices = set.toList();
    return ChoiceRound(
      prompt: 'Cât fac $a × $b?',
      speak: ['Cât fac', '$a', 'ori', '$b'],
      visuals: [TextVisual('$a × $b = ?', isEquation: true)],
      hint: '$a × $b = $p',
      stimulusId: '$a×$b',
      choices: [for (final n in choices..shuffle(ctx.random)) Choice(label: '$n', correct: n == p)],
    );
  }
}

const _names = ['Ana', 'Dan', 'Maria', 'Andrei', 'Ioana', 'Radu', 'Elena', 'Mihai'];
const _things = [
  ('mere', '🍎'),
  ('baloane', '🎈'),
  ('flori', '🌸'),
  ('mașinuțe', '🚗'),
  ('căpșuni', '🍓'),
  ('cireșe', '🍒'),
  ('steluțe', '⭐'),
  ('peștișori', '🐟'),
];

/// Probleme cu text (port din `probleme.js`): o mică întâmplare cu numere. La început
/// adunare și scădere cu numere mici; de la nivelul 3 și înmulțire; numerele cresc.
class ProblemeGame extends ChoiceGame {
  const ProblemeGame()
      : super(
          id: 'probleme',
          name: 'Probleme',
          emoji: '💡',
          description: 'Gândește și alege',
          subject: Subject.matematica,
          gradeCodes: '234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final cap = min(10 + tier * 8, 100);
    final kinds = tier >= 3 ? const ['plus', 'minus', 'ori'] : const ['plus', 'minus'];
    return Lesson(
      title: name,
      instruction: 'Citește problema și alege răspunsul.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, kinds[i % kinds.length], cap, tier)],
    );
  }

  ChoiceRound _round(GameContext ctx, String kind, int cap, int tier) {
    final who = ctx.pick(_names);
    final (what, _) = ctx.pick(_things);
    final (String text, int answer, String hint) = switch (kind) {
      'plus' => () {
          final a = ctx.intBetween(2, max(3, (cap * 0.6).round()));
          final b = ctx.intBetween(1, max(2, (cap * 0.4).round()));
          return ('$who are $a $what și mai primește $b. Câte $what are acum?', a + b, '$a + $b = ${a + b}');
        }(),
      'minus' => () {
          final a = ctx.intBetween(3, max(4, cap));
          final b = ctx.intBetween(1, a - 1);
          return ('$who are $a $what și dăruiește $b. Câte $what îi rămân?', a - b, '$a − $b = ${a - b}');
        }(),
      _ => () {
          final g = ctx.intBetween(2, min(2 + tier, 6));
          final each = ctx.intBetween(2, min(2 + tier, 9));
          return ('$g copii au fiecare câte $each $what. Câte $what sunt în total?', g * each, '$g × $each = ${g * each}');
        }(),
    };
    return ChoiceRound(
      prompt: 'Rezolvă problema',
      speak: const ['Citește problema și alege răspunsul.'],
      // Doar textul: pe telefon panoul micșorează tot ce are, iar problema trebuie citită.
      visuals: [SceneVisual(text)],
      hint: hint,
      stimulusId: kind,
      choices: [
        for (final n in numberChoices(ctx, answer, max(0, answer - 10), answer + 12)) Choice(label: '$n', correct: n == answer),
      ],
    );
  }
}

// ---------------------------------------------------------------- limba română

class _Kind {
  const _Kind(this.id, this.label, this.words);
  final String id;
  final String label;

  /// Cuvântul și ilustrația lui (adjectivele n-au).
  final List<(String, String?)> words;
}

const _kinds = [
  _Kind('substantiv', 'Substantiv', [
    ('casă', '🏠'), ('măr', '🍎'), ('câine', '🐶'), ('floare', '🌸'), ('carte', '📖'), //
    ('pisică', '🐱'), ('copil', '🧒'), ('soare', '☀️'), ('școală', '🏫'),
  ]),
  _Kind('verb', 'Verb', [
    ('aleargă', '🏃'), ('mănâncă', '🍽️'), ('doarme', '😴'), ('cântă', '🎤'), ('scrie', '✍️'), //
    ('citește', '📖'), ('zboară', '🦅'), ('înoată', '🏊'), ('râde', '😄'),
  ]),
  _Kind('adjectiv', 'Adjectiv', [
    ('mare', null), ('mic', null), ('roșu', null), ('frumos', null), ('rapid', null), //
    ('vesel', null), ('înalt', null), ('dulce', null), ('nou', null),
  ]),
];

/// Ce fel de cuvânt? (port din `gramatica.js`): substantiv, verb sau adjectiv. Variantele
/// stau mereu în aceeași ordine, ca la tablă.
class GramaticaGame extends ChoiceGame {
  const GramaticaGame()
      : super(
          id: 'gramatica',
          name: 'Ce fel de cuvânt?',
          emoji: '✍️',
          description: 'Substantiv, verb sau adjectiv',
          subject: Subject.romana,
          gradeCodes: '34',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Substantiv, verb sau adjectiv?',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final k = ctx.pick(_kinds);
    final (word, emoji) = ctx.pick(k.words);
    return ChoiceRound(
      prompt: 'Ce fel de cuvânt este?',
      speak: ['Ce fel de cuvânt este?', word],
      visuals: [if (emoji != null) EmojiVisual(emoji), TextVisual(word)],
      hint: '„$word” este ${k.label.toLowerCase()}.',
      stimulusId: word,
      fixedChoices: true,
      choices: [for (final o in _kinds) Choice(label: o.label, id: o.id, speak: o.label, correct: o == k)],
    );
  }
}

// ---------------------------------------------------------------- istorie

const _symbols = [
  ('drapelul României', '🇷🇴'),
  ('drapelul Moldovei', '🇲🇩'),
  ('coroana domnitorului', '👑'),
  ('stema', '🛡️'),
  ('imnul', '🎵'),
  ('cetatea', '🏰'),
];

/// Simbolurile țării (port din `simboluri.js`).
class SimboluriGame extends ChoiceGame {
  const SimboluriGame()
      : super(
          id: 'simboluri',
          name: 'Simbolurile țării',
          emoji: '🏛️',
          description: 'Drapel, stemă, imn',
          subject: Subject.istorie,
          gradeCodes: '34',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Ce este?',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final t = ctx.pick(_symbols);
    final others = ctx.sample(_symbols.where((s) => s != t).toList(), 4);
    return ChoiceRound(
      prompt: 'Ce este?',
      speak: const ['Ce este?'],
      visuals: [EmojiVisual(t.$2)],
      hint: 'Acesta este ${t.$1}.',
      stimulusId: t.$1,
      choices: [
        for (final o in [t, ...others]..shuffle(ctx.random)) Choice(label: _cap(o.$1), id: o.$1, speak: o.$1, correct: o == t),
      ],
    );
  }
}

const _pastPresent = [
  (('lumânarea', '🕯️'), ('becul', '💡')),
  (('trăsura cu cal', '🐎'), ('mașina', '🚗')),
  (('pergamentul', '📜'), ('telefonul', '📱')),
  (('scrisoarea', '✉️'), ('mesajul pe telefon', '📧')),
  (('radioul vechi', '📻'), ('televizorul', '📺')),
  (('pana de scris', '🪶'), ('pixul', '🖊️')),
  (('plugul tras de vaci', '🐄'), ('tractorul', '🚜')),
  (('clepsidra', '⏳'), ('ceasul cu alarmă', '⏰')),
];

/// Trecut și prezent (port din `trecut.js`): dintre două lucruri, care e de demult?
class TrecutGame extends ChoiceGame {
  const TrecutGame()
      : super(
          id: 'trecut',
          name: 'Trecut și prezent',
          emoji: '⏳',
          description: 'Vechi sau nou?',
          subject: Subject.istorie,
          gradeCodes: '1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Care e de demult?',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final (old, now) = ctx.pick(_pastPresent);
    return ChoiceRound(
      prompt: 'Care e de demult?',
      speak: const ['Care e de demult?'],
      visuals: const [],
      hint: '${_cap(old.$1)} e de demult; ${now.$1} e de acum.',
      stimulusId: old.$1,
      fixedChoices: true,
      choices: [
        for (final (o, isOld) in [(old, true), (now, false)]..shuffle(ctx.random))
          Choice(label: _cap(o.$1), art: o.$2, id: o.$1, speak: o.$1, correct: isOld),
      ],
    );
  }
}

const _people = [
  ('Cine a scris poezia „Luceafărul”?', 'Mihai Eminescu'),
  ('Cine a fost domnitorul care a apărat Moldova timp de aproape 50 de ani?', 'Ștefan cel Mare'),
  ('Cine a scris „Amintiri din copilărie”?', 'Ion Creangă'),
  ('Cine a unit prima dată cele trei Țări Române?', 'Mihai Viteazul'),
  ('Cine a fost domnitor și mare cărturar, autorul „Descrierii Moldovei”?', 'Dimitrie Cantemir'),
];

/// Personalități (port din `personalitati.js`): cine a fost? Întrebarea se citește; numele
/// mari ale istoriei și literaturii.
class PersonalitatiGame extends ChoiceGame {
  const PersonalitatiGame()
      : super(
          id: 'personalitati',
          name: 'Personalități',
          emoji: '👑',
          description: 'Oameni mari din istorie',
          subject: Subject.istorie,
          gradeCodes: '34',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Cine a fost?',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final (q, a) = ctx.pick(_people);
    return ChoiceRound(
      prompt: 'Cine a fost?',
      speak: [q],
      visuals: [SceneVisual(q)],
      hint: 'Răspunsul este $a.',
      stimulusId: a,
      choices: [
        for (final (_, name) in [..._people]..shuffle(ctx.random)) Choice(label: name, id: name, speak: name, correct: name == a),
      ],
    );
  }
}

// ---------------------------------------------------------------- engleză

/// Cuvintele în engleză: (română, engleză, ilustrație). Vocea englezească: fraza cu
/// prefixul `en:` (clip generat cu voce în engleză — `tools/gen-voice`).
const englishWords = [
  ('roșu', 'red', '🔴'),
  ('albastru', 'blue', '🔵'),
  ('verde', 'green', '🟢'),
  ('galben', 'yellow', '🟡'),
  ('câine', 'dog', '🐶'),
  ('pisică', 'cat', '🐱'),
  ('pește', 'fish', '🐟'),
  ('pasăre', 'bird', '🐦'),
  ('urs', 'bear', '🐻'),
  ('vulpe', 'fox', '🦊'),
  ('soare', 'sun', '☀️'),
  ('casă', 'house', '🏠'),
  ('măr', 'apple', '🍎'),
  ('carte', 'book', '📖'),
  ('stea', 'star', '⭐'),
  ('minge', 'ball', '⚽'),
];

/// Engleză (port din `engleza.js`): vezi imaginea, auzi cuvântul în engleză și alegi cum se
/// scrie. Câte variante se arată decide nivelul (motorul taie).
class EnglezaGame extends ChoiceGame {
  const EnglezaGame()
      : super(
          id: 'engleza',
          name: 'Engleză',
          emoji: '🌐',
          description: 'Primele cuvinte',
          subject: Subject.engleza,
          gradeCodes: '1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Ascultă și alege cuvântul în engleză.',
        rounds: [for (var i = 0; i < 8; i++) _round(ctx)],
      );

  ChoiceRound _round(GameContext ctx) {
    final t = ctx.pick(englishWords);
    final others = ctx.sample(englishWords.where((w) => w != t).toList(), 4);
    return ChoiceRound(
      prompt: 'Cum se spune în engleză?',
      speak: ['Cum se spune în engleză?', 'en:${t.$2}'],
      visuals: [EmojiVisual(t.$3), TextVisual(t.$1)],
      hint: '„${t.$1}” în engleză este „${t.$2}”.',
      stimulusId: t.$2,
      choices: [
        for (final o in [t, ...others]..shuffle(ctx.random)) Choice(label: o.$2, id: o.$2, speak: 'en:${o.$2}', correct: o == t),
      ],
    );
  }
}
