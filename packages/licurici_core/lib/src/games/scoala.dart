/// Jocurile „școlare” portate din prototip (`legacy/electron/src/games/*.js`, conținutul din
/// `data/school.js`, `data/romana.js`), mecanica `choice`: științe (anotimpuri, habitate),
/// citire (silabe, cuvinte, plural) și matematică (zeci și unități, înmulțire).
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';
import 'content.dart' as content;

// ---------------------------------------------------------------- conținut

class _SylWord {
  const _SylWord(this.word, this.emoji, this.syllables);
  final String word;
  final String emoji;
  final List<String> syllables;
}

const _words = [
  _SylWord('măr', '🍎', ['măr']),
  _SylWord('urs', '🐻', ['urs']),
  _SylWord('stea', '⭐', ['stea']),
  _SylWord('casă', '🏠', ['ca', 'să']),
  _SylWord('floare', '🌸', ['floa', 're']),
  _SylWord('soare', '☀️', ['soa', 're']),
  _SylWord('balon', '🎈', ['ba', 'lon']),
  _SylWord('copac', '🌳', ['co', 'pac']),
  _SylWord('lună', '🌙', ['lu', 'nă']),
  _SylWord('carte', '📖', ['car', 'te']),
  _SylWord('tobă', '🥁', ['to', 'bă']),
  _SylWord('banană', '🍌', ['ba', 'na', 'nă']),
  _SylWord('pisică', '🐱', ['pi', 'si', 'că']),
  _SylWord('mașină', '🚗', ['ma', 'și', 'nă']),
  _SylWord('elefant', '🐘', ['e', 'le', 'fant']),
  _SylWord('iepure', '🐇', ['ie', 'pu', 're']),
  _SylWord('girafă', '🦒', ['gi', 'ra', 'fă']),
  _SylWord('căpșună', '🍓', ['căp', 'șu', 'nă']),
  _SylWord('albină', '🐝', ['al', 'bi', 'nă']),
  _SylWord('broscuță', '🐢', ['bros', 'cu', 'ță']),
  _SylWord('fluturaș', '🦋', ['flu', 'tu', 'raș']),
];

class _Habitat {
  const _Habitat(this.name, this.emoji, this.animals);
  final String name;
  final String emoji;
  final List<String> animals;
}

const _habitats = [
  _Habitat('la fermă', '🚜', ['🐄', '🐖', '🐓', '🐑', '🐎', '🦆']),
  _Habitat('în junglă', '🌴', ['🦁', '🐯', '🐒', '🦜']),
  _Habitat('în ocean', '🌊', ['🐙', '🦈', '🐳', '🦀', '🐬']),
  _Habitat('în pădure', '🌲', ['🦊', '🐻', '🦉', '🦌', '🐿️', '🦔']),
  _Habitat('la pol', '❄️', ['🐧', '🐻‍❄️', '🦭']),
];

class _Season {
  const _Season(this.name, this.emoji, this.items);
  final String name;
  final String emoji;
  final List<String> items;
}

const _seasons = [
  _Season('primăvara', '🌷', ['🌷', '🐣', '🌱', '🌦️']),
  _Season('vara', '☀️', ['🏖️', '🍉', '🩳', '🍦']),
  _Season('toamna', '🍂', ['🍂', '🍇', '🌰', '☔']),
  _Season('iarna', '❄️', ['⛄', '🎿', '🧣', '🧤']),
];

class _Plural {
  const _Plural(this.singular, this.plural, this.emoji);
  final String singular;
  final String plural;
  final String emoji;
}

const _plurals = [
  _Plural('măr', 'mere', '🍎'),
  _Plural('casă', 'case', '🏠'),
  _Plural('floare', 'flori', '🌸'),
  _Plural('copil', 'copii', '🧒'),
  _Plural('carte', 'cărți', '📖'),
  _Plural('pisică', 'pisici', '🐱'),
  _Plural('câine', 'câini', '🐶'),
  _Plural('stea', 'stele', '⭐'),
  _Plural('scaun', 'scaune', '🪑'),
  _Plural('creion', 'creioane', '✏️'),
  _Plural('minge', 'mingi', '⚽'),
  _Plural('pom', 'pomi', '🌳'),
  _Plural('balon', 'baloane', '🎈'),
  _Plural('ou', 'ouă', '🥚'),
];

