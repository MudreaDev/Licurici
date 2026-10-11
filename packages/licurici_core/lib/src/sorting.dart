/// Sortăm (COG3, catalog #26): copilul trage fiecare lucru în grupa lui (prima mecanică
/// `dragDrop`). Nivelurile sunt generate din seed (ADR-027); fiecare lucru pus = o încercare,
/// iar o grupă greșită dă confuzia între categorii (ex. „pune fructele la jucării”).
library;

import 'dart:math';

import 'face.dart';
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

/// Un joc de sortare: aceeași mecanică (`dragDrop`), alte grupe și altă treaptă. Jocurile
/// „frate” (același obiectiv pe alt material — generalizarea, plan §4) se adaugă aici, fără cod nou
/// în ecran: [sortGames].
class SortGame {
  const SortGame()
      : id = 'sortam',
        name = 'Sortăm',
        emoji = '🗂',
        description = 'Pune fiecare lucru în grupa lui',
        gradeCodes = 'G1234',
        steps = const ['COG3'],
        categories = sortCategories,
        instruction = 'Trage fiecare lucru în grupa potrivită.';

  const SortGame.custom({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.steps,
    required this.categories,
    required this.instruction,
    this.gradeCodes = 'G1234',
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final String gradeCodes;
  final List<String> steps;

  /// Grupele din care se aleg cele ale nivelului (cel puțin 4, fiecare cu cel puțin 4 lucruri).
  final List<SortBin> categories;
  final String instruction;

  Set<Grade> get grades => Grade.parseCodes(gradeCodes);

  SortAxes axesFor(int level) => SortAxes(
        bins: level < 5 ? 2 : (level < 10 ? 3 : 4),
        perBin: level < 3 ? 2 : (level < 8 ? 3 : 4),
      );

  SortLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final bins = ([...categories]..shuffle(random)).take(axes.bins).toList();
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
      instruction: instruction,
    );
  }
}

/// Pune la locul lui (COG3, al doilea joc al treptei): aceleași sortări, pe locurile din casă.
const sortRooms = SortGame.custom(
  id: 'la-locul-lui',
  name: 'La locul lui',
  emoji: '🏠',
  description: 'Duce fiecare lucru în camera lui',
  steps: ['COG3'],
  instruction: 'Pune fiecare lucru la locul lui.',
  categories: [
    SortBin('bucatarie', 'Bucătărie', '🍽️', ['🥄', '🥣', '🥛', '🍞', '🍎']),
    SortBin('baie', 'Baie', '🛁', ['🧼', '🪥', '🧴', '🧻']),
    SortBin('dormitor', 'Dormitor', '🛏️', ['🧸', '📖', '🌙', '🪀']),
    SortBin('dulap', 'Dulap', '🚪', ['👕', '👖', '👗', '🧦', '🧢', '👟']),
  ],
);

/// Sortăm emoțiile (EMO2, al doilea joc al treptei): în cutii, fețele pictate ale copilului
/// cunoscut (referința); de sortat, fețe desenate din cod, de fiecare dată altele (ten, păr,
/// ochi, accesorii) — emoția recunoscută pe fețe noi, nu doar pe desenele învățate.
final sortEmotions = SortGame.custom(
  id: 'sortam-emotiile',
  name: 'Sortăm emoțiile',
  emoji: '😊',
  description: 'Pune fiecare față la emoția ei',
  steps: const ['EMO2'],
  instruction: 'Pune fiecare față la emoția ei.',
  categories: [
    for (final (i, (e, icon, name)) in const [
      (FaceEmotion.bucuros, '😊', 'Bucuros'),
      (FaceEmotion.trist, '😢', 'Trist'),
      (FaceEmotion.suparat, '😠', 'Supărat'),
      (FaceEmotion.speriat, '😨', 'Speriat'),
      (FaceEmotion.surprins, '😲', 'Surprins'),
    ].indexed)
      SortBin(e.name, name, icon, [for (final f in distinctFaces(Random(31 + i), e, 12)) f.art]),
  ],
);

/// Toate jocurile de sortare (fiecare cu nivelul lui și ruta `/sortam/:id`).
final sortGames = <SortGame>[const SortGame(), sortRooms, sortEmotions];

SortGame? sortGameById(String id) {
  for (final g in sortGames) {
    if (g.id == id) return g;
  }
  return null;
}
