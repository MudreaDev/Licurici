/// Regula se schimbă (FEX3–4, catalog #38): cartonașe cu o formă colorată se pun în una din
/// două cutii — întâi după **culoare**, apoi regula se schimbă: după **formă**. Paradigma
/// „Dimensional Change Card Sort” (flexibilitate cognitivă). Nivelurile sunt generate din seed
/// (ADR-027): o singură regulă (FEX3) → o schimbare anunțată → mai multe schimbări → regula
/// amestecată, arătată pe fiecare cartonaș (FEX4).
/// KPI: **erori perseverative** (sortează după regula veche) și **costul schimbării** (TR).
library;

import 'dart:math';

import 'grades.dart';

enum SortRule { color, shape }

class CardColor {
  const CardColor(this.id, this.name, this.argb);
  final String id;
  final String name;
  final int argb;
}

class CardShape {
  const CardShape(this.id, this.name);
  final String id;

  /// Numele rostit („steaua”).
  final String name;
}

const cardColors = [
  CardColor('rosu', 'roșu', 0xFFE36A6A),
  CardColor('albastru', 'albastru', 0xFF4F8FD0),
  CardColor('galben', 'galben', 0xFFF2C53D),
  CardColor('verde', 'verde', 0xFF5DB37E),
];

const cardShapes = [
  CardShape('stea', 'steaua'),
  CardShape('cerc', 'cercul'),
  CardShape('inima', 'inima'),
  CardShape('patrat', 'pătratul'),
];

class SwitchCard {
  const SwitchCard(this.color, this.shape);
  final CardColor color;
  final CardShape shape;

  String get id => '${color.id}-${shape.id}';

  @override
  bool operator ==(Object other) => other is SwitchCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Un cartonaș de sortat și regula după care se sortează.
class SwitchItem {
  const SwitchItem({required this.index, required this.card, required this.rule, required this.answer});

  final int index;
  final SwitchCard card;
  final SortRule rule;

  /// Cutia corectă: 0 (stânga) sau 1 (dreapta).
  final int answer;

  /// Cutia în care ar merge după cealaltă regulă (mereu cealaltă cutie).
  int get otherRuleAnswer => 1 - answer;
}

class SwitchAxes {
  const SwitchAxes({required this.blocks, required this.perBlock, required this.mixed});

  /// Câte blocuri cu aceeași regulă (1 = fără schimbare).
  final int blocks;
  final int perBlock;

  /// Regula se schimbă de la un cartonaș la altul (arătată pe cartonaș).
  final bool mixed;

  Map<String, Object> toJson() => {'blocks': blocks, 'perBlock': perBlock, 'mixed': mixed};
}

class SwitchLevel {
  const SwitchLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.targets,
    required this.items,
  });

  final String gameId;
  final int level;
  final int seed;
  final SwitchAxes axes;

  /// Cartonașele model de pe cele două cutii (diferă și ca formă, și ca culoare).
  final List<SwitchCard> targets;
  final List<SwitchItem> items;

  /// Indicii unde se schimbă regula (primul cartonaș cu regula nouă).
  List<int> get switches => [
        for (var i = 1; i < items.length; i++)
          if (items[i].rule != items[i - 1].rule) i,
      ];
}

/// Cum a sortat copilul un cartonaș.
class SwitchResponse {
  const SwitchResponse(this.item, {required this.chosen, this.ms});

  final SwitchItem item;
  final int chosen;
  final int? ms;

  bool get correct => chosen == item.answer;

  /// Greșeala de perseverare: a pus după cealaltă regulă (în acest joc, orice greșeală).
  bool get perseverative => !correct;
}

class SwitchResult {
  SwitchResult(this.level, List<SwitchResponse> responses) : responses = List.unmodifiable(responses);

  final SwitchLevel level;
  final List<SwitchResponse> responses;

  double get accuracy =>
      responses.isEmpty ? 0 : responses.where((r) => r.correct).length / responses.length;

  /// Erorile din primele trei cartonașe după fiecare schimbare (perseverare).
  int get perseverativeErrors {
    final after = <int>{
      for (final s in level.switches)
        for (var i = s; i < min(s + 3, level.items.length); i++) i,
    };
    return responses.where((r) => after.contains(r.item.index) && !r.correct).length;
  }

