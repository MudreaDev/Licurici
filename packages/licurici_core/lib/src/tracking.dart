/// Urmărește peștele (ATN2b, catalog pe arii #2): peștele copilului e arătat (strălucește),
/// apoi peștii înoată prin acvariu și, la final, se opresc toți; copilul atinge peștele lui.
/// Cu un singur pește, sarcina e doar urmărirea cu privirea și atingerea când se oprește;
/// cu mai mulți, e urmărirea unui obiect printre altele (paradigma *multiple object
/// tracking*, cu o singură țintă).
///
/// Nivelurile sunt generate din seed (ADR-027). Axe: numărul de pești (1 → 5), cât de
/// asemănători sunt (alt model → același model, altă culoare → identici), viteza, cât
/// înoată, cât de întortocheat e drumul (puncte de trecere, schimbări de adâncime — peștii
/// trec unul prin spatele altuia).
/// KPI: acuratețea pe număr de pești și pe asemănare, **pierderile de urmărire** (a ales
/// alt pește), atingerile în timpul înotului.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

/// Cât seamănă peștii între ei.
enum TrackSimilarity {
  /// Modele diferite (forme și culori diferite).
  species,

  /// Același model, culori diferite.
  color,

  /// Identici: doar urmărirea îl deosebește.
  identical,
}

class TrackAxes {
  const TrackAxes({
    required this.trials,
    required this.fish,
    required this.similarity,
    required this.speed,
    required this.swimMs,
    required this.waypoints,
    required this.depth,
  });

  final int trials;

  /// Câți pești sunt (1 = doar ținta).
  final int fish;
  final TrackSimilarity similarity;

  /// Viteza față de cea obișnuită din acvariu.
  final double speed;

  /// Cât înoată înainte să se oprească.
  final int swimMs;

  /// Prin câte puncte trece fiecare pește.
  final int waypoints;

  /// Se mută și în adâncime (trec unul prin spatele altuia).
  final bool depth;

  Map<String, Object> toJson() => {
    'trials': trials,
    'fish': fish,
    'similarity': similarity.name,
    'speed': speed,
    'swimMs': swimMs,
    'waypoints': waypoints,
    'depth': depth,
  };
}

/// Un punct de trecere: x, y ∈ [0, 1] (din colțul stânga-sus al zonei de înot), z ∈ [0, 1].
typedef TrackPoint = ({double x, double y, double z});

class TrackFish {
  const TrackFish({required this.species, required this.hue, required this.path});

  /// Modelul peștelui (`clovn`, `inger`, `balon`, `chirurg`).
  final String species;

  /// Rotirea culorii (grade); 0 = culorile obișnuite.
  final double hue;

  /// Primul punct = unde stă la început; ultimul = unde se oprește.
  final List<TrackPoint> path;
}

class TrackTrial {
  const TrackTrial({required this.index, required this.fish, required this.target});

  final int index;
  final List<TrackFish> fish;

  /// Peștele copilului (indice în [fish]).
  final int target;
}

class TrackLevel {
  const TrackLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.trials});

  final String gameId;
  final int level;
  final int seed;
  final TrackAxes axes;
  final List<TrackTrial> trials;

  /// Cât e arătat peștele la început.
  static const showMs = 2200;

  /// Cât așteptăm atingerea după oprire, apoi îl arătăm noi.
  static const answerMs = 9000;
}

class TrackResponse {
  const TrackResponse(this.trial, {required this.chosen, this.rtMs, this.earlyTaps = 0});

  final TrackTrial trial;

  /// Peștele atins (null = n-a atins nimic).
  final int? chosen;

  /// Din momentul opririi.
  final int? rtMs;

  /// Atingeri cât timp peștii înotau.
  final int earlyTaps;

  bool get correct => chosen == trial.target;

  /// A ales alt pește: și-a pierdut ținta.
  bool get lost => chosen != null && chosen != trial.target;
}

class TrackResult {
  TrackResult(this.level, List<TrackResponse> responses) : responses = List.unmodifiable(responses);

  final TrackLevel level;
  final List<TrackResponse> responses;

  double get accuracy => responses.isEmpty ? 0 : responses.where((r) => r.correct).length / responses.length;
  int get lost => responses.where((r) => r.lost).length;
  int get omissions => responses.where((r) => r.chosen == null).length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.84) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

