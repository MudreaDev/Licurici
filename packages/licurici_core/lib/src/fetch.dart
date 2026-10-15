/// Adu-mi (LRC1–2, fratele lui „Arată-mi”): Licurici cere „Adu-mi mingea”, iar copilul **duce**
/// obiectul în coșul lui (îl trage sau îl atinge). Același vocabular ca „Arată-mi”, alt fel de
/// răspuns — ca înțelegerea cuvântului să se verifice și prin acțiune, nu doar prin arătat.
///
/// Axe: câte obiecte pe masă (2 → 6), doar cuvinte foarte cunoscute la început, distractori din
/// aceeași grupă (fructe între fructe) de la nivelul 4, două obiecte cerute deodată („Adu-mi
/// mingea și mărul”) de la nivelul 6.
library;

import 'dart:math';

import 'avoid.dart';
import 'games/vocabular.dart';
import 'grades.dart';

class FetchAxes {
  const FetchAxes({required this.objects, required this.familiarOnly, required this.sameGroup, required this.wanted});

  final int objects;
  final bool familiarOnly;
  final bool sameGroup;

  /// Câte obiecte se cer deodată (1 sau 2).
  final int wanted;

  Map<String, Object> toJson() => {'objects': objects, 'familiarOnly': familiarOnly, 'sameGroup': sameGroup, 'wanted': wanted};
}

class FetchRound {
  const FetchRound({required this.table, required this.wanted});

  /// Obiectele de pe masă (în ordinea așezării).
  final List<ObjectWord> table;

  /// Ce cere Licurici, în ordinea spusă.
  final List<ObjectWord> wanted;

  /// Ce se rostește: „Adu-mi” + cuvintele (cu „și” între ele).
  List<String> get speak => [
        'Adu-mi',
        for (final (i, w) in wanted.indexed) ...[if (i > 0) 'și', w.word],
      ];
}

class FetchLevel {
  const FetchLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final FetchAxes axes;
  final List<FetchRound> rounds;
}

/// O cerere dusă la capăt: câte obiecte greșite au ajuns în coș și cât a durat.
class FetchAnswer {
  const FetchAnswer(this.round, {required this.wrong, required this.ms, this.firstWrong});

  final FetchRound round;
  final int wrong;
  final int ms;

  /// Primul obiect greșit dus în coș (pentru confuzii).
  final ObjectWord? firstWrong;

  bool get clean => wrong == 0;
}

class FetchResult {
  FetchResult(this.level, List<FetchAnswer> answers) : answers = List.unmodifiable(answers);

  final FetchLevel level;
  final List<FetchAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.clean).length / answers.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (answers.isEmpty) return current;
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class FetchGame {
  const FetchGame();

  String get id => 'adu-mi';
  String get name => 'Adu-mi';
  String get emoji => '🧺';
  String get description => 'Du în coș ce îți cere Licurici';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['LRC1', 'LRC2'];

  /// Câte cereri pe nivel.
  static const rounds = 5;

  FetchAxes axesFor(int level) => FetchAxes(
        objects: min(6, 1 + level),
        familiarOnly: level <= 2,
        sameGroup: level >= 4,
        wanted: level >= 6 ? 2 : 1,
      );

  /// [avoid]: imaginile de evitat (`avoidedEmojis`) — nu apar deloc pe masă.
  FetchLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final words = safeWords(avoid);
    final pool = [for (final w in words) if (!axes.familiarOnly || w.familiar) w];
    final list = <FetchRound>[];
    ObjectWord? last;
    for (var r = 0; r < rounds; r++) {
      final candidates = [for (final w in pool) if (w != last) w]..shuffle(random);
      final target = candidates.first;
      last = target;
      final wanted = <ObjectWord>[target];
      if (axes.wanted == 2) wanted.add(candidates.firstWhere((w) => w != target));
      // Distractorii: din aceeași grupă când nivelul o cere (și dacă ajung), altfel oricare.
      final same = [for (final w in words) if (!wanted.contains(w) && w.group == target.group) w]..shuffle(random);
      final other = [for (final w in words) if (!wanted.contains(w) && !same.contains(w)) w]..shuffle(random);
      final distractors = [...(axes.sameGroup ? same : <ObjectWord>[]), ...other].take(axes.objects - wanted.length).toList();
      final table = [...wanted, ...distractors]..shuffle(random);
      list.add(FetchRound(table: table, wanted: wanted));
    }
    return FetchLevel(gameId: id, level: level, seed: s, axes: axes, rounds: list);
  }
}
