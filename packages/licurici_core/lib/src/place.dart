/// Pune ursul (LRC6, fratele lui „Unde e ursulețul?”): Licurici spune „Pune ursulețul sub masă”,
/// iar copilul **așază** obiectul acolo (îl trage sau atinge locul). Aceleași prepoziții ca la
/// „Unde e ursulețul?”, alt fel de răspuns — copilul produce poziția, nu doar o recunoaște.
///
/// Axe: câte locuri sunt de ales (pe / sub → + lângă → + în → + deasupra) și, de la nivelul 5,
/// două obiecte de așezat după aceeași propoziție („Pune ursulețul sub masă și mingea pe masă”).
library;

import 'dart:math';

import 'game.dart';
import 'grades.dart';

class PlaceAxes {
  const PlaceAxes({required this.relations, required this.objects});

  /// Prepozițiile folosite la nivelul ăsta (locurile de pe scenă, cât permite reperul).
  final List<Relation> relations;

  /// Câte obiecte de așezat după aceeași propoziție (1 sau 2).
  final int objects;

  Map<String, Object> toJson() => {'relations': [for (final r in relations) r.name], 'objects': objects};
}

/// Un obiect de așezat: emoji, cuvântul („ursulețul”) și unde trebuie pus.
class PlaceTask {
  const PlaceTask(this.emoji, this.word, this.relation);

  final String emoji;
  final String word;
  final Relation relation;
}

class PlaceRound {
  const PlaceRound({required this.landmark, required this.spots, required this.tasks});

  final Landmark landmark;

  /// Locurile de pe scenă (unde se poate pune ceva), în ordine fixă.
  final List<Relation> spots;

  /// Ce trebuie așezat, în ordinea spusă.
  final List<PlaceTask> tasks;

  /// „Pune ursulețul sub masă” (+ „și” + „mingea pe masă”).
  List<String> get speak => [
        'Pune ${tasks.first.word} ${tasks.first.relation.at(landmark)}',
        for (final t in tasks.skip(1)) ...['și', '${t.word} ${t.relation.at(landmark)}'],
      ];
}

class PlaceLevel {
  const PlaceLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final PlaceAxes axes;
  final List<PlaceRound> rounds;
}

/// O propoziție dusă la capăt: câte așezări greșite și cât a durat.
class PlaceAnswer {
  const PlaceAnswer(this.round, {required this.wrong, required this.ms, this.firstWrong});

  final PlaceRound round;
  final int wrong;
  final int ms;

  /// Primul loc greșit ales (pentru confuzii: „pe” în loc de „deasupra”).
  final Relation? firstWrong;

  bool get clean => wrong == 0;
}

class PlaceResult {
  PlaceResult(this.level, List<PlaceAnswer> answers) : answers = List.unmodifiable(answers);

  final PlaceLevel level;
  final List<PlaceAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.clean).length / answers.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (answers.isEmpty) return current;
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class PlaceGame {
  const PlaceGame();

  String get id => 'pune-ursul';
  String get name => 'Pune ursulețul';
  String get emoji => '🧸';
  String get description => 'Pune-l pe, sub, în, lângă';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['LRC6'];

  /// Câte propoziții pe nivel.
  static const rounds = 6;

  static const things = [('🧸', 'ursulețul'), ('⚽', 'mingea'), ('🐱', 'pisica'), ('🐶', 'cățelul'), ('🍎', 'mărul')];

  /// „În” doar la cutie; „sub cutie” nu (cutia stă pe podea).
  static bool fits(Relation r, Landmark l) => l == Landmark.cutie ? r != Relation.sub : r != Relation.inauntru;

  PlaceAxes axesFor(int level) => PlaceAxes(
        relations: switch (level) {
          1 => const [Relation.pe, Relation.sub],
          2 => const [Relation.pe, Relation.sub, Relation.langa],
          3 => const [Relation.pe, Relation.sub, Relation.inauntru, Relation.langa],
          _ => Relation.values,
        },
        objects: level >= 5 ? 2 : 1,
      );

  PlaceLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final list = <PlaceRound>[];
    Relation? last;
    for (var r = 0; r < rounds; r++) {
      // Reperul: unul la care rămân cel puțin două locuri (la nivelul 1, doar masa are „sub”).
      final landmarks = [for (final l in Landmark.values) if (axes.relations.where((x) => fits(x, l)).length >= 2) l];
      final landmark = landmarks[random.nextInt(landmarks.length)];
      final spots = [for (final x in Relation.values) if (axes.relations.contains(x) && fits(x, landmark)) x];
      final objects = [...things]..shuffle(random);
      // Locurile cerute: diferite între ele și, pe cât se poate, nu același ca data trecută.
      final free = [for (final x in spots) if (x != last) x]..shuffle(random);
      final places = <Relation>[free.first];
      if (axes.objects == 2) places.add(([...spots]..remove(free.first)..shuffle(random)).first);
      last = places.first;
      list.add(PlaceRound(
        landmark: landmark,
        spots: spots,
        tasks: [for (final (i, p) in places.indexed) PlaceTask(objects[i].$1, objects[i].$2, p)],
      ));
    }
    return PlaceLevel(gameId: id, level: level, seed: s, axes: axes, rounds: list);
  }
}
