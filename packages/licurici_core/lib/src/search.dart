/// Caută (ATN2–4, catalog #3 `cauta-in-camera`): un obiect cerut, printre altele împrăștiate
/// pe ecran. Căutare vizuală: nivelurile cresc numărul de obiecte (4 → 25) și asemănarea lor
/// cu ținta (alte grupe → aceeași grupă). Generat din seed (ADR-027).
/// KPI: **timpul de căutare în funcție de numărul de obiecte** (panta) și atingerile greșite.
library;

import 'dart:math';

import 'avoid.dart' show safeWords;
import 'games/vocabular.dart';
import 'grades.dart';
import 'reaction.dart' show ramp;

class SearchAxes {
  const SearchAxes({required this.items, required this.similar, required this.rounds});

  /// Câte obiecte sunt pe ecran (inclusiv ținta).
  final int items;

  /// Distractorii sunt din aceeași grupă cu ținta (mai greu de deosebit).
  final bool similar;
  final int rounds;

  Map<String, Object> toJson() => {'items': items, 'similar': similar, 'rounds': rounds};
}

class SearchItem {
  const SearchItem(this.index, this.object, this.x, this.y, this.tilt);

  final int index;
  final ObjectWord object;

  /// Centrul, în 0…1 din zona de joc.
  final double x;
  final double y;

  /// Ușor rotit (radiani), ca să pară împrăștiate natural.
  final double tilt;
}

class SearchRound {
  const SearchRound({required this.target, required this.items, required this.cols, required this.rows});

  final ObjectWord target;
  final List<SearchItem> items;

  /// Grila din care s-au împrăștiat (UI-ul calculează mărimea: o celulă).
  final int cols;
  final int rows;

  /// Rostit: „Găsește ursulețul.”
  String get says => 'Găsește ${target.word}.';
}

class SearchLevel {
  const SearchLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final SearchAxes axes;
  final List<SearchRound> rounds;

  Set<String> get art => {for (final r in rounds) ...r.items.map((i) => i.object.emoji)};
}

class SearchFind {
  const SearchFind(this.round, {required this.ms, this.wrongTaps = 0, this.firstWrong});

  final SearchRound round;
  final int ms;
  final int wrongTaps;
  final String? firstWrong;

  bool get clean => wrongTaps == 0;
}

class SearchResult {
  SearchResult(this.level, List<SearchFind> finds) : finds = List.unmodifiable(finds);

  final SearchLevel level;
  final List<SearchFind> finds;

  double get accuracy => finds.isEmpty ? 0 : finds.where((f) => f.clean).length / finds.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.6) return max(1, current - 1);
    return current;
  }
}

class SearchGame {
  const SearchGame();

  String get id => 'cauta';
  String get name => 'Caută';
  String get emoji => '🎯';
  String get description => 'Găsește obiectul cerut';
  Set<Grade> get grades => Grade.parseCodes('G12');
  List<String> get steps => const ['ATN2'];

  SearchAxes axesFor(int level) => SearchAxes(
        items: ramp(level, 4, 25, 14).round(),
        similar: level >= 5,
        rounds: 5,
      );

  /// Grila pentru [n] obiecte pe o zonă lată (landscape ~16:9).
  static (int, int) grid(int n) {
    final cols = max(2, (sqrt(n * 1.8)).ceil());
    final rows = (n / cols).ceil();
    return (cols, max(rows, 2));
  }

  /// [avoid]: imaginile pe care copilul nu trebuie să le vadă (`avoidedEmojis`) nu apar deloc.
  SearchLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final words = safeWords(avoid);
    final targets = ([...words]..shuffle(random)).take(axes.rounds).toList();
    final rounds = <SearchRound>[];
    for (final target in targets) {
      final others = words.where((o) => o.emoji != target.emoji).toList()..shuffle(random);
      final same = others.where((o) => o.group == target.group).toList();
      final rest = others.where((o) => o.group != target.group).toList();
      // Distractorii pot să se repete (mulți pe ecran), dar niciunul nu e ținta.
      final pool = axes.similar ? [...same, ...same, ...rest.take(4)] : rest;
      final n = axes.items;
      final distractors = [for (var i = 0; i < n - 1; i++) pool[random.nextInt(pool.length)]];
      final (cols, rows) = grid(n);
      final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(random);
      final objects = [target, ...distractors]..shuffle(random);
      final items = <SearchItem>[];
      for (var i = 0; i < n; i++) {
        final c = cells[i] % cols, r = cells[i] ~/ cols;
        // În celulă, cu o abatere mică (să nu pară o grilă), fără să iasă din ea.
        final jx = (random.nextDouble() - 0.5) * 0.3, jy = (random.nextDouble() - 0.5) * 0.3;
        items.add(SearchItem(
          i,
          objects[i],
          (c + 0.5 + jx) / cols,
          (r + 0.5 + jy) / rows,
          (random.nextDouble() - 0.5) * 0.4,
        ));
      }
      rounds.add(SearchRound(target: target, items: items, cols: cols, rows: rows));
    }
    return SearchLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
