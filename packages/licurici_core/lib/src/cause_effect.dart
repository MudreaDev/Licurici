/// Atinge și vezi (COG1, catalog #24): orice atingere pe un obiect produce o reacție veselă —
/// floarea înflorește, peștele sare, balonul zboară, toba bate. Cel mai mic nivel al
/// cogniției: legătura cauză–efect („când ating, se întâmplă ceva”). Generat din seed
/// (ADR-027): de la un singur obiect mare, în mijloc, la șase obiecte mai mici.
/// KPI: **atingeri intenționate** (pe obiecte) față de atingerile pe lângă.
library;

import 'dart:math';

import 'grades.dart';

/// Ce face obiectul când e atins.
enum CauseReaction {
  /// Crește și se rotește puțin (floarea înflorește).
  bloom,

  /// Sare în sus și aterizează.
  jump,

  /// Se ridică plutind, apoi coboară.
  float,

  /// Bate (toba): se turtește și sună.
  bang,

  /// Se învârte o dată, cu sclipiri.
  spin,
}

class CauseObject {
  const CauseObject(this.emoji, this.reaction, {this.sound});

  final String emoji;
  final CauseReaction reaction;

  /// Ce se aude (o frază din vocea înregistrată, ex. „ham, ham”); null = un sunet scurt.
  final String? sound;
}

const causeObjects = [
  CauseObject('🌸', CauseReaction.bloom),
  CauseObject('🌷', CauseReaction.bloom),
  CauseObject('🐶', CauseReaction.jump, sound: 'ham, ham'),
  CauseObject('🐱', CauseReaction.jump, sound: 'miau'),
  CauseObject('🦆', CauseReaction.jump, sound: 'mac, mac'),
  CauseObject('🐄', CauseReaction.jump, sound: 'muuu'),
  CauseObject('🎈', CauseReaction.float),
  CauseObject('🦋', CauseReaction.float),
  CauseObject('🥁', CauseReaction.bang),
  CauseObject('⭐', CauseReaction.spin),
  CauseObject('⚽', CauseReaction.jump),
  CauseObject('🐝', CauseReaction.spin, sound: 'bzzz'),
];

class CausePlacement {
  const CausePlacement(this.object, this.x, this.y);

  final CauseObject object;

  /// Centrul (0…1).
  final double x;
  final double y;
}

class CauseLevel {
  const CauseLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.objects,
    required this.size,
    required this.goal,
  });

  final String gameId;
  final int level;
  final int seed;
  final List<CausePlacement> objects;

  /// Mărimea unui obiect, ca fracție din înălțimea zonei.
  final double size;

  /// Câte reacții are o rundă (apoi vine finalul cu abțibildul).
  final int goal;

  Set<String> get art => {for (final o in objects) o.object.emoji};
}

/// O atingere: pe un obiect (intenționată) sau pe lângă.
class CauseTouch {
  const CauseTouch({required this.onObject, this.object, this.sinceLastMs});

  final bool onObject;
  final String? object;

  /// Timpul de la atingerea precedentă (ritmul implicării).
  final int? sinceLastMs;
}

class CauseResult {
  CauseResult(this.level, List<CauseTouch> touches) : touches = List.unmodifiable(touches);

  final CauseLevel level;
  final List<CauseTouch> touches;

  int get onObject => touches.where((t) => t.onObject).length;
  int get offObject => touches.length - onObject;

  /// Proporția atingerilor intenționate.
  double get intentional => touches.isEmpty ? 0 : onObject / touches.length;

  /// Câte obiecte diferite a încercat (explorare).
  int get explored => {for (final t in touches) if (t.object != null) t.object}.length;

  /// Mereu cel puțin 2 stele: aici nu există greșeli; 3 când atingerile sunt țintite.
  int get stars => intentional >= 0.7 ? 3 : 2;

  /// Atingeri țintite → mai multe obiecte; multe atingeri pe lângă → mai puține.
  int suggestedNextLevel(int current) {
    if (intentional >= 0.8) return current + 1;
    if (intentional < 0.4) return max(1, current - 1);
    return current;
  }
}

class CauseGame {
  const CauseGame();

  String get id => 'atinge-si-vezi';
  String get name => 'Atinge și vezi';
  String get emoji => '🌸';
  String get description => 'Atinge și vezi ce se întâmplă';
  Set<Grade> get grades => Grade.parseCodes('G');
  List<String> get steps => const ['COG1'];

  int countFor(int level) => min(6, level);

  CauseLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final n = countFor(level);
    final picked = ([...causeObjects]..shuffle(random)).take(n).toList();
    // Așezare pe o grilă de 3 × 2 (sau în mijloc, pentru unul singur), cu mică abatere.
    final cols = n <= 1 ? 1 : (n <= 2 ? 2 : 3);
    final rows = n <= 3 ? 1 : 2;
    final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(random);
    final objects = <CausePlacement>[];
    for (var i = 0; i < n; i++) {
      final c = cells[i] % cols, r = cells[i] ~/ cols;
      objects.add(CausePlacement(
        picked[i],
        (c + 0.5) / cols + (random.nextDouble() - 0.5) * 0.08,
        rows == 1 ? 0.52 : (r + 0.5) / rows * 0.85 + 0.08,
      ));
    }
    return CauseLevel(
      gameId: id,
      level: level,
      seed: s,
      objects: objects,
      size: n == 1 ? 0.5 : (n <= 3 ? 0.36 : 0.28),
      goal: 10,
    );
  }
}