// ---------------------------------------------------------------- științe

/// Anotimpuri (port din `anotimpuri.js`): în ce anotimp se potrivește lucrul arătat?
class AnotimpuriGame extends ChoiceGame {
  const AnotimpuriGame()
      : super(
          id: 'anotimpuri',
          name: 'Anotimpuri',
          emoji: '🍂',
          description: 'În ce anotimp?',
          subject: Subject.stiinte,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Alege anotimpul potrivit.',
        rounds: [
          for (var i = 0; i < 8; i++) _round(ctx),
        ],
      );

  ChoiceRound _round(GameContext ctx) {
    final s = ctx.pick(_seasons);
    final item = ctx.pick(s.items);
    return ChoiceRound(
      prompt: 'În ce anotimp?',
      speak: ['În ce anotimp?'],
      visuals: [EmojiVisual(item)],
      hint: 'Acesta e un semn al anotimpului: ${s.name}.',
      // Mereu toate cele patru anotimpuri, în aceeași ordine a anului.
      fixedChoices: true,
      choices: [
        for (final o in _seasons)
          Choice(label: _cap(o.name), art: o.emoji, id: o.name, speak: o.name, correct: o == s),
      ],
    );
  }
}

/// Unde trăiește? (port din `habitate.js`): animalul și mediul lui.
class HabitateGame extends ChoiceGame {
  const HabitateGame()
      : super(
          id: 'habitate',
          name: 'Unde trăiește?',
          emoji: '🌲',
          description: 'Fiecare animal la casa lui',
          subject: Subject.stiinte,
          gradeCodes: 'G1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Unde trăiește animalul?',
        rounds: [
          for (var i = 0; i < 8; i++) _round(ctx),
        ],
      );

  ChoiceRound _round(GameContext ctx) {
    final h = ctx.pick(_habitats);
    final animal = ctx.pick(h.animals);
    return ChoiceRound(
      prompt: 'Unde trăiește?',
      speak: ['Unde trăiește?'],
      visuals: [EmojiVisual(animal)],
      hint: 'Acest animal trăiește ${h.name}.',
      choices: [
        for (final o in [h, ...ctx.sample(_habitats.where((x) => x != h).toList(), 4)]..shuffle(ctx.random))
          Choice(label: _cap(o.name), art: o.emoji, id: o.name, speak: o.name, correct: o == h),
      ],
    );
  }
}

// ---------------------------------------------------------------- citire

/// Silabe (port din `silabe.js`): câte silabe are cuvântul? Bătăi din palme, ca la școală.
class SilabeGame extends ChoiceGame {
  const SilabeGame()
      : super(
          id: 'silabe',
          name: 'Silabe',
          emoji: '👏',
          description: 'Câte silabe are cuvântul?',
          subject: Subject.romana,
          gradeCodes: '12',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Bate din palme pentru fiecare silabă.',
        rounds: [
          for (var i = 0; i < 8; i++) _round(ctx),
        ],
      );

  ChoiceRound _round(GameContext ctx) {
    final w = ctx.pick(_words);
    final n = w.syllables.length;
    return ChoiceRound(
      prompt: 'Câte silabe are „${w.word}”?',
      speak: ['Câte silabe are cuvântul ${w.word}?'],
      visuals: [EmojiVisual(w.emoji), TextVisual(w.word)],
      hint: '${_cap(w.word)}: ${w.syllables.join(' – ')}. Sunt $n.',
      fixedChoices: true,
      choices: [
        for (var k = 1; k <= 3; k++) Choice(label: '$k', correct: k == n),
      ],
    );
  }
}

/// Citește cuvântul (port din `cuvinte.js`): cuvântul scris → imaginea potrivită.
class CuvinteGame extends ChoiceGame {
  const CuvinteGame()
      : super(
          id: 'cuvinte',
          name: 'Citește cuvântul',
          emoji: '📖',
          description: 'Citește și alege imaginea',
          subject: Subject.romana,
          gradeCodes: '1234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Citește cuvântul și alege imaginea.',
        rounds: [
          for (var i = 0; i < 8; i++) _round(ctx),
        ],
      );

