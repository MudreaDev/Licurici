/// Acum sau mai mult? (FEX1b, amânarea recompensei — varianta pe ecran a „testului
/// bezelei”): Licurici oferă **o stea acum** sau **mai multe stele dacă aștepți** câteva
/// secunde. Dacă alege să aștepte, borcanul se umple încet; copilul poate oricând să ia steaua
/// mică (fără reproș). Stelele sunt cele adevărate, din pușculița acvariului.
///
/// Măsuri: cât de des alege să aștepte și cât de des duce așteptarea până la capăt; timpul
/// așteptat. Axe: cât durează așteptarea (5 s → 30 s) și cât de mare e câștigul (3 stele → 2).
library;

import 'dart:math';

import 'grades.dart';

class DelayOffer {
  const DelayOffer({required this.waitMs, required this.later});

  /// Cât trebuie așteptat pentru recompensa mare.
  final int waitMs;

  /// Câte stele dacă așteaptă (acum = 1).
  final int later;
}

class DelayLevel {
  const DelayLevel({required this.gameId, required this.level, required this.seed, required this.offers});

  final String gameId;
  final int level;
  final int seed;
  final List<DelayOffer> offers;
}

/// Ce a făcut copilul la o ofertă.
class DelayChoice {
  const DelayChoice(this.offer, {required this.waited, required this.completed, this.waitedMs = 0, this.latencyMs});

  final DelayOffer offer;

  /// A ales să aștepte.
  final bool waited;

  /// A așteptat până la capăt.
  final bool completed;

  /// Cât a așteptat (ms).
  final int waitedMs;

  /// Cât s-a gândit înainte să aleagă.
  final int? latencyMs;

  int get stars => completed ? offer.later : 1;
}

class DelayResult {
  DelayResult(this.level, List<DelayChoice> choices) : choices = List.unmodifiable(choices);

  final DelayLevel level;
  final List<DelayChoice> choices;

  /// Cât de des a dus așteptarea până la capăt (0…1).
  double get completedRate => choices.isEmpty ? 0 : choices.where((c) => c.completed).length / choices.length;

  int get starsWon => choices.fold(0, (a, c) => a + c.stars);

  /// Stelele finale: efortul contează, nu doar așteptarea.
  int get stars => completedRate >= 0.75 ? 3 : (completedRate >= 0.25 ? 2 : 1);

  /// Așteptare mai lungă dacă a reușit aproape mereu; mai scurtă dacă n-a reușit deloc.
  int suggestedNextLevel(int current) {
    if (choices.isEmpty) return current;
    if (completedRate >= 0.75) return current + 1;
    if (completedRate == 0) return max(1, current - 1);
    return current;
  }
}

class DelayGame {
  const DelayGame();

  String get id => 'acum-sau-mai-mult';
  String get name => 'Acum sau mai mult?';
  String get emoji => '⏳';
  String get description => 'O stea acum sau mai multe dacă aștepți';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['FEX1b'];

  /// Câte oferte pe nivel.
  static const count = 4;

  /// Cât se așteaptă la [level] (5 s → 30 s la nivelul 9).
  int waitMsFor(int level) => min(30000, 5000 + 3125 * (level - 1));

  /// Câte stele aduce așteptarea (3 până la nivelul 5, apoi 2).
  int laterFor(int level) => level <= 5 ? 3 : 2;

  DelayLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final base = waitMsFor(level);
    return DelayLevel(
      gameId: id,
      level: level,
      seed: s,
      offers: [
        // Puțină variație (±15%), ca durata să nu fie învățată pe de rost.
        for (var i = 0; i < count; i++)
          DelayOffer(waitMs: (base * (0.85 + random.nextDouble() * 0.3)).round(), later: laterFor(level)),
      ],
    );
  }
}
