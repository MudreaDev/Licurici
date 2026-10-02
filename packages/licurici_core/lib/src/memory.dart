/// Perechi (FEX5, catalog #41): cărți întoarse, copilul găsește perechile. Memorie vizuală.
/// Nivelurile sunt generate din seed (ADR-027); KPI: mutări / pereche și întoarcerile
/// repetate inutile (o carte deja văzută, întoarsă din nou fără să facă pereche).
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

/// Axele de dificultate ale unui nivel.
class MemoryAxes {
  const MemoryAxes({required this.pairs, required this.similar});

  /// Câte perechi (2 → 10).
  final int pairs;

  /// Toate imaginile din aceeași categorie (doar animale) — mai greu de ținut minte decât un
  /// amestec de animale, fructe și jucării.
  final bool similar;

  /// Coloanele grilei (landscape): două rânduri cât încap, apoi trei.
  int get columns {
    final n = pairs * 2;
    if (n <= 4) return n;
    if (n <= 14) return n ~/ 2;
    return (n / 3).ceil();
  }

  Map<String, Object> toJson() => {'pairs': pairs, 'similar': similar};
}

const _animals = [
  '🐶', '🐱', '🐇', '🐻', '🦊', '🐭', '🐥', '🦆', '🐄', '🐎', //
  '🐑', '🐖', '🐘', '🦒', '🦓', '🦉', '🦋', '🐝', '🐢', '🐬',
];
const _things = [
  '🍎', '🍌', '🍓', '🍒', '🥕', '🍉', '🎈', '⚽', '🧸', '🏠', //
  '🚗', '🌸', '🌳', '☀️', '🌙', '🎁', '🥁', '📖',
];

class MemoryLevel {
  const MemoryLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.cards,
    required this.instruction,
  });

  final String gameId;
  final int level;
  final int seed;
  final MemoryAxes axes;

  /// Fețele cărților, amestecate (fiecare apare de exact două ori).
  final List<String> cards;
  final String instruction;

  int get pairs => axes.pairs;

  /// Imaginile de pre-încărcat.
  Set<String> get art => cards.toSet();
}

/// O mutare: două cărți întoarse una după alta.
class MemoryMove {
  const MemoryMove(this.first, this.second, {this.ms});

  /// Indicii cărților (în `MemoryLevel.cards`).
  final int first;
  final int second;

  /// Cât a durat mutarea (de la prima la a doua carte), dacă se măsoară.
  final int? ms;
}

class MemoryResult {
  MemoryResult(this.level, List<MemoryMove> moves) : moves = List.unmodifiable(moves);

  final MemoryLevel level;
  final List<MemoryMove> moves;

  bool isMatch(MemoryMove m) => level.cards[m.first] == level.cards[m.second];

  int get matches => moves.where(isMatch).length;
  bool get complete => matches == level.pairs;

  /// Mutări pe pereche: 1 = memorie perfectă (imposibil la prima vedere), ~1,5–2 = foarte bine.
  double get movesPerPair => level.pairs == 0 ? 0 : moves.length / level.pairs;

  /// Întoarceri repetate inutile: o carte deja văzută, întoarsă din nou într-o mutare fără
  /// pereche, deși perechea ei fusese și ea văzută (copilul „știa”, dar nu și-a amintit).
  int get uselessRepeats {
    final seen = <int>{};
    var useless = 0;
    for (final m in moves) {
      if (!isMatch(m)) {
        for (final c in [m.first, m.second]) {
          final partner = _partnerOf(c);
          if (seen.contains(c) && seen.contains(partner)) useless++;
        }
      }
      seen..add(m.first)..add(m.second);
    }
    return useless;
  }

  int _partnerOf(int card) {
    final face = level.cards[card];
    for (var i = 0; i < level.cards.length; i++) {
      if (i != card && level.cards[i] == face) return i;
    }
    return card;
  }

  /// Stele: recompensăm eficiența, dar oricine termină primește cel puțin una.
  int get stars {
    final optimal = movesPerPair;
    if (optimal <= 1.6) return 3;
    if (optimal <= 2.4) return 2;
    return 1;
  }

  /// Nivelul următor: foarte eficient → +1; multe repetări inutile → −1; altfel rămâne.
  int suggestedNextLevel(int current) {
    if (stars == 3) return current + 1;
    if (uselessRepeats > level.pairs) return max(1, current - 1);
    return current;
  }
}

class MemoryGame {
  const MemoryGame();

  String get id => 'perechi';
  String get name => 'Perechi';
  String get emoji => '🃏';
  String get description => 'Găsește perechile';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['FEX5'];

  MemoryAxes axesFor(int level) => MemoryAxes(
        pairs: ramp(level, 2, 10, 13).round(),
        similar: level >= 8,
      );

  MemoryLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final pool = [...(axes.similar ? _animals : [..._animals, ..._things])]..shuffle(random);
    final faces = pool.take(axes.pairs).toList();
    final cards = [...faces, ...faces]..shuffle(random);
    return MemoryLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      cards: cards,
      instruction: 'Găsește perechile la fel.',
    );
  }
}