  ChoiceRound _round(GameContext ctx) {
    final w = ctx.pick(_words);
    return ChoiceRound(
      prompt: 'Citește și alege',
      // Nu rostim cuvântul: aici exersăm citirea; vocea doar dă sarcina.
      speak: ['Citește și alege imaginea.'],
      visuals: [TextVisual(w.word)],
      hint: '„${w.word}” arată așa.',
      choices: [
        for (final o in [w, ...ctx.sample(_words.where((x) => x != w).toList(), 4)]..shuffle(ctx.random))
          Choice(art: o.emoji, id: o.word, speak: o.word, correct: o == w),
      ],
    );
  }
}

/// Singular și plural (port din `plural.js`): cum spui la mai multe?
class PluralGame extends ChoiceGame {
  const PluralGame()
      : super(
          id: 'plural',
          name: 'Unul și mai mulți',
          emoji: '🍎',
          description: 'Cum spui la mai multe?',
          subject: Subject.romana,
          gradeCodes: '234',
        );

  @override
  Lesson generate(GameContext ctx) => Lesson(
        title: name,
        instruction: 'Cum spui când sunt mai multe?',
        rounds: [
          for (var i = 0; i < 8; i++) _round(ctx),
        ],
      );

  ChoiceRound _round(GameContext ctx) {
    final p = ctx.pick(_plurals);
    return ChoiceRound(
      prompt: 'Un ${p.singular}… mai multe?',
      speak: ['Cum spui la mai multe?'],
      visuals: [ObjectsVisual([ObjectGroup(p.emoji, 1), ObjectGroup(p.emoji, 3)])],
      hint: 'Mai multe: ${p.plural}.',
      choices: [
        for (final o in [p.plural, ...ctx.sample(_plurals.where((x) => x != p).map((x) => x.plural).toList(), 4)]
          ..shuffle(ctx.random))
          Choice(label: o, correct: o == p.plural),
      ],
    );
  }
}

// ---------------------------------------------------------------- matematică

/// Zeci și unități (port din `zeci.js`): bețișoare de zece și bile de unu → numărul.
/// Distractorul clasic: cifrele inversate (34 ↔ 43).
class ZeciGame extends ChoiceGame {
  const ZeciGame()
      : super(
          id: 'zeci',
          name: 'Zeci și unități',
          emoji: '🔟',
          description: 'Ce număr este?',
          subject: Subject.matematica,
          gradeCodes: '12',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxT = min(max(2, ctx.difficulty.tier), 9);
    return Lesson(
      title: name,
      instruction: 'Numără zecile și unitățile.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxT)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxT) {
    final t = ctx.intBetween(1, maxT);
    final u = ctx.intBetween(1, 9);
    final n = t * 10 + u;
    final set = <int>{n, if (u != t) u * 10 + t};
    for (var g = 0; set.length < 5 && g < 60; g++) {
      final d = n + ctx.intBetween(-9, 9);
      if (d >= 1 && d <= 99) set.add(d);
    }
    return ChoiceRound(
      prompt: 'Ce număr este?',
      speak: ['Ce număr este?'],
      visuals: [
        // O zece = o cartelă „10”; o unitate = o bilă.
        ObjectsVisual([ObjectGroup('🔟', t), ObjectGroup('🟡', u)], operator: '+'),
      ],
      hint: '$t zeci și $u unități fac $n.',
      stimulusId: '$t-$u',
      choices: [
        for (final v in set.toList()..shuffle(ctx.random)) Choice(label: '$v', correct: v == n),
      ],
    );
  }
}

/// Înmulțim (port din `inmultim.js`): grupe egale de obiecte, apoi doar ecuația.
class InmultimGame extends ChoiceGame {
  const InmultimGame()
      : super(
          id: 'inmultim',
          name: 'Înmulțim',
          emoji: '✖️',
          description: 'Grupe egale',
          subject: Subject.matematica,
          gradeCodes: '234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxF = min(3 + ctx.difficulty.tier, 10);
    return Lesson(
      title: name,
      instruction: 'Câte sunt în total?',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxF)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxF) {
    final a = ctx.intBetween(1, maxF);
    final b = ctx.intBetween(2, min(maxF, 5));
    final prod = a * b;
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Cât fac $a × $b?',
      speak: ['Cât fac', '$a', 'ori', '$b'],
      visuals: [
        if (prod <= 25) ObjectsVisual([for (var g = 0; g < b; g++) ObjectGroup(item, a)]),
        TextVisual('$a × $b = ?', isEquation: true),
      ],
      hint: '$b grupe a câte $a fac $prod.',
      choices: [
        for (final n in numberChoices(ctx, prod, 1, maxF * maxF)) Choice(label: '$n', correct: n == prod),
      ],
    );
  }
}

