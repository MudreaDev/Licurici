/// Mecanica `reaction` (catalog §4): stimuli care apar în timp, copilul atinge sau se abține.
/// Acoperă go/no-go (`pescarul`, FEX2) și reacția simplă (`prinde-licuriciul`, ATN1–2).
///
/// Nivelurile sunt generate procedural (plan §3.5, ADR-027): nivelul `n` (1…∞) → axe de
/// dificultate → o secvență de stimuli, deterministă pentru același seed. Copilul nu vede
/// numărul nivelului; UI-ul doar redă secvența și trimite răspunsurile înapoi pentru scor.
library;

import 'dart:math';

import 'grades.dart';

/// Ce trebuie să facă copilul cu un stimul.
enum ReactionKind {
  /// Atinge-l (peștele, licuriciul).
  go,

  /// Nu-l atinge (caracatița, crabul…).
  noGo,
}

/// Axele de dificultate ale unui nivel (catalog: `pescarul`, `prinde-licuriciul`).
class ReactionAxes {
  const ReactionAxes({
    required this.count,
    required this.gapMs,
    required this.visibleMs,
    required this.noGoRatio,
    required this.similarity,
    required this.sizeFactor,
    required this.edgeBias,
    required this.moving,
  });

  /// Câți stimuli are nivelul.
  final int count;

  /// Pauza dintre doi stimuli (ecran liber), ms.
  final int gapMs;

  /// Cât stă un stimul pe ecran, ms (fereastra de răspuns).
  final int visibleMs;

  /// Proporția de stimuli „nu atinge” (0 = reacție simplă).
  final double noGoRatio;

  /// Cât seamănă „nu atinge” cu „atinge”: 0 = foarte diferit … 2 = aproape la fel.
  final int similarity;

  /// Mărimea stimulului față de mărimea de bază (1.0 = țintă mare, ≥ 64 dp).
  final double sizeFactor;

  /// 0 = stimulii apar spre centru … 1 = oriunde, inclusiv la margini.
  final double edgeBias;

  /// Stimulii înoată / plutesc în timp ce sunt vizibili.
  final bool moving;

  Map<String, num> toJson() => {
        'count': count,
        'gapMs': gapMs,
        'visibleMs': visibleMs,
        'noGoRatio': noGoRatio,
        'similarity': similarity,
        'sizeFactor': sizeFactor,
        'edgeBias': edgeBias,
        'moving': moving ? 1 : 0,
      };
}

/// Un stimul din secvență. Pozițiile sunt relative la zona de joc (0…1), cu marginile deja
/// lăsate libere de generator, ca ținta să nu iasă din ecran.
class ReactionStimulus {
  const ReactionStimulus({
    required this.index,
    required this.kind,
    required this.art,
    required this.x,
    required this.y,
    required this.size,
    required this.gapBeforeMs,
    required this.visibleMs,
    this.driftX = 0,
  });

  final int index;
  final ReactionKind kind;

  /// Emoji (OpenMoji în UI).
  final String art;
  final double x;
  final double y;

  /// Factor de mărime (1.0 = mărimea de bază aleasă de UI).
  final double size;
  final int gapBeforeMs;
  final int visibleMs;

  /// Deplasare orizontală relativă pe durata afișării (−0.25…0.25); 0 = stă pe loc.
  final double driftX;

  bool get isGo => kind == ReactionKind.go;
}

/// Un nivel gata de jucat: reproductibil din `(gameId, level, seed)`.
class ReactionLevel {
  const ReactionLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.instruction,
    required this.goArt,
    required this.noGoArt,
    required this.stimuli,
  });

  final String gameId;
  final int level;
  final int seed;
  final ReactionAxes axes;

  /// Rostit la început (ex. „Prinde peștii. Caracatița nu.”).
  final String instruction;
  final String goArt;
  final String? noGoArt;
  final List<ReactionStimulus> stimuli;

  /// Toate ilustrațiile, pentru pre-încărcare.
  Set<String> get art => {goArt, ?noGoArt};

  int get totalMs => stimuli.fold(0, (s, x) => s + x.gapBeforeMs + x.visibleMs);
}

/// Răspunsul copilului la un stimul, măsurat de UI cu un ceas monoton (`Stopwatch`), de la
/// momentul în care stimulul a apărut pe ecran.
class ReactionResponse {
  const ReactionResponse({required this.index, required this.tapped, this.reactionMs});

  final int index;
  final bool tapped;
  final int? reactionMs;
}

enum ReactionOutcome {
  /// A atins un „atinge”.
  hit,

  /// N-a atins un „atinge” (omisiune).
  omission,

  /// A atins un „nu atinge” (comisie — eroarea de inhibiție).
  commission,

  /// S-a abținut corect.
  correctRejection,
}

/// Rezultatul unui nivel: KPI-urile din catalog (`pescarul`: comisii, omisiuni, TR și
/// variabilitatea lui). Nicio „notă rea”: stelele răsplătesc și efortul (minim 1).
class ReactionSummary {
  ReactionSummary._(this.outcomes, this.reactionTimes, this.offTargetTaps);