  /// Costul schimbării: TR median pe cartonașele de după schimbare − TR median în rest (ms).
  int? get switchCostMs {
    final sw = level.switches.toSet();
    int? median(Iterable<int> xs) {
      final l = xs.toList()..sort();
      return l.isEmpty ? null : l[l.length ~/ 2];
    }

    final post = median([for (final r in responses) if (sw.contains(r.item.index) && r.ms != null) r.ms!]);
    final rest = median([for (final r in responses) if (!sw.contains(r.item.index) && r.ms != null) r.ms!]);
    return post == null || rest == null ? null : post - rest;
  }

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.9) return current + 1;
    if (accuracy < 0.6) return max(1, current - 1);
    return current;
  }
}

class SwitchGame {
  const SwitchGame();

  String get id => 'regula-se-schimba';
  String get name => 'Regula se schimbă';
  String get emoji => '🔀';
  String get description => 'Sortează după culoare, apoi după formă';
  Set<Grade> get grades => Grade.parseCodes('G12');
  List<String> get steps => const ['FEX3', 'FEX4'];

  SwitchAxes axesFor(int level) => switch (level) {
        1 || 2 => const SwitchAxes(blocks: 1, perBlock: 6, mixed: false),
        3 || 4 => const SwitchAxes(blocks: 2, perBlock: 5, mixed: false),
        5 || 6 => const SwitchAxes(blocks: 3, perBlock: 4, mixed: false),
        _ => const SwitchAxes(blocks: 1, perBlock: 12, mixed: true),
      };

  /// Rostit când începe un bloc (sau, la regula amestecată, la începutul jocului).
  static String announce(SortRule rule) =>
      rule == SortRule.color ? 'Acum sortăm după culoare.' : 'Acum sortăm după formă.';

  SwitchLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final colors = ([...cardColors]..shuffle(random)).take(2).toList();
    final shapes = ([...cardShapes]..shuffle(random)).take(2).toList();
    // Cutia 0: culoarea 0 + forma 0; cutia 1: culoarea 1 + forma 1.
    final targets = [SwitchCard(colors[0], shapes[0]), SwitchCard(colors[1], shapes[1])];
    // Cartonașele de sortat combină culoarea unei cutii cu forma celeilalte: regula decide.
    final conflict = [SwitchCard(colors[0], shapes[1]), SwitchCard(colors[1], shapes[0])];

    final rules = <SortRule>[];
    if (axes.mixed) {
      // Amestecat: cel puțin 4 schimbări, cel mult 3 la rând cu aceeași regulă.
      do {
        rules
          ..clear()
          ..addAll([for (var i = 0; i < axes.perBlock; i++) random.nextBool() ? SortRule.color : SortRule.shape]);
      } while (_switchCount(rules) < 4 || _maxRun(rules) > 3);
    } else {
      for (var b = 0; b < axes.blocks; b++) {
        rules.addAll(List.filled(axes.perBlock, b.isEven ? SortRule.color : SortRule.shape));
      }
    }

    final items = <SwitchItem>[];
    for (final (i, rule) in rules.indexed) {
      // Echilibrat: cartonașele alternează aleator, fără mai mult de 2 la fel la rând.
      SwitchCard card;
      do {
        card = conflict[random.nextInt(2)];
      } while (items.length >= 2 && items[items.length - 1].card == card && items[items.length - 2].card == card);
      final answer = rule == SortRule.color
          ? (card.color == targets[0].color ? 0 : 1)
          : (card.shape == targets[0].shape ? 0 : 1);
      items.add(SwitchItem(index: i, card: card, rule: rule, answer: answer));
    }
    return SwitchLevel(gameId: id, level: level, seed: s, axes: axes, targets: targets, items: items);
  }

  static int _switchCount(List<SortRule> r) {
    var n = 0;
    for (var i = 1; i < r.length; i++) {
      if (r[i] != r[i - 1]) n++;
    }
    return n;
  }

  static int _maxRun(List<SortRule> r) {
    var best = 0, run = 0;
    SortRule? prev;
    for (final x in r) {
      run = x == prev ? run + 1 : 1;
      prev = x;
      best = max(best, run);
    }
    return best;
  }
}
