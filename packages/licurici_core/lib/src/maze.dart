/// Labirint (FEX6 / MOT, catalog #42): du peștișorul prin labirint până la casă, cu degetul.
/// Planificare și control motor. Labirinturile sunt generate din seed (ADR-027) — „perfecte”
/// (un singur drum între oricare două celule), din ce în ce mai mari: 3 × 2 → 8 × 5.
/// KPI: **eficiența drumului** (drumul cel mai scurt / pașii făcuți), loviri de pereți,
/// timpul de gândire înainte de prima mutare.
library;

import 'dart:collection';
import 'dart:math';

import 'grades.dart';

/// Direcțiile, ca biți în pereții unei celule.
enum MazeDir {
  up(0, -1, 1),
  right(1, 0, 2),
  down(0, 1, 4),
  left(-1, 0, 8);

  const MazeDir(this.dx, this.dy, this.bit);
  final int dx;
  final int dy;
  final int bit;

  MazeDir get opposite => switch (this) {
        MazeDir.up => MazeDir.down,
        MazeDir.down => MazeDir.up,
        MazeDir.left => MazeDir.right,
        MazeDir.right => MazeDir.left,
      };
}

class Maze {
  Maze(this.cols, this.rows, this.walls);

  final int cols;
  final int rows;

  /// Pentru fiecare celulă (r * cols + c), biții pereților care EXISTĂ.
  final List<int> walls;

  int index(int c, int r) => r * cols + c;
  (int, int) cell(int i) => (i % cols, i ~/ cols);

  bool open(int i, MazeDir d) => walls[i] & d.bit == 0;

  /// Vecinul prin direcția [d], dacă nu e perete; altfel null.
  int? step(int i, MazeDir d) {
    if (!open(i, d)) return null;
    final (c, r) = cell(i);
    final nc = c + d.dx, nr = r + d.dy;
    if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) return null;
    return index(nc, nr);
  }

  /// Cel mai scurt drum (celule, inclusiv capetele) — BFS.
  List<int> path(int from, int to) {
    final prev = <int, int>{from: -1};
    final q = Queue<int>()..add(from);
    while (q.isNotEmpty) {
      final i = q.removeFirst();
      if (i == to) break;
      for (final d in MazeDir.values) {
        final n = step(i, d);
        if (n != null && !prev.containsKey(n)) {
          prev[n] = i;
          q.add(n);
        }
      }
    }
    if (!prev.containsKey(to)) return const [];
    final out = <int>[];
    for (var i = to; i != -1; i = prev[i]!) {
      out.add(i);
    }
    return out.reversed.toList();
  }

  /// Labirint perfect: căutare în adâncime cu revenire, pornind din colțul de sus-stânga.
  static Maze generate(int cols, int rows, Random random) {
    final walls = List.filled(cols * rows, 15);
    final seen = List.filled(cols * rows, false);
    final stack = <int>[0];
    seen[0] = true;
    while (stack.isNotEmpty) {
      final i = stack.last;
      final c = i % cols, r = i ~/ cols;
      final options = [
        for (final d in MazeDir.values)
          if (c + d.dx >= 0 && r + d.dy >= 0 && c + d.dx < cols && r + d.dy < rows &&
              !seen[(r + d.dy) * cols + c + d.dx])
            d,
      ];
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = options[random.nextInt(options.length)];
      final n = (r + d.dy) * cols + c + d.dx;
      walls[i] &= ~d.bit;
      walls[n] &= ~d.opposite.bit;
      seen[n] = true;
      stack.add(n);
    }
    return Maze(cols, rows, walls);
  }
}

/// Mersul prin labirint: personajul trece doar pe culoare, câte o celulă (sau câteva, dacă
/// degetul a sărit peste ele pe un drum deschis); încercările prin perete se numără.
class MazeWalker {
  MazeWalker(this.maze, {this.start = 0, int? goal}) : goal = goal ?? maze.cols * maze.rows - 1 {
    position = start;
    visited.add(start);
  }

  final Maze maze;
  final int start;
  final int goal;
  late int position;
  int steps = 0;
  int bumps = 0;
  final visited = <int>{};

  bool get done => position == goal;

  /// Degetul e deasupra celulei [target]. Întoarce true dacă personajul s-a mutat.
  bool toward(int target) {
    if (done || target == position) return false;
    final route = maze.path(position, target);
    // Doar mutări scurte (fără „teleportare” peste labirint).
    if (route.length >= 2 && route.length <= 4) {
      for (final i in route.skip(1)) {
        position = i;
        steps++;
        visited.add(i);
      }
      return true;
    }
    // Celulă vecină, dar cu perete între: o lovire.
    final (c, r) = maze.cell(position);
    final (tc, tr) = maze.cell(target);
    if ((c - tc).abs() + (r - tr).abs() == 1) bumps++;
    return false;
  }

  /// Eficiența: drumul cel mai scurt / pașii făcuți (1 = perfect).
  double get efficiency {
    final best = maze.path(start, goal).length - 1;
    return steps == 0 ? 0 : (best / steps).clamp(0, 1).toDouble();
  }
}

class MazeLevel {
  const MazeLevel({required this.gameId, required this.level, required this.seed, required this.mazes});

  final String gameId;
  final int level;
  final int seed;
  final List<Maze> mazes;
}

class MazeRun {
  const MazeRun(this.maze, {required this.efficiency, required this.bumps, this.ms, this.planMs});

  final Maze maze;
  final double efficiency;
  final int bumps;
  final int? ms;

  /// Timpul până la prima mutare.
  final int? planMs;

  bool get clean => efficiency >= 0.75;
}

class MazeResult {
  MazeResult(this.level, List<MazeRun> runs) : runs = List.unmodifiable(runs);

  final MazeLevel level;
  final List<MazeRun> runs;

  double get accuracy => runs.isEmpty ? 0 : runs.where((r) => r.clean).length / runs.length;
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class MazeGame {
  const MazeGame();

  String get id => 'labirint';
  String get name => 'Labirint';
  String get emoji => '🌀';
  String get description => 'Du peștișorul acasă prin labirint';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['FEX7'];

  (int, int) sizeFor(int level) => (min(8, 2 + level), min(5, 1 + (level + 1) ~/ 2));

  MazeLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final (cols, rows) = sizeFor(level);
    return MazeLevel(
      gameId: id,
      level: level,
      seed: s,
      mazes: [for (var i = 0; i < 3; i++) Maze.generate(cols, rows, random)],
    );
  }
}
