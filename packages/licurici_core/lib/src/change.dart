/// Ce s-a schimbat? (ATN5, catalog #5): copilul privește câteva obiecte, ele se acoperă o
/// clipă, apoi revin cu o schimbare. Detectarea schimbării, atenția susținută și memoria de
/// scurtă durată. Generat din seed (ADR-027): numărul de obiecte (3 → 8), timpul de privit
/// (4 → 2,5 s) și tipul schimbării: a apărut ceva → s-a înlocuit ceva → a dispărut ceva.
/// KPI: acuratețea pe tip de schimbare.
library;

import 'dart:math';

import 'games/vocabular.dart';
import 'grades.dart';
import 'reaction.dart' show ramp;

enum ChangeKind {
  /// Un obiect nou a apărut (copilul îl atinge).
  appear,

  /// Un obiect a fost înlocuit cu altul (copilul atinge noul obiect).
  replace,

  /// Un obiect a dispărut (copilul alege, dintre câteva, ce lipsește).
  disappear,
}

class ChangeItem {
  const ChangeItem(this.object, this.cell);

  final ObjectWord object;

  /// Celula din grilă (index).
  final int cell;
}

class ChangeRound {
  const ChangeRound({
    required this.kind,
    required this.before,
    required this.after,
    required this.target,
    required this.options,
    required this.cols,
    required this.rows,
  });

  final ChangeKind kind;
  final List<ChangeItem> before;
  final List<ChangeItem> after;

  /// Obiectul schimbat: cel nou (apare / înlocuiește) sau cel dispărut.
  final ObjectWord target;

  /// La „a dispărut”: variantele de răspuns (ținta + obiecte care n-au fost în scenă).
  final List<ObjectWord> options;
  final int cols;
  final int rows;

  /// Rostit după schimbare.
  String get question => kind == ChangeKind.disappear ? 'Ce a dispărut?' : 'Ce s-a schimbat?';
}

class ChangeAxes {
  const ChangeAxes({required this.items, required this.lookMs, required this.kinds});

  final int items;
  final int lookMs;
  final List<ChangeKind> kinds;

  Map<String, Object> toJson() =>
      {'items': items, 'lookMs': lookMs, 'kinds': kinds.map((k) => k.name).join(',')};
}

class ChangeLevel {
  const ChangeLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final ChangeAxes axes;
  final List<ChangeRound> rounds;

  /// Cât stă acoperită scena între „înainte” și „după”.
  static const coverMs = 1200;

  Set<String> get art => {
        for (final r in rounds) ...[
          ...r.before.map((i) => i.object.emoji),
          ...r.after.map((i) => i.object.emoji),
          ...r.options.map((o) => o.emoji),
        ],
      };
}

class ChangeAnswer {
  const ChangeAnswer(this.round, {required this.correct, this.chosen, this.ms});

  final ChangeRound round;
  final bool correct;
  final String? chosen;
  final int? ms;
}

class ChangeResult {
  ChangeResult(this.level, List<ChangeAnswer> answers) : answers = List.unmodifiable(answers);

  final ChangeLevel level;
  final List<ChangeAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.correct).length / answers.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class ChangeGame {
  const ChangeGame();

  String get id => 'ce-s-a-schimbat';
  String get name => 'Ce s-a schimbat?';
  String get emoji => '🪄';
  String get description => 'Privește bine și găsește schimbarea';
  Set<Grade> get grades => Grade.parseCodes('G12');
  List<String> get steps => const ['ATN5'];

  ChangeAxes axesFor(int level) => ChangeAxes(
        items: min(8, 2 + (level + 1) ~/ 2),
        lookMs: ramp(level, 4000, 2500, 10).round(),
        kinds: level <= 3
            ? const [ChangeKind.appear]
            : (level <= 6
                ? const [ChangeKind.appear, ChangeKind.replace]
                : const [ChangeKind.appear, ChangeKind.replace, ChangeKind.disappear]),
      );

  ChangeLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final rounds = <ChangeRound>[];
    for (var r = 0; r < 5; r++) {
      final kind = axes.kinds[r % axes.kinds.length];
      final n = axes.items;
      // O celulă în plus pentru obiectul care apare.
      final cols = n <= 3 ? 3 : (n <= 6 ? 3 : 4);
      final rows = ((n + 1) / cols).ceil();
      final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(random);
      final objects = ([...objectWords]..shuffle(random)).take(n + 4).toList();
      final before = [for (var i = 0; i < n; i++) ChangeItem(objects[i], cells[i])];
      final spare = objects.sublist(n);
      late List<ChangeItem> after;
      late ObjectWord target;
      var options = <ObjectWord>[];
      switch (kind) {
        case ChangeKind.appear:
          target = spare.first;
          after = [...before, ChangeItem(target, cells[n])];
        case ChangeKind.replace:
          final k = random.nextInt(n);
          target = spare.first;
          after = [for (final (i, it) in before.indexed) i == k ? ChangeItem(target, it.cell) : it];
        case ChangeKind.disappear:
          final k = random.nextInt(n);
          target = before[k].object;
          after = [for (final (i, it) in before.indexed) if (i != k) it];
          options = [target, ...spare.take(2)]..shuffle(random);
      }
      rounds.add(ChangeRound(
        kind: kind,
        before: before,
        after: after,
        target: target,
        options: options,
        cols: cols,
        rows: rows,
      ));
    }
    return ChangeLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
