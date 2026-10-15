/// Unde se uită? (ATN3–4, catalog #4): Licurici se uită (și, la început, arată) spre unul din
/// două obiecte; copilul atinge obiectul. Atenția comună — urmărirea privirii și a gestului —
/// e una dintre abilitățile-cheie lucrate în autism. Generat din seed (ADR-027): indiciul trece
/// de la privire + gest (ATN3) la doar privire (ATN4), iar obiectele devin asemănătoare.
library;

import 'dart:math';

import 'avoid.dart' show safeWords;
import 'games/vocabular.dart';
import 'grades.dart';

enum GazeCue {
  /// Se uită și arată cu mâna.
  point,

  /// Doar se uită.
  look,
}

class GazeAxes {
  const GazeAxes({required this.cue, required this.similar, required this.rounds});

  final GazeCue cue;

  /// Cele două obiecte sunt din aceeași grupă.
  final bool similar;
  final int rounds;

  Map<String, Object> toJson() => {'cue': cue.name, 'similar': similar, 'rounds': rounds};
}

class GazeRound {
  const GazeRound({required this.objects, required this.side});

  /// Obiectul din stânga și cel din dreapta.
  final List<ObjectWord> objects;

  /// Spre care se uită Licurici: 0 = stânga, 1 = dreapta (a privitorului).
  final int side;

  ObjectWord get target => objects[side];
}

class GazeLevel {
  const GazeLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final GazeAxes axes;
  final List<GazeRound> rounds;

  /// Rostit la fiecare rundă.
  String get question => axes.cue == GazeCue.point ? 'Ce arată Licurici?' : 'Unde se uită Licurici?';

  Set<String> get art => {for (final r in rounds) ...r.objects.map((o) => o.emoji)};
}

class GazeAnswer {
  const GazeAnswer(this.round, {required this.firstChoice, this.ms, this.extraCue = false});

  final GazeRound round;

  /// Prima atingere: 0 / 1.
  final int firstChoice;
  final int? ms;

  /// A primit un indiciu în plus (gestul, când cerința era doar privirea).
  final bool extraCue;

  bool get correct => firstChoice == round.side;
}

class GazeResult {
  GazeResult(this.level, List<GazeAnswer> answers) : answers = List.unmodifiable(answers);

  final GazeLevel level;
  final List<GazeAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.correct).length / answers.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  /// Cu două variante, 50% e întâmplare: urcăm doar peste 85%.
  int suggestedNextLevel(int current) {
    if (accuracy >= 0.85) return current + 1;
    if (accuracy < 0.6) return max(1, current - 1);
    return current;
  }
}

class GazeGame {
  const GazeGame();

  String get id => 'unde-se-uita';
  String get name => 'Unde se uită?';
  String get emoji => '👁️';
  String get description => 'Urmărește privirea lui Licurici';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['ATN3', 'ATN4'];

  GazeAxes axesFor(int level) => GazeAxes(
        cue: level <= 3 ? GazeCue.point : GazeCue.look,
        similar: level >= 6,
        rounds: 6,
      );

  /// [avoid]: imaginile pe care copilul nu trebuie să le vadă (`avoidedEmojis`) nu apar deloc.
  GazeLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    // Partea: echilibrat (jumătate stânga), fără mai mult de două la rând pe aceeași parte.
    List<int> sides;
    do {
      sides = [for (var i = 0; i < axes.rounds; i++) i < axes.rounds ~/ 2 ? 0 : 1]..shuffle(random);
    } while (_maxRun(sides) > 2);
    final rounds = <GazeRound>[];
    final used = <String>{};
    for (final side in sides) {
      final pool = safeWords(avoid).where((o) => !used.contains(o.emoji)).toList();
      // La obiecte asemănătoare, ținta vine dintr-o grupă care mai are măcar un obiect liber.
      final starts = axes.similar
          ? pool.where((o) => pool.any((p) => p != o && p.group == o.group)).toList()
          : pool;
      final a = starts[random.nextInt(starts.length)];
      final others = pool.where((o) => o != a && (axes.similar ? o.group == a.group : o.group != a.group)).toList();
      final candidates = others.isEmpty ? pool.where((o) => o != a).toList() : others;
      final b = candidates[random.nextInt(candidates.length)];
      used.addAll([a.emoji, b.emoji]);
      rounds.add(GazeRound(objects: random.nextBool() ? [a, b] : [b, a], side: side));
    }
    return GazeLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }

  static int _maxRun(List<int> xs) {
    var best = 0, run = 0;
    for (var i = 0; i < xs.length; i++) {
      run = i > 0 && xs[i] == xs[i - 1] ? run + 1 : 1;
      best = max(best, run);
    }
    return best;
  }
}
