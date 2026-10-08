/// Mecanica `sequence` pentru memoria de lucru (catalog: `simon`, FEX5): felinarele se aprind
/// pe rând, copilul le atinge în aceeași ordine (sau invers, la niveluri mari).
/// Niveluri generate procedural (ADR-027): nivel → axe → secvență, deterministă pentru un seed.
library;

import 'dart:math';

import 'grades.dart';
import 'reaction.dart' show ramp;

/// Un felinar (buton) de pe ecran: culoare + nota pe care o cântă.
class SequencePad {
  const SequencePad(this.index, this.argb, this.note);
  final int index;
  final int argb;

  /// Treapta muzicală (0 = do …), pentru sunetul generat de UI.
  final int note;
}

/// Culori calme, distincte și pentru daltonism (fără perechi roșu/verde vecine).
const _padColors = [0xFFF2CF6B, 0xFF5B9BB5, 0xFFE79B86, 0xFF6BBF8A, 0xFFA9A3D1, 0xFFF0A9C0];

class SequenceAxes {
  const SequenceAxes({
    required this.pads,
    required this.length,
    required this.onMs,
    required this.gapMs,
    required this.reverse,
    required this.withSound,
  });

  /// Câte felinare sunt pe ecran (3 → 6).
  final int pads;

  /// Lungimea secvenței (span-ul cerut).
  final int length;

  /// Cât stă aprins un felinar, ms. Cu [gapMs] ≥ 250 → maxim ~1,3 aprinderi/s (sigur).
  final int onMs;
  final int gapMs;

  /// Copilul repetă secvența de la coadă la cap (memorie de lucru „inversă”).
  final bool reverse;

  /// Fiecare felinar cântă nota lui; la niveluri mari doar lumina (mai greu).
  final bool withSound;

  Map<String, num> toJson() => {
        'pads': pads,
        'length': length,
        'onMs': onMs,
        'gapMs': gapMs,
        'reverse': reverse ? 1 : 0,
        'withSound': withSound ? 1 : 0,
      };
}

class SequenceLevel {
  const SequenceLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.pads,
    required this.sequence,
    required this.instruction,
    this.positions,
  });

  final String gameId;
  final int level;
  final int seed;
  final SequenceAxes axes;
  final List<SequencePad> pads;

  /// Indicii felinarelor, în ordinea aprinderii.
  final List<int> sequence;

  /// Unde stă fiecare felinar în zona de joc (0…1), dacă jocul îi împrăștie (Corsi); altfel
  /// stau pe un rând.
  final List<Point<double>>? positions;
  final String instruction;

  /// Ordinea în care trebuie atinse.
  List<int> get expected => axes.reverse ? sequence.reversed.toList() : sequence;
}

/// Rezultatul unei încercări: span-ul atins = câte atingeri corecte la rând de la început.
class SequenceResult {
  SequenceResult(this.level, this.taps);

  final SequenceLevel level;
  final List<int> taps;

  int get correctPrefix {
    final exp = level.expected;
    var i = 0;
    while (i < taps.length && i < exp.length && taps[i] == exp[i]) {
      i++;
    }
    return i;
  }

  bool get complete => correctPrefix == level.expected.length;

  /// Nivelul următor (stil „span adaptiv”): reușit → +1; greșit devreme → −1; altfel rămâne.
  int suggestedNextLevel(int current) {
    if (complete) return current + 1;
    if (correctPrefix < level.expected.length ~/ 2) return max(1, current - 1);
    return current;
  }
}

/// Un joc pe mecanica `sequence` (Felinarele, Licuricii din grădină).
abstract class SequenceGame {
  const SequenceGame();

  String get id;
  String get name;
  String get emoji;
  String get description;
  Set<Grade> get grades;
  List<String> get steps;
  SequenceLevel generate(int level, {int? seed});
}

class SimonGame extends SequenceGame {
  const SimonGame();