  factory ReactionSummary.score(
    ReactionLevel level,
    List<ReactionResponse> responses, {
    int offTargetTaps = 0,
  }) {
    final byIndex = {for (final r in responses) r.index: r};
    final outcomes = <ReactionOutcome>[];
    final rts = <int>[];
    for (final s in level.stimuli) {
      final r = byIndex[s.index];
      final tapped = r?.tapped ?? false;
      if (s.isGo) {
        outcomes.add(tapped ? ReactionOutcome.hit : ReactionOutcome.omission);
        if (tapped && r!.reactionMs != null) rts.add(r.reactionMs!);
      } else {
        outcomes.add(tapped ? ReactionOutcome.commission : ReactionOutcome.correctRejection);
      }
    }
    return ReactionSummary._(outcomes, rts, offTargetTaps);
  }

  final List<ReactionOutcome> outcomes;
  final List<int> reactionTimes;
  final int offTargetTaps;

  int _n(ReactionOutcome o) => outcomes.where((x) => x == o).length;
  int get hits => _n(ReactionOutcome.hit);
  int get omissions => _n(ReactionOutcome.omission);
  int get commissions => _n(ReactionOutcome.commission);
  int get correctRejections => _n(ReactionOutcome.correctRejection);

  /// (atingeri corecte + abțineri corecte) / total.
  double get accuracy =>
      outcomes.isEmpty ? 0 : (hits + correctRejections) / outcomes.length;

  /// Mediana timpului de reacție (robustă la valori extreme), ms.
  int? get medianRtMs {
    if (reactionTimes.isEmpty) return null;
    final s = List.of(reactionTimes)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
  }

  /// Variabilitatea timpului de reacție (abaterea standard), ms — indicator de atenție.
  double? get rtVariabilityMs {
    if (reactionTimes.length < 2) return null;
    final mean = reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
    final v = reactionTimes.map((t) => (t - mean) * (t - mean)).reduce((a, b) => a + b) /
        (reactionTimes.length - 1);
    return sqrt(v);
  }

  /// 1–3 stele: 1 pentru efort (a jucat), 2 la ≥ 60%, 3 la ≥ 85%.
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  /// Nivelul următor (plan §3.5 b, ținta ~80% reușită): ≥ 90% → +2, ≥ 80% → +1,
  /// < 60% → −1 (minim 1), altfel rămâne. Comisiile multe (impulsivitate) nu urcă nivelul.
  int suggestedNextLevel(int current) {
    final impulsive = commissions > 0 && commissions >= (hits / 3);
    final next = switch (accuracy) {
      >= 0.9 when !impulsive => current + 2,
      >= 0.8 when !impulsive => current + 1,
      < 0.6 => current - 1,
      _ => current,
    };
    return max(1, next);
  }
}

/// Un joc pe mecanica `reaction`. Nivelul e nemărginit: axele cresc lin și se plafonează la
/// valori sigure (fără clipiri rapide, fără ținte mai mici decât minimul accesibil).
abstract class ReactionGame {
  const ReactionGame();

  String get id;
  String get name;
  String get emoji;
  String get description;
  Subject get subject;
  Set<Grade> get grades;

  /// Codul ariei de dezvoltare și treptele acoperite (catalog), ex. `FEX2`.
  List<String> get steps;

  ReactionAxes axesFor(int level);
  String instructionFor(ReactionAxes axes);
  String goArtFor(ReactionAxes axes);
  String? noGoArtFor(ReactionAxes axes);

  ReactionLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final kinds = _kinds(axes, random);
    final goArt = goArtFor(axes);
    final noGoArt = noGoArtFor(axes);
    final stimuli = <ReactionStimulus>[];
    for (var i = 0; i < kinds.length; i++) {
      final margin = 0.12 + 0.18 * (1 - axes.edgeBias);
      final drift = axes.moving ? (random.nextBool() ? 1 : -1) * (0.08 + random.nextDouble() * 0.12) : 0.0;
      // Ținta nu trebuie să iasă din ecran nici după ce înoată.
      final lo = margin + (drift < 0 ? -drift : 0);
      final hi = 1 - margin - (drift > 0 ? drift : 0);
      stimuli.add(ReactionStimulus(
        index: i,
        kind: kinds[i],
        art: kinds[i] == ReactionKind.go ? goArt : noGoArt!,
        x: lo + random.nextDouble() * (hi - lo),
        y: margin + random.nextDouble() * (1 - 2 * margin),
        size: axes.sizeFactor,
        // Puțină variație în ritm, ca momentul apariției să nu fie previzibil.
        gapBeforeMs: i == 0 ? 1200 : (axes.gapMs * (0.8 + random.nextDouble() * 0.4)).round(),
        visibleMs: axes.visibleMs,
        driftX: drift,
      ));
    }
    return ReactionLevel(
      gameId: id,
      level: level,
      seed: s,
      axes: axes,
      instruction: instructionFor(axes),
      goArt: goArt,
      noGoArt: noGoArt,
      stimuli: stimuli,
    );
  }

  /// Ordinea go/no-go: primele două sunt mereu „atinge” (început cu succes), cel mult două
  /// „nu atinge” la rând, iar numărul de no-go e exact proporția cerută (cel puțin 1 dacă > 0).
  static List<ReactionKind> _kinds(ReactionAxes axes, Random random) {
    final noGo = axes.noGoRatio <= 0 ? 0 : max(1, (axes.count * axes.noGoRatio).round());
    for (var attempt = 0; attempt < 200; attempt++) {
      final rest = [
        for (var i = 0; i < axes.count - 2; i++) i < noGo ? ReactionKind.noGo : ReactionKind.go,
      ]..shuffle(random);
      final all = [ReactionKind.go, ReactionKind.go, ...rest];
      if (_maxRun(all, ReactionKind.noGo) <= 2) return all;
    }
    // Rezervă deterministă: no-go distribuiți uniform după încălzire.
    final all = List.filled(axes.count, ReactionKind.go);
    final step = (axes.count - 2) / max(1, noGo);
    for (var k = 0; k < noGo; k++) {
      all[2 + (k * step).floor()] = ReactionKind.noGo;
    }
    return all;
  }

  static int _maxRun(List<ReactionKind> xs, ReactionKind k) {
    var best = 0, run = 0;
    for (final x in xs) {
      run = x == k ? run + 1 : 0;
      best = max(best, run);
    }
    return best;
  }
}

