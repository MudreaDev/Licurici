/// Colorează ce auzi (LRC4, fratele lui „Mare, mic, roșu”): Licurici spune „Colorează balonul cu
/// roșu”, iar copilul ia culoarea din borcan și colorează obiectul. Același atribut (culoarea,
/// apoi și mărimea) ca la „Mare, mic, roșu”, alt fel de răspuns — copilul **face** ce a auzit.
///
/// Axe: câte culori în paletă (2 → 6), câte obiecte de ales (1 → 2), de la nivelul 6 același
/// obiect mare și mic („balonul mic cu galben”), de la nivelul 7 două colorări într-o propoziție.
library;

import 'dart:math';

import 'grades.dart';

/// O culoare din paletă: cum se rostește („cu roșu”) și valoarea ARGB (desenul e în aplicație).
enum PaintColor {
  rosu('roșu', 0xFFE5533D),
  albastru('albastru', 0xFF3E7FD6),
  galben('galben', 0xFFF4C430),
  verde('verde', 0xFF4CAF50),
  portocaliu('portocaliu', 0xFFF28C28),
  mov('mov', 0xFF9C5BC7);

  const PaintColor(this.word, this.argb);
  final String word;
  final int argb;
}

/// Un obiect de colorat (un singur fel de culoare în desenul real, ca să aibă sens orice culoare).
class PaintThing {
  const PaintThing(this.emoji, this.word, {this.feminine = false});

  final String emoji;
  final String word;
  final bool feminine;

  /// „mare” / „mic”, „mică”.
  String size(bool big) => big ? 'mare' : (feminine ? 'mică' : 'mic');
}

const paintThings = [
  PaintThing('🎈', 'balonul'),
  PaintThing('🚗', 'mașina', feminine: true),
  PaintThing('👕', 'tricoul'),
  PaintThing('⭐', 'steaua', feminine: true),
  PaintThing('🐟', 'peștele'),
  PaintThing('☂️', 'umbrela', feminine: true),
  PaintThing('🦋', 'fluturele'),
  PaintThing('🏠', 'casa', feminine: true),
];

class PaintAxes {
  const PaintAxes({required this.colors, required this.objects, required this.sized, required this.pair});

  final int colors;
  final int objects;

  /// Obiectele sunt același lucru, mare și mic (mărimea face parte din cerere).
  final bool sized;

  /// Două colorări într-o singură propoziție.
  final bool pair;

  Map<String, Object> toJson() => {'colors': colors, 'objects': objects, 'sized': sized, 'pair': pair};
}

/// Un obiect de pe planșă: ce e și, la nivelurile cu mărime, dacă e cel mare.
class PaintSlot {
  const PaintSlot(this.thing, {this.big});

  final PaintThing thing;

  /// null = fără mărime (un singur obiect de felul ăsta pe planșă).
  final bool? big;

  /// „balonul”, „balonul mic”.
  String get name => big == null ? thing.word : '${thing.word} ${thing.size(big!)}';
}

/// O cerere: ce obiect, cu ce culoare.
class PaintTask {
  const PaintTask(this.slot, this.color);

  final int slot;
  final PaintColor color;
}

class PaintRound {
  const PaintRound({required this.slots, required this.palette, required this.tasks});

  final List<PaintSlot> slots;
  final List<PaintColor> palette;
  final List<PaintTask> tasks;

  /// „Colorează balonul cu roșu” (+ „și” + „balonul mic cu albastru”).
  List<String> get speak => [
        'Colorează ${slots[tasks.first.slot].name} cu ${tasks.first.color.word}',
        for (final t in tasks.skip(1)) ...['și', '${slots[t.slot].name} cu ${t.color.word}'],
      ];
}

class PaintLevel {
  const PaintLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final PaintAxes axes;
  final List<PaintRound> rounds;
}

/// O cerere dusă la capăt: câte colorări greșite și cât a durat.
class PaintAnswer {
  const PaintAnswer(this.round, {required this.wrong, required this.ms, this.firstWrong});

  final PaintRound round;
  final int wrong;
  final int ms;

  /// Prima greșeală, ca „obiect:culoare” (ex. „balonul mic:albastru”) — pentru confuzii.
  final String? firstWrong;

  bool get clean => wrong == 0;
}

class PaintResult {
  PaintResult(this.level, List<PaintAnswer> answers) : answers = List.unmodifiable(answers);

  final PaintLevel level;
  final List<PaintAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.clean).length / answers.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (answers.isEmpty) return current;
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class PaintGame {
  const PaintGame();

  String get id => 'coloreaza-ce-auzi';
  String get name => 'Colorează ce auzi';
  String get emoji => '🖍️';
  String get description => 'Ia culoarea spusă și colorează';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['LRC4'];

  /// Câte cereri pe nivel.
  static const rounds = 5;

  PaintAxes axesFor(int level) => PaintAxes(
        colors: switch (level) { 1 => 2, 2 => 3, 3 || 4 => 4, _ => 6 },
        objects: level >= 4 ? 2 : 1,
        sized: level >= 6,
        pair: level >= 7,
      );

  PaintLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final list = <PaintRound>[];
    PaintColor? last;
    for (var r = 0; r < rounds; r++) {
      final things = [...paintThings]..shuffle(random);
      final slots = axes.sized
          ? ([PaintSlot(things.first, big: true), PaintSlot(things.first, big: false)]..shuffle(random))
          : [for (final t in things.take(axes.objects)) PaintSlot(t)];
      // Paleta: culorile în ordine fixă (copilul le găsește mereu în același loc).
      final chosen = ([...PaintColor.values]..shuffle(random)).take(axes.colors).toSet();
      final palette = [for (final c in PaintColor.values) if (chosen.contains(c)) c];
      final colors = [for (final c in palette) if (c != last) c]..shuffle(random);
      final first = PaintTask(random.nextInt(slots.length), colors.first);
      last = first.color;
      final tasks = [
        first,
        if (axes.pair) PaintTask(1 - first.slot, colors[1]),
      ];
      list.add(PaintRound(slots: slots, palette: palette, tasks: tasks));
    }
    return PaintLevel(gameId: id, level: level, seed: s, axes: axes, rounds: list);
  }
}
