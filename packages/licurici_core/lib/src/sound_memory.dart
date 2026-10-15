/// Memorie cu sunete (COM1, fratele lui „Ce se aude?”): perechile sunt un animal (sau lucru) și
/// **sunetul** lui. Cartea-sunet arată o notă și, când se întoarce, Licurici spune sunetul
/// („miau”); copilul găsește cine îl face. Aceeași asociere sunet → sursă, cu memorie.
///
/// Axe: câte perechi (2 → 6) și dacă animalele stau la vedere (nivelurile 1–3: copilul ascultă
/// sunetul și arată cine îl face; de la 4, toate cărțile sunt întoarse — memorie). De la nivelul 6,
/// doar animale de la fermă (sunete mai apropiate).
library;

import 'dart:math';

import 'games/vocabular.dart';
import 'grades.dart';

class SoundMemoryAxes {
  const SoundMemoryAxes({required this.pairs, required this.sourcesUp, required this.farmOnly});

  final int pairs;

  /// Cărțile cu animale stau la vedere (se întorc doar cele cu sunete).
  final bool sourcesUp;
  final bool farmOnly;

  /// Coloanele grilei (landscape).
  int get columns {
    final n = pairs * 2;
    return n <= 4 ? n : (n / 2).ceil();
  }

  Map<String, Object> toJson() => {'pairs': pairs, 'sourcesUp': sourcesUp, 'farmOnly': farmOnly};
}

/// O carte: sursa (animalul) sau sunetul ei.
class SoundCard {
  const SoundCard(this.source, {required this.isSound});

  final SoundSource source;
  final bool isSound;

  /// Pentru înregistrări: „sunet:miau” sau „pisica”.
  String get id => isSound ? 'sunet:${source.sound}' : source.who;

  bool matches(SoundCard other) => other.source == source && other.isSound != isSound;
}

class SoundMemoryLevel {
  const SoundMemoryLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.cards});

  final String gameId;
  final int level;
  final int seed;
  final SoundMemoryAxes axes;
  final List<SoundCard> cards;

  int get pairs => axes.pairs;
}

/// O mutare: două cărți întoarse una după alta.
class SoundMove {
  const SoundMove(this.first, this.second, {this.ms});

  final int first;
  final int second;
  final int? ms;
}

class SoundMemoryResult {
  SoundMemoryResult(this.level, List<SoundMove> moves) : moves = List.unmodifiable(moves);

  final SoundMemoryLevel level;
  final List<SoundMove> moves;

  bool isMatch(SoundMove m) => level.cards[m.first].matches(level.cards[m.second]);

  int get matches => moves.where(isMatch).length;
  bool get complete => matches == level.pairs;

  double get movesPerPair => level.pairs == 0 ? 0 : moves.length / level.pairs;

  /// Cu animalele la vedere, o pereche din prima e asocierea corectă (nu noroc de memorie), deci
  /// pragurile sunt mai stricte.
  int get stars {
    final m = movesPerPair;
    if (level.axes.sourcesUp) return m <= 1.25 ? 3 : (m <= 2 ? 2 : 1);
    return m <= 1.75 ? 3 : (m <= 2.5 ? 2 : 1);
  }

  int suggestedNextLevel(int current) {
    if (stars == 3) return current + 1;
    if (stars == 1) return max(1, current - 1);
    return current;
  }
}

class SoundMemoryGame {
  const SoundMemoryGame();

  String get id => 'memorie-sunete';
  String get name => 'Memorie cu sunete';
  String get emoji => '🔊';
  String get description => 'Găsește cine face sunetul';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['COM1'];

  static const instruction = 'Întoarce o carte cu sunet și găsește cine îl face.';

  /// Ce spune Licurici la o pereche găsită: „Pisica face miau.”
  static String says(SoundSource x) => '${x.who[0].toUpperCase()}${x.who.substring(1)} face ${x.sound}.';

  SoundMemoryAxes axesFor(int level) => SoundMemoryAxes(
        pairs: switch (level) { 1 => 2, 2 => 3, 3 => 4, 4 => 3, 5 => 4, 6 => 5, _ => 6 },
        sourcesUp: level <= 3,
        farmOnly: level >= 6,
      );

  SoundMemoryLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final pool = [for (final x in soundSources) if ((!axes.farmOnly || x.farm) && !avoid.contains(x.emoji)) x]..shuffle(random);
    final sources = pool.take(axes.pairs).toList();
    final cards = [
      for (final x in sources) ...[SoundCard(x, isSound: false), SoundCard(x, isSound: true)],
    ]..shuffle(random);
    return SoundMemoryLevel(gameId: id, level: level, seed: s, axes: axes, cards: cards);
  }
}