String _cap(String s) => s[0].toUpperCase() + s.substring(1);


/// Ora citită pe înțelesul copilului: „ora trei”, „trei și jumătate”, „trei și un sfert”,
/// „patru fără un sfert”.
String clockLabel(int h, int m) {
  const names = ['douăsprezece', 'unu', 'două', 'trei', 'patru', 'cinci', 'șase', 'șapte', 'opt',
    'nouă', 'zece', 'unsprezece', 'douăsprezece'];
  final next = h % 12 + 1;
  return switch (m) {
    0 => h == 1 ? 'ora unu' : 'ora ${names[h]}',
    15 => '${names[h]} și un sfert',
    30 => '${names[h]} și jumătate',
    _ => '${names[next]} fără un sfert',
  };
}

/// Ceasul (port din `ceasul.js`): cât e ceasul? Tier 1–2: ore fixe; tier 3–4: și jumătăți;
/// de la tier 5: și sferturi. Distractorii sunt alte ore, scrise la fel.
class CeasulGame extends ChoiceGame {
  const CeasulGame()
      : super(
          id: 'ceasul',
          name: 'Ceasul',
          emoji: '🕒',
          description: 'Cât e ceasul?',
          subject: Subject.timpBani,
          gradeCodes: '1234',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final minutes = tier <= 2 ? const [0] : (tier <= 4 ? const [0, 30] : const [0, 15, 30, 45]);
    return Lesson(
      title: name,
      instruction: 'Acul mic arată ora.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, minutes)],
    );
  }

  ChoiceRound _round(GameContext ctx, List<int> minutes) {
    final h = ctx.intBetween(1, 12);
    final m = ctx.pick(minutes);
    final correct = clockLabel(h, m);
    final options = <String>{correct};
    while (options.length < 5) {
      options.add(clockLabel(ctx.intBetween(1, 12), ctx.pick(minutes)));
    }
    return ChoiceRound(
      prompt: 'Cât e ceasul?',
      speak: ['Cât e ceasul?'],
      visuals: [ClockVisual(h, m)],
      hint: 'Acul mic arată ora. Este $correct.',
      choices: [
        for (final o in options.toList()..shuffle(ctx.random)) Choice(label: _cap(o), id: o, speak: o, correct: o == correct),
      ],
    );
  }
}

/// Împărțim (port din `impartim.js`): împarte obiectele egal în grupe. Cu obiecte cât sunt
/// puține; răspunsul = câte primește fiecare.
class ImpartimGame extends ChoiceGame {
  const ImpartimGame()
      : super(
          id: 'impartim',
          name: 'Împărțim',
          emoji: '➗',
          description: 'Împarte frățește',
          subject: Subject.matematica,
          gradeCodes: '34',
        );

  @override
  Lesson generate(GameContext ctx) {
    final maxQ = min(2 + ctx.difficulty.tier, 10);
    return Lesson(
      title: name,
      instruction: 'Împarte frățește.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, maxQ)],
    );
  }

  ChoiceRound _round(GameContext ctx, int maxQ) {
    final groups = ctx.intBetween(2, 5);
    final each = ctx.intBetween(1, maxQ);
    final total = groups * each;
    final item = ctx.pick(content.mathItems);
    return ChoiceRound(
      prompt: 'Cât face $total : $groups?',
      speak: ['Cât face', '$total', 'împărțit la', '$groups'],
      visuals: [
        if (total <= 20) ObjectsVisual([ObjectGroup(item, total)]),
        TextVisual('$total : $groups = ?', isEquation: true),
      ],
      hint: 'Dacă împărțim $total la $groups, fiecare primește $each.',
      choices: [
        for (final n in numberChoices(ctx, each, 1, maxQ + 3)) Choice(label: '$n', correct: n == each),
      ],
    );
  }
}