  @override
  String get id => 'simon';
  @override
  String get name => 'Felinarele';
  @override
  String get emoji => '💡';
  @override
  String get description => 'Ține minte ordinea luminilor';
  Subject get subject => Subject.forme;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1234');
  @override
  List<String> get steps => const ['FEX5'];

  SequenceAxes axesFor(int level) => SequenceAxes(
        pads: ramp(level, 3, 6, 12).round(),
        // Span 2 → 7: crește la fiecare ~3 niveluri, ca între două lungimi să fie timp de consolidare.
        length: min(7, 2 + (level - 1) ~/ 3),
        onMs: ramp(level, 900, 550, 18).round(),
        gapMs: ramp(level, 450, 280, 18).round(),
        reverse: level >= 19,
        withSound: level < 25,
      );

  @override
  SequenceLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final seq = <int>[];
    while (seq.length < axes.length) {
      final next = random.nextInt(axes.pads);
      // Fără același felinar de două ori la rând la span mic (se confundă cu o singură aprindere).
      if (seq.isNotEmpty && seq.last == next && axes.length <= 4) continue;
      seq.add(next);
    }
    return SequenceLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      pads: [for (var i = 0; i < axes.pads; i++) SequencePad(i, _padColors[i], i * 2)],
      sequence: seq,
      instruction: axes.reverse
          ? 'Privește felinarele. Apoi atinge-le invers, de la ultimul.'
          : 'Privește felinarele. Apoi atinge-le în aceeași ordine.',
    );
  }
}

/// Licuricii din grădină (FEX5b, catalog pe arii #40, sarcina Corsi): licurici **identici**,
/// așezați pe flori împrăștiate prin grădină, se aprind pe rând; copilul atinge florile în
/// aceeași ordine. Doar locul îi deosebește (memorie vizuo-spațială), fără culori și fără note.
/// Axe: câte flori (5 → 9), lungimea secvenței (span 2 → 7), viteza, ordinea inversă.
class SpatialSpanGame extends SequenceGame {
  const SpatialSpanGame();

  @override
  String get id => 'licuricii';
  @override
  String get name => 'Licuricii din grădină';
  @override
  String get emoji => '✨';
  @override
  String get description => 'Ține minte unde s-au aprins';
  @override
  Set<Grade> get grades => Grade.parseCodes('G1234');
  @override
  List<String> get steps => const ['FEX5b'];

  SequenceAxes axesFor(int level) => SequenceAxes(
        pads: ramp(level, 5, 9, 12).round(),
        length: min(7, 2 + (level - 1) ~/ 3),
        onMs: ramp(level, 900, 600, 18).round(),
        gapMs: ramp(level, 450, 300, 18).round(),
        reverse: level >= 19,
        withSound: false,
      );

  /// Locurile florilor: împrăștiate, la cel puțin 0,22 una de alta (ca degetul să nu le
  /// încurce), departe de margini.
  static List<Point<double>> scatter(int n, Random r) {
    final out = <Point<double>>[];
    var tries = 0;
    while (out.length < n && tries < 5000) {
      tries++;
      final p = Point(0.1 + r.nextDouble() * 0.8, 0.14 + r.nextDouble() * 0.72);
      final minD = tries > 3000 ? 0.16 : 0.22;
      if (out.every((q) => q.distanceTo(p) >= minD)) out.add(p);
    }
    return out;
  }

  @override
  SequenceLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final positions = scatter(axes.pads, random);
    final seq = <int>[];
    while (seq.length < axes.length) {
      final next = random.nextInt(axes.pads);
      if (seq.isNotEmpty && seq.last == next) continue;
      seq.add(next);
    }
    return SequenceLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      pads: [for (var i = 0; i < axes.pads; i++) SequencePad(i, 0xFFF2CF6B, 4)],
      sequence: seq,
      positions: positions,
      instruction: axes.reverse
          ? 'Privește licuricii. Apoi atinge florile invers, de la ultima.'
          : 'Privește licuricii. Apoi atinge florile în aceeași ordine.',
    );
  }
}