/// Modelele care pot înota în joc (aceleași ca în acvariu).
const trackSpecies = ['clovn', 'inger', 'chirurg', 'balon'];

class TrackGame {
  const TrackGame();

  String get id => 'urmareste-pestele';
  String get name => 'Urmărește peștele';
  String get emoji => '🐠';
  String get description => 'Nu-l pierde din ochi';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['ATN2b'];

  TrackAxes axesFor(int level) => TrackAxes(
    trials: 6,
    fish: level <= 2 ? 1 : (level <= 4 ? 2 : (level <= 7 ? 3 : (level <= 10 ? 4 : 5))),
    similarity: level <= 5
        ? TrackSimilarity.species
        : (level <= 8 ? TrackSimilarity.color : TrackSimilarity.identical),
    speed: ramp(level, 0.8, 1.8, 14),
    swimMs: ramp(level, 2600, 7000, 12).round(),
    waypoints: ramp(level, 2, 6, 12).round(),
    depth: level >= 4,
  );

  TrackLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final trials = <TrackTrial>[];
    for (var t = 0; t < axes.trials; t++) {
      final looks = _looks(axes, random);
      final starts = _spread(axes.fish, random);
      final fish = <TrackFish>[
        for (var i = 0; i < axes.fish; i++)
          TrackFish(species: looks[i].$1, hue: looks[i].$2, path: _path(starts[i], axes, random)),
      ];
      trials.add(TrackTrial(index: t, fish: fish, target: random.nextInt(axes.fish)));
    }
    return TrackLevel(gameId: id, level: level, seed: s, axes: axes, trials: trials);
  }

  /// Cum arată fiecare pește, după asemănare.
  List<(String, double)> _looks(TrackAxes axes, Random r) {
    switch (axes.similarity) {
      case TrackSimilarity.species:
        final sp = [...trackSpecies]..shuffle(r);
        // Peste 4 pești, al cincilea e un model repetat cu altă culoare.
        return [for (var i = 0; i < axes.fish; i++) (sp[i % sp.length], i < sp.length ? 0.0 : 150.0)];
      case TrackSimilarity.color:
        final sp = trackSpecies[r.nextInt(trackSpecies.length)];
        final hues = [0.0, 60.0, 130.0, 200.0, 280.0]..shuffle(r);
        return [for (var i = 0; i < axes.fish; i++) (sp, hues[i])];
      case TrackSimilarity.identical:
        final sp = trackSpecies[r.nextInt(trackSpecies.length)];
        return [for (var i = 0; i < axes.fish; i++) (sp, 0.0)];
    }
  }

  /// Locuri de pornire depărtate între ele (pe o grilă amestecată).
  List<TrackPoint> _spread(int n, Random r) {
    final cells = <(int, int)>[for (var i = 0; i < 3; i++) for (var j = 0; j < 2; j++) (i, j)]..shuffle(r);
    return [
      for (var k = 0; k < n; k++)
        (
          x: (cells[k % cells.length].$1 + 0.25 + r.nextDouble() * 0.5) / 3,
          y: (cells[k % cells.length].$2 + 0.25 + r.nextDouble() * 0.5) / 2,
          z: 0.15 + r.nextDouble() * 0.3,
        ),
    ];
  }

  List<TrackPoint> _path(TrackPoint start, TrackAxes axes, Random r) {
    final pts = <TrackPoint>[start];
    var p = start;
    for (var i = 0; i < axes.waypoints; i++) {
      // Pași nu prea scurți (să se vadă că înoată) și nu peste tot ecranul.
      TrackPoint next;
      var tries = 0;
      do {
        next = (
          x: 0.05 + r.nextDouble() * 0.9,
          y: 0.05 + r.nextDouble() * 0.9,
          z: axes.depth ? 0.05 + r.nextDouble() * 0.7 : p.z,
        );
        tries++;
      } while (tries < 20 && (_d(p, next) < 0.25 || _d(p, next) > 0.7));
      pts.add(next);
      p = next;
    }
    return pts;
  }

  static double _d(TrackPoint a, TrackPoint b) => sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
}
