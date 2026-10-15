/// Oglinda (IMI1–3, fratele lui „Fă ca Licurici”): Licurici atinge o parte a feței unui prieten
/// (nasul, gura, părul, un ochi, o ureche), iar copilul face la fel pe fața din oglindă. Aceeași
/// imitație cu model, alt material — propriul corp, desenat (fețele din `face.dart`).
///
/// Axe: câte părți (3 → 5), câte atingeri de repetat (1 → 3), dacă partea contează (ochiul din
/// stânga ≠ cel din dreapta, de la nivelul 4) și, de la nivelul 6, fața din oglindă e alt copil
/// decât modelul (generalizare).
library;

import 'dart:math';

import 'face.dart';
import 'grades.dart';

enum FacePart {
  par('părul'),
  nas('nasul'),
  gura('gura'),
  ochi('ochiul'),
  urechi('urechea');

  const FacePart(this.word);
  final String word;

  /// Are două părți (stânga / dreapta).
  bool get paired => this == ochi || this == urechi;
}

/// O atingere: partea și, la ochi / urechi, latura văzută pe ecran (−1 stânga, +1 dreapta).
class MirrorTouch {
  const MirrorTouch(this.part, [this.side]);

  final FacePart part;
  final int? side;

  /// Pentru înregistrări: „nasul”, „ochiul-stanga”.
  String get id => side == null ? part.word : '${part.word}-${side! < 0 ? 'stanga' : 'dreapta'}';

  /// Atingerea copilului [other] e aceeași? Când latura nu contează ([side] null), orice ochi merge.
  bool accepts(MirrorTouch other) => other.part == part && (side == null || other.side == side);

  @override
  bool operator ==(Object other) => other is MirrorTouch && other.part == part && other.side == side;

  @override
  int get hashCode => Object.hash(part, side);
}

class MirrorAxes {
  const MirrorAxes({required this.parts, required this.touches, required this.sided, required this.otherChild});

  final List<FacePart> parts;
  final int touches;
  final bool sided;
  final bool otherChild;

  Map<String, Object> toJson() => {'parts': [for (final p in parts) p.name], 'touches': touches, 'sided': sided, 'otherChild': otherChild};
}

class MirrorRound {
  const MirrorRound({required this.model, required this.mirror, required this.touches});

  /// Fața pe care o atinge Licurici și fața din oglindă (la fel până la nivelul 6).
  final FaceLook model;
  final FaceLook mirror;
  final List<MirrorTouch> touches;
}

class MirrorLevel {
  const MirrorLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final MirrorAxes axes;
  final List<MirrorRound> rounds;
}

/// O imitație dusă la capăt: câte atingeri greșite și cât a durat (de la „Acum tu!”).
class MirrorAnswer {
  const MirrorAnswer(this.round, {required this.wrong, required this.ms, this.firstWrong, this.modelRepeated = false});

  final MirrorRound round;
  final int wrong;
  final int ms;
  final MirrorTouch? firstWrong;

  /// Licurici a arătat din nou (după greșeli sau la cerere) — ajutor prin model.
  final bool modelRepeated;

  bool get clean => wrong == 0;
}

class MirrorResult {
  MirrorResult(this.level, List<MirrorAnswer> answers) : answers = List.unmodifiable(answers);

  final MirrorLevel level;
  final List<MirrorAnswer> answers;

  double get accuracy => answers.isEmpty ? 0 : answers.where((a) => a.clean).length / answers.length;

  int get stars => accuracy >= 0.8 ? 3 : (accuracy >= 0.5 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (answers.isEmpty) return current;
    if (accuracy >= 0.8) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

class MirrorGame {
  const MirrorGame();

  String get id => 'oglinda';
  String get name => 'Oglinda';
  String get emoji => '👦';
  String get description => 'Atinge ce a atins Licurici';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['IMI1', 'IMI2', 'IMI3'];

  static const rounds = 5;
  static const instruction = 'Uită-te la Licurici.';

  MirrorAxes axesFor(int level) => MirrorAxes(
        parts: level == 1 ? const [FacePart.par, FacePart.nas, FacePart.gura] : FacePart.values,
        touches: level <= 2 ? 1 : (level <= 4 ? 2 : 3),
        sided: level >= 4,
        otherChild: level >= 6,
      );

  MirrorLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final list = <MirrorRound>[];
    for (var r = 0; r < rounds; r++) {
      final model = FaceLook.random(random);
      var mirror = model;
      while (axes.otherChild && mirror.differences(model) < 3) {
        mirror = FaceLook.random(random);
      }
      final touches = <MirrorTouch>[];
      while (touches.length < axes.touches) {
        final p = axes.parts[random.nextInt(axes.parts.length)];
        final t = MirrorTouch(p, p.paired && axes.sided ? (random.nextBool() ? -1 : 1) : null);
        // Nu de două ori la rând același loc (s-ar vedea ca o singură atingere).
        if (touches.isNotEmpty && touches.last == t) continue;
        touches.add(t);
      }
      list.add(MirrorRound(model: model, mirror: mirror, touches: touches));
    }
    return MirrorLevel(gameId: id, level: level, seed: s, axes: axes, rounds: list);
  }
}
