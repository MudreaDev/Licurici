/// „Pune în ordine” (mecanica `sequence` de imagini): copilul atinge pozele în ordinea în
/// care se întâmplă. Două jocuri pe aceeași mecanică:
///  - **Pașii rutinei** (AUT1–3, catalog #44): spălatul pe mâini, îmbrăcatul, culcarea…
///    (analiza sarcinii — practică bazată pe dovezi);
///  - **Ce urmează?** (COG6, catalog #29): întâmplări scurte (oul → puiul, sămânța → floarea).
/// Nivelurile sunt generate din seed (ADR-027): de la „întâi … apoi …” (2 pași) la 5 pași.
library;

import 'dart:math';

import 'grades.dart';

class OrderStep {
  const OrderStep(this.emoji, this.caption, {this.scale = 1});

  final String emoji;

  /// Mărimea pozei (1 = toată cartela); la „Mare–mijlociu–mic” aceeași poză în mărimi diferite.
  final double scale;

  /// Rostit când pasul e pus la locul lui („Pun săpun.”).
  final String caption;
}

class OrderStory {
  const OrderStory(this.id, this.title, this.steps);

  final String id;

  /// Rostit la început („Spălatul pe mâini”).
  final String title;
  final List<OrderStep> steps;

  /// Pozele diferă doar ca mărime (Mare și mic).
  bool get sized => steps.any((s) => s.scale != 1);
}

const routineStories = [
  OrderStory('maini', 'Ne spălăm pe mâini', [
    OrderStep('🚰', 'Deschid apa.'),
    OrderStep('🧼', 'Pun săpun.'),
    OrderStep('👐', 'Frec mâinile.'),
    OrderStep('💧', 'Clătesc spuma.'),
    OrderStep('🧻', 'Mă șterg pe mâini.'),
  ]),
  OrderStory('imbracat', 'Ne îmbrăcăm', [
    OrderStep('👕', 'Pun tricoul.'),
    OrderStep('👖', 'Pun pantalonii.'),
    OrderStep('🧦', 'Pun șosetele.'),
    OrderStep('👟', 'Pun pantofii.'),
  ]),
  OrderStory('culcare', 'Ne pregătim de culcare', [
    OrderStep('🛁', 'Fac baie.'),
    OrderStep('🪥', 'Mă spăl pe dinți.'),
    OrderStep('📖', 'Ascult o poveste.'),
    OrderStep('🛌', 'Mă culc.'),
  ]),
  OrderStory('masa', 'La masă', [
    OrderStep('🧼', 'Mă spăl pe mâini.'),
    OrderStep('🪑', 'Mă așez la masă.'),
    OrderStep('🍽️', 'Mănânc.'),
    OrderStep('🥛', 'Beau lapte.'),
  ]),
  OrderStory('afara', 'Ieșim afară', [
    OrderStep('🧥', 'Pun geaca.'),
    OrderStep('👟', 'Pun pantofii.'),
    OrderStep('🚪', 'Deschid ușa.'),
    OrderStep('🌳', 'Mă joc în parc.'),
  ]),
];

const storyStories = [
  OrderStory('puiul', 'Puiul', [
    OrderStep('🥚', 'Este un ou.'),
    OrderStep('🐣', 'Puiul iese din ou.'),
    OrderStep('🐥', 'Puiul crește.'),
    OrderStep('🐓', 'S-a făcut cocoș.'),
  ]),
  OrderStory('floarea', 'Floarea', [
    OrderStep('🌱', 'Răsare o plantă.'),
    OrderStep('💧', 'O udăm.'),
    OrderStep('🌷', 'A crescut o floare.'),
  ]),
  OrderStory('omul-de-zapada', 'Omul de zăpadă', [
    OrderStep('❄️', 'Ninge.'),
    OrderStep('⛄', 'Facem un om de zăpadă.'),
    OrderStep('☀️', 'Iese soarele.'),
    OrderStep('💧', 'Omul de zăpadă se topește.'),
  ]),
  OrderStory('ploaia', 'Ploaia', [
    OrderStep('☁️', 'Vin norii.'),
    OrderStep('🌧️', 'Plouă.'),
    OrderStep('🌈', 'Apare curcubeul.'),
  ]),
  OrderStory('ziua', 'O zi', [
    OrderStep('🌅', 'Răsare soarele.'),
    OrderStep('☀️', 'Este zi.'),
    OrderStep('🌇', 'Apune soarele.'),
    OrderStep('🌙', 'Este noapte.'),
  ]),
  OrderStory('tortul', 'Ziua de naștere', [
    OrderStep('🥚', 'Luăm ouă și făină.'),
    OrderStep('🎂', 'Facem un tort.'),
    OrderStep('🕯️', 'Aprindem lumânarea.'),
    OrderStep('🥳', 'Sărbătorim.'),
  ]),
  OrderStory('marul', 'Mărul', [
    OrderStep('🌳', 'Mărul crește în pom.'),
    OrderStep('🍎', 'Culegem mărul.'),
    OrderStep('😋', 'Mâncăm mărul.'),
  ]),
];

