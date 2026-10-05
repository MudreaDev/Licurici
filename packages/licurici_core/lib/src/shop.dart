/// La magazin (AUT5, catalog #47): o listă de cumpărături cu poze; copilul găsește pe rafturi
/// produsele de pe listă și le pune în coș. Planificare în viața de zi cu zi. Generat din seed
/// (ADR-027): lista crește (1 → 5 produse), rafturile au tot mai multe produse (6 → 15), iar
/// de la nivelul 6 apar pe raft produse asemănătoare (aceeași grupă).
/// KPI: produse corecte, produse luate în plus (impulsivitate), timpul pe produs.
library;

import 'dart:math';

import 'games/vocabular.dart';
import 'grades.dart';

/// Produsele de magazin (mâncare și lucruri, toate pictate).
final shopProducts = [
  for (final o in objectWords)
    if (o.group == ObjectGroupKind.fructe ||
        o.group == ObjectGroupKind.mancare ||
        o.group == ObjectGroupKind.lucruri ||
        o.group == ObjectGroupKind.jucarii)
      o,
];

class ShopRound {
  const ShopRound({required this.list, required this.shelf});

  /// Ce trebuie cumpărat.
  final List<ObjectWord> list;

  /// Ce e pe raft (include tot ce e pe listă, o singură dată).
  final List<ObjectWord> shelf;
}

class ShopLevel {
  const ShopLevel({required this.gameId, required this.level, required this.seed, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final List<ShopRound> rounds;

  Set<String> get art => {for (final r in rounds) ...r.shelf.map((o) => o.emoji), '🧺'};
}

class ShopTrip {
  const ShopTrip(this.round, {required this.extra, this.ms});

  final ShopRound round;

  /// Atingeri pe produse care nu erau pe listă.
  final int extra;
  final int? ms;

  bool get clean => extra == 0;
}

class ShopResult {
  ShopResult(this.level, List<ShopTrip> trips) : trips = List.unmodifiable(trips);

  final ShopLevel level;
  final List<ShopTrip> trips;

  double get accuracy => trips.isEmpty ? 0 : trips.where((t) => t.clean).length / trips.length;
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class ShopGame {
  const ShopGame();

  String get id => 'la-magazin';
  String get name => 'La magazin';
  String get emoji => '🧺';
  String get description => 'Cumpără ce e pe listă';
  Set<Grade> get grades => Grade.parseCodes('G123');
  List<String> get steps => const ['AUT5'];

  int listFor(int level) => min(5, 1 + (level - 1) ~/ 2);
  int shelfFor(int level) => min(15, 5 + level);

  ShopLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final k = listFor(level), n = shelfFor(level);
    final rounds = <ShopRound>[];
    for (var r = 0; r < 3; r++) {
      final products = [...shopProducts]..shuffle(random);
      final list = products.take(k).toList();
      final rest = products.skip(k).toList();
      // De la nivelul 6, mai întâi produse din aceleași grupe (se confundă mai ușor).
      if (level >= 6) {
        final groups = list.map((o) => o.group).toSet();
        rest.sort((a, b) => (groups.contains(a.group) ? 0 : 1).compareTo(groups.contains(b.group) ? 0 : 1));
      }
      final shelf = [...list, ...rest.take(n - k)]..shuffle(random);
      rounds.add(ShopRound(list: list, shelf: shelf));
    }
    return ShopLevel(gameId: id, level: level, seed: s, rounds: rounds);
  }
}
