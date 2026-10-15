/// Găsește diferențele (POT8, catalog #12): două scene cu obiecte, aproape la fel; copilul
/// atinge în scena din dreapta locurile unde e altfel (obiect înlocuit, lipsă sau în plus).
/// Discriminare vizuală și scanare atentă. Generat din seed (ADR-027): 1 → 5 diferențe,
/// 4 → 12 obiecte, de la înlocuiri evidente la obiecte din aceeași grupă.
/// KPI: diferențe găsite pe minut și atingerile greșite.
library;

import 'dart:math';

import 'avoid.dart' show safeWords;
import 'games/vocabular.dart';
import 'grades.dart';

enum DiffKind { replaced, missing, extra }

class DiffScene {
  const DiffScene({
    required this.cols,
    required this.rows,
    required this.left,
    required this.right,
    required this.differences,
  });

  final int cols;
  final int rows;

  /// Celulă → obiect, în fiecare scenă (celulele lipsă sunt goale).
  final Map<int, ObjectWord> left;
  final Map<int, ObjectWord> right;

  /// Celulele diferite și felul diferenței.
  final Map<int, DiffKind> differences;
}

class DiffLevel {
  const DiffLevel({required this.gameId, required this.level, required this.seed, required this.scenes});

  final String gameId;
  final int level;
  final int seed;
  final List<DiffScene> scenes;

  Set<String> get art => {
        for (final s in scenes) ...[...s.left.values.map((o) => o.emoji), ...s.right.values.map((o) => o.emoji)],
      };
}

class DiffSolve {
  const DiffSolve(this.scene, {required this.wrongTaps, this.ms});

  final DiffScene scene;
  final int wrongTaps;
  final int? ms;

  bool get clean => wrongTaps <= scene.differences.length ~/ 3;
}

class DiffResult {
  DiffResult(this.level, List<DiffSolve> solves) : solves = List.unmodifiable(solves);

  final DiffLevel level;
  final List<DiffSolve> solves;

  double get accuracy => solves.isEmpty ? 0 : solves.where((s) => s.clean).length / solves.length;
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class SpotDiffGame {
  const SpotDiffGame();

  String get id => 'diferente';
  String get name => 'Găsește diferențele';
  String get emoji => '🔎';
  String get description => 'Ce e altfel în poza a doua?';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['POT8'];

  int differencesFor(int level) => min(6, 1 + (level - 1) ~/ 2);
  int itemsFor(int level) => min(16, 3 + level);

  /// [avoid]: imaginile pe care copilul nu trebuie să le vadă (`avoidedEmojis`) nu apar deloc.
  DiffLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    final words = safeWords(avoid);
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final n = itemsFor(level), k = differencesFor(level);
    final similar = level >= 6;
    final scenes = <DiffScene>[];
    for (var sc = 0; sc < 3; sc++) {
      final cols = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
      final rows = ((n + 2) / cols).ceil();
      final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(random);
      final objects = ([...words]..shuffle(random)).take(n).toList();
      final left = {for (var i = 0; i < n; i++) cells[i]: objects[i]};
      final right = Map.of(left);
      final differences = <int, DiffKind>{};
      final free = cells.skip(n).toList();
      final used = [...cells.take(n)]..shuffle(random);
      for (var d = 0; d < k; d++) {
        final kind = d == 0 ? DiffKind.replaced : DiffKind.values[random.nextInt(3)];
        switch (kind) {
          case DiffKind.replaced || DiffKind.missing:
            final cell = used.removeLast();
            if (kind == DiffKind.missing) {
              right.remove(cell);
            } else {
              final old = left[cell]!;
              final pool = words
                  .where((o) => !left.containsValue(o) && !right.containsValue(o))
                  .where((o) => !similar || o.group == old.group)
                  .toList();
              final fallback = words.where((o) => !left.containsValue(o) && !right.containsValue(o)).toList();
              final list = pool.isEmpty ? fallback : pool;
              right[cell] = list[random.nextInt(list.length)];
            }
            differences[cell] = kind;
          case DiffKind.extra:
            if (free.isEmpty) {
              d--;
              continue;
            }
            final cell = free.removeLast();
            final pool = words.where((o) => !left.containsValue(o) && !right.containsValue(o)).toList();
            right[cell] = pool[random.nextInt(pool.length)];
            differences[cell] = DiffKind.extra;
        }
      }
      scenes.add(DiffScene(cols: cols, rows: rows, left: left, right: right, differences: differences));
    }
    return DiffLevel(gameId: id, level: level, seed: s, scenes: scenes);
  }
}