/// Mare–mijlociu–mic: același obiect în 5 mărimi (de la mic la mare). Rundele iau 2 → 5
/// dintre ele: cu cât sunt mai multe, cu atât diferențele dintre vecini sunt mai mici.
const sizeStories = [
  OrderStory('marime-ursulețul', 'De la mic la mare', [
    OrderStep('🧸', 'Cel mai mic.', scale: 0.32),
    OrderStep('🧸', 'Mai mare.', scale: 0.48),
    OrderStep('🧸', 'Mai mare.', scale: 0.64),
    OrderStep('🧸', 'Mai mare.', scale: 0.82),
    OrderStep('🧸', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-balonul', 'De la mic la mare', [
    OrderStep('🎈', 'Cel mai mic.', scale: 0.32),
    OrderStep('🎈', 'Mai mare.', scale: 0.48),
    OrderStep('🎈', 'Mai mare.', scale: 0.64),
    OrderStep('🎈', 'Mai mare.', scale: 0.82),
    OrderStep('🎈', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-mărul', 'De la mic la mare', [
    OrderStep('🍎', 'Cel mai mic.', scale: 0.32),
    OrderStep('🍎', 'Mai mare.', scale: 0.48),
    OrderStep('🍎', 'Mai mare.', scale: 0.64),
    OrderStep('🍎', 'Mai mare.', scale: 0.82),
    OrderStep('🍎', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-steaua', 'De la mic la mare', [
    OrderStep('⭐', 'Cel mai mic.', scale: 0.32),
    OrderStep('⭐', 'Mai mare.', scale: 0.48),
    OrderStep('⭐', 'Mai mare.', scale: 0.64),
    OrderStep('⭐', 'Mai mare.', scale: 0.82),
    OrderStep('⭐', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-câinele', 'De la mic la mare', [
    OrderStep('🐶', 'Cel mai mic.', scale: 0.32),
    OrderStep('🐶', 'Mai mare.', scale: 0.48),
    OrderStep('🐶', 'Mai mare.', scale: 0.64),
    OrderStep('🐶', 'Mai mare.', scale: 0.82),
    OrderStep('🐶', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-copacul', 'De la mic la mare', [
    OrderStep('🌳', 'Cel mai mic.', scale: 0.32),
    OrderStep('🌳', 'Mai mare.', scale: 0.48),
    OrderStep('🌳', 'Mai mare.', scale: 0.64),
    OrderStep('🌳', 'Mai mare.', scale: 0.82),
    OrderStep('🌳', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-mașina', 'De la mic la mare', [
    OrderStep('🚗', 'Cel mai mic.', scale: 0.32),
    OrderStep('🚗', 'Mai mare.', scale: 0.48),
    OrderStep('🚗', 'Mai mare.', scale: 0.64),
    OrderStep('🚗', 'Mai mare.', scale: 0.82),
    OrderStep('🚗', 'Cel mai mare.', scale: 1.0),
  ]),
  OrderStory('marime-elefantul', 'De la mic la mare', [
    OrderStep('🐘', 'Cel mai mic.', scale: 0.32),
    OrderStep('🐘', 'Mai mare.', scale: 0.48),
    OrderStep('🐘', 'Mai mare.', scale: 0.64),
    OrderStep('🐘', 'Mai mare.', scale: 0.82),
    OrderStep('🐘', 'Cel mai mare.', scale: 1.0),
  ]),
];

/// O rundă: povestea, pașii aleși (în ordinea corectă) și cum apar amestecați pe ecran.
class OrderRound {
  const OrderRound({required this.story, required this.steps, required this.shuffled});

  final OrderStory story;

  /// Pașii de pus, în ordinea corectă.
  final List<OrderStep> steps;

  /// Indicii din [steps], în ordinea în care apar cartonașele (niciodată deja în ordine).
  final List<int> shuffled;
}

class OrderLevel {
  const OrderLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.stepsPerRound,
    required this.rounds,
    required this.instruction,
  });

  final String gameId;
  final int level;
  final int seed;
  final int stepsPerRound;
  final List<OrderRound> rounds;
  final String instruction;

  Set<String> get art => {for (final r in rounds) ...r.steps.map((s) => s.emoji)};
}

/// Cum a pus copilul o poveste: câte atingeri greșite și primul pas greșit ales.
class OrderAttempt {
  const OrderAttempt(this.round, {this.wrongTaps = 0, this.firstWrong, this.expected, this.hinted = false, this.ms});

  final OrderRound round;
  final int wrongTaps;

  /// Ce a atins prima dată greșit și ce trebuia atins atunci (erori de ordine).
  final String? firstWrong;
  final String? expected;

  /// A primit ghidaj (cartonașul corect a pulsat).
  final bool hinted;
  final int? ms;

  bool get clean => wrongTaps == 0;
}

class OrderResult {
  OrderResult(this.level, List<OrderAttempt> attempts) : attempts = List.unmodifiable(attempts);

  final OrderLevel level;
  final List<OrderAttempt> attempts;

  double get accuracy => attempts.isEmpty ? 0 : attempts.where((a) => a.clean).length / attempts.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class OrderGame {
  const OrderGame._(this.id, this.name, this.emoji, this.description, this.steps, this.stories,
      this.instruction);

  /// Pașii rutinei (AUT1–3).
  static const routine = OrderGame._(
    'pasii-rutinei',
    'Pașii rutinei',
    '🧼',
    'Pune pașii în ordine',
    ['AUT1', 'AUT2'],
    routineStories,
    'Ce facem întâi? Atinge pozele în ordine.',
  );

  /// Ce urmează? (COG6).
  static const story = OrderGame._(
    'ce-urmeaza',
    'Ce urmează?',
    '🐣',
    'Pune întâmplarea în ordine',
    ['COG6'],
    storyStories,
    'Ce s-a întâmplat întâi? Atinge pozele în ordine.',
  );

  /// Mare–mijlociu–mic (COG4).
  static const sizes = OrderGame._(
    'mare-mic',
    'Mare și mic',
    '🧸',
    'Pune de la mic la mare',
    ['COG4'],
    sizeStories,
    'Pune de la cel mai mic la cel mai mare.',
  );

  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> steps;
  final List<OrderStory> stories;
  final String instruction;

  Set<Grade> get grades => Grade.parseCodes('G12');

  /// Câți pași are o rundă: 2 („întâi … apoi …”) → 5.
  int stepsFor(int level) => min(5, 2 + (level - 1) ~/ 2);

  /// Câte povești pe nivel.
  int roundsFor(int level) => level <= 2 ? 3 : 4;

  OrderLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final k = stepsFor(level);
    final pool = [...stories]..shuffle(random);
    final rounds = <OrderRound>[];
    for (var i = 0; i < roundsFor(level); i++) {
      final story = pool[i % pool.length];
      // Păstrăm primul și ultimul pas (începutul și finalul clar) și pași din mijloc, în ordine.
      final n = story.steps.length;
      final take = min(k, n);
      final middle = [for (var j = 1; j < n - 1; j++) j]..shuffle(random);
      final idx = take == 1 ? [0] : ([0, ...middle.take(take - 2), n - 1]..sort());
      final steps = [for (final j in idx) story.steps[j]];
      List<int> order;
      do {
        order = [for (var j = 0; j < steps.length; j++) j]..shuffle(random);
      } while (_sorted(order));
      rounds.add(OrderRound(story: story, steps: steps, shuffled: order));
    }
    return OrderLevel(
      gameId: id,
      level: level,
      seed: s,
      stepsPerRound: k,
      rounds: rounds,
      instruction: instruction,
    );
  }

  static bool _sorted(List<int> xs) {
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] < xs[i - 1]) return false;
    }
    return true;
  }
}

const orderGames = [OrderGame.routine, OrderGame.story, OrderGame.sizes];

OrderGame? orderGameById(String id) {
  for (final g in orderGames) {
    if (g.id == id) return g;
  }
  return null;
}