/// Interpolare liniară plafonată: nivelul 1 → [from], nivelul [atLevel] și peste → [to].
double ramp(int level, double from, double to, int atLevel) {
  final t = ((level - 1) / max(1, atLevel - 1)).clamp(0.0, 1.0);
  return from + (to - from) * t;
}

/// Pescarul — go/no-go (FEX2): prinde peștii, lasă în pace celelalte vietăți.
/// Axe: viteză (pauză + timp de afișare), proporția no-go 10% → 40%, asemănarea no-go cu go
/// (caracatiță → crab → alt pește), peștii încep să înoate de la nivelul 4.
class PescarulGame extends ReactionGame {
  const PescarulGame();

  @override
  String get id => 'pescarul';
  @override
  String get name => 'Pescarul';
  @override
  String get emoji => '🐟';
  @override
  String get description => 'Prinde peștii, lasă caracatița';
  @override
  Subject get subject => Subject.emotii;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1234');
  @override
  List<String> get steps => const ['FEX2'];

  static const go = '🐟';
  static const noGoBySimilarity = ['🐙', '🦀', '🐠'];
  static const noGoName = ['caracatița', 'crabul', 'peștele colorat'];

  @override
  ReactionAxes axesFor(int level) => ReactionAxes(
        count: ramp(level, 10, 20, 11).round(),
        gapMs: ramp(level, 1600, 700, 16).round(),
        visibleMs: ramp(level, 2200, 900, 16).round(),
        noGoRatio: ramp(level, 0.1, 0.4, 16),
        similarity: level < 6 ? 0 : (level < 12 ? 1 : 2),
        sizeFactor: ramp(level, 1.25, 0.9, 12),
        edgeBias: ramp(level, 0.2, 1, 10),
        moving: level >= 4,
      );

  @override
  String instructionFor(ReactionAxes axes) =>
      'Prinde peștii. Pe ${noGoName[axes.similarity]} nu.';

  @override
  String goArtFor(ReactionAxes axes) => go;

  @override
  String? noGoArtFor(ReactionAxes axes) => noGoBySimilarity[axes.similarity];
}

/// Prinde licuriciul — reacție simplă (ATN1–2): licuriciul apare, copilul îl atinge.
/// Axe: poziție (centru → margini), mărime (mare → mai mică), timp de afișare, apoi mișcare.
class PrindeLicuriciulGame extends ReactionGame {
  const PrindeLicuriciulGame();

  @override
  String get id => 'prinde-licuriciul';
  @override
  String get name => 'Prinde licuriciul';
  @override
  String get emoji => '✨';
  @override
  String get description => 'Atinge licuriciul când apare';
  @override
  Subject get subject => Subject.emotii;
  @override
  Set<Grade> get grades => Grade.parseCodes('G1');
  @override
  List<String> get steps => const ['ATN1', 'ATN2'];

  @override
  ReactionAxes axesFor(int level) => ReactionAxes(
        count: ramp(level, 8, 15, 8).round(),
        gapMs: ramp(level, 1400, 800, 12).round(),
        visibleMs: ramp(level, 4000, 1200, 14).round(),
        noGoRatio: 0,
        similarity: 0,
        sizeFactor: ramp(level, 1.4, 0.85, 12),
        edgeBias: ramp(level, 0, 1, 8),
        moving: level >= 6,
      );

  @override
  String instructionFor(ReactionAxes axes) => 'Prinde licuriciul!';

  @override
  String goArtFor(ReactionAxes axes) => '✨';

  @override
  String? noGoArtFor(ReactionAxes axes) => null;
}

const List<ReactionGame> reactionGames = [PrindeLicuriciulGame(), PescarulGame()];

ReactionGame? reactionGameById(String id) {
  for (final g in reactionGames) {
    if (g.id == id) return g;
  }
  return null;
}
