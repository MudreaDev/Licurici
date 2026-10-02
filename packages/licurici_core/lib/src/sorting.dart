/// Sortăm (COG3, catalog #26): copilul trage fiecare lucru în grupa lui (prima mecanică
/// `dragDrop`). Nivelurile sunt generate din seed (ADR-027); fiecare lucru pus = o încercare,
/// iar o grupă greșită dă confuzia între categorii (ex. „pune fructele la jucării”).
library;

import 'dart:math';

import 'grades.dart';

/// O grupă (cutia în care se sortează).
class SortBin {
  const SortBin(this.id, this.name, this.emoji, this.items);

  final String id;

  /// Numele rostit și scris pe cutie.
  final String name;

  /// Iconița cutiei.
  final String emoji;

  /// Ce poate intra în grupă.
  final List<String> items;
}

/// Grupele disponibile (doar lucruri care au ilustrații pictate sau OpenMoji clare).
const sortCategories = [
  SortBin('fructe', 'Fructe', '🍎', ['🍎', '🍌', '🍓', '🍒', '🍉', '🍏']),
  SortBin('animale', 'Animale', '🐶', ['🐶', '🐱', '🐇', '🐻', '🦊', '🐭', '🐥', '🦆', '🐄', '🐑', '🐖']),
  SortBin('jucarii', 'Jucării', '🧸', ['🎈', '⚽', '🧸', '🥁', '🚗', '🎁']),
  SortBin('natura', 'Natură', '🌳', ['🌸', '🌷', '🌳', '🌲', '🍂', '☀️', '🌙', '☁️', '🌈']),
];

class SortAxes {
  const SortAxes({required this.bins, required this.perBin});

  /// Câte grupe (2 → 4).
  final int bins;

  /// Câte lucruri pe grupă (2 → 4).
  final int perBin;

  int get items => bins * perBin;

  Map<String, Object> toJson() => {'bins': bins, 'perBin': perBin};
}

/// Un lucru de sortat: imaginea și grupa lui.
class SortItem {
  const SortItem(this.index, this.emoji, this.binId);

  final int index;
  final String emoji;
  final String binId;
}

class SortLevel {
  const SortLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.bins,
    required this.items,
    required this.instruction,
  });

  final String gameId;
  final int level;
  final int seed;
  final SortAxes axes;
  final List<SortBin> bins;

  /// Lucrurile, amestecate (ordinea în care apar pe ecran).
  final List<SortItem> items;
  final String instruction;

  Set<String> get art => {...items.map((i) => i.emoji), ...bins.map((b) => b.emoji)};
}

/// Cum a pus copilul un lucru: câte greșeli înainte și în ce grupă greșită a încercat prima dată.
class SortPlacement {
  const SortPlacement(this.item, {this.wrongDrops = 0, this.firstWrongBin, this.ms});

  final SortItem item;
  final int wrongDrops;
  final String? firstWrongBin;
  final int? ms;

  bool get firstTry => wrongDrops == 0;
}

class SortResult {
  SortResult(this.level, List<SortPlacement> placements)
      : placements = List.unmodifiable(placements);

  final SortLevel level;
  final List<SortPlacement> placements;

  double get accuracy => placements.isEmpty
      ? 0
      : placements.where((p) => p.firstTry).length / placements.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  /// Totul din prima → +1; sub 60% → −1; altfel rămâne.
  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.6) return max(1, current - 1);
    return current;
  }
}

class SortGame {
  const SortGame();

  String get id => 'sortam';
  String get name => 'Sortăm';
  String get emoji => '🗂';
  String get description => 'Pune fiecare lucru în grupa lui';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['COG3'];

  SortAxes axesFor(int level) => SortAxes(
        bins: level < 5 ? 2 : (level < 10 ? 3 : 4),
        perBin: level < 3 ? 2 : (level < 8 ? 3 : 4),
      );

  SortLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final bins = ([...sortCategories]..shuffle(random)).take(axes.bins).toList();
    final items = <SortItem>[];
    for (final b in bins) {
      for (final e in ([...b.items]..shuffle(random)).take(axes.perBin)) {
        items.add(SortItem(0, e, b.id));
      }
    }
    items.shuffle(random);
    return SortLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      bins: bins,
      items: [for (final (i, it) in items.indexed) SortItem(i, it.emoji, it.binId)],
      instruction: 'Trage fiecare lucru în grupa potrivită.',
    );
  }
}
