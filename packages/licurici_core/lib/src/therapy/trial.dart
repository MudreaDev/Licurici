/// Încercarea (`trial`, plan §4.1): singurul eveniment de bază. Totul (acuratețe, independență,
/// latență, stăpânire, rating) se calculează din încercări (event sourcing, ADR-011).
library;

/// Ierarhia de ajutor (plan §3.3), de la independent la model complet.
enum PromptLevel {
  /// Fără ajutor: răspuns independent.
  p0('P0', 'independent'),

  /// Indiciu vocal neutru („Uită-te la urechi”) — prompt verbal.
  p1('P1', 'indiciu'),

  /// Distractorii se estompează (mai puține variante) — prompt de poziție/stimul.
  p2('P2', 'reducere variante'),

  /// Răspunsul corect pulsează — prompt gestual.
  p3('P3', 'indicare'),

  /// Mâna animată atinge răspunsul, copilul repetă — model complet.
  p4('P4', 'model');

  const PromptLevel(this.code, this.label);

  final String code;
  final String label;

  static PromptLevel fromCode(String code) => values.firstWhere((p) => p.code == code);

  PromptLevel operator +(int n) => values[(index + n).clamp(0, values.length - 1)];
  PromptLevel operator -(int n) => this + (-n);
  bool operator >(PromptLevel o) => index > o.index;
  bool operator <(PromptLevel o) => index < o.index;
  bool operator >=(PromptLevel o) => index >= o.index;

  static PromptLevel max(PromptLevel a, PromptLevel b) => a >= b ? a : b;
  static PromptLevel min(PromptLevel a, PromptLevel b) => a >= b ? b : a;
}

/// Contextul în care s-a jucat (plan §4.1).
enum TrialMode { plan, liber, evaluare, live }

class Trial {
  const Trial({
    required this.sessionId,
    required this.stepId,
    required this.gameId,
    required this.correct,
    required this.at,
    this.promptLevel = PromptLevel.p0,
    this.attempts = 1,
    this.latencyMs,
    this.seed,
    this.config = const {},
    this.axes = const {},
    this.rating,
    this.stimulusId,
    this.stimulusSet,
    this.selfCorrected = false,
    this.offTargetTaps = 0,
    this.idleMs = 0,
    this.mode = TrialMode.plan,
  })  : assert(attempts >= 1),
        assert(offTargetTaps >= 0),
        assert(idleMs >= 0);

  factory Trial.fromJson(Map<String, Object?> j) => Trial(
        sessionId: j['sessionId']! as String,
        stepId: j['stepId']! as String,
        gameId: j['gameId']! as String,
        correct: j['correct']! as bool,
        at: DateTime.parse(j['at']! as String),
        promptLevel: PromptLevel.fromCode(j['promptLevel'] as String? ?? 'P0'),
        attempts: j['attempts'] as int? ?? 1,
        latencyMs: j['latencyMs'] as int?,
        seed: j['seed'] as int?,
        config: Map.unmodifiable(j['config'] as Map<String, Object?>? ?? const {}),
        axes: {
          for (final MapEntry(:key, :value) in (j['axes'] as Map? ?? const {}).entries)
            key as String: (value as num).toDouble(),
        },
        rating: (j['rating'] as num?)?.toDouble(),
        stimulusId: j['stimulusId'] as String?,
        stimulusSet: j['stimulusSet'] as String?,
        selfCorrected: j['selfCorrected'] as bool? ?? false,
        offTargetTaps: j['offTargetTaps'] as int? ?? 0,
        idleMs: j['idleMs'] as int? ?? 0,
        mode: TrialMode.values.byName(j['mode'] as String? ?? 'plan'),
      );

  /// Pseudonim: niciun nume, doar UUID-ul sesiunii (copilul e cheia de partiție în stocare).
  final String sessionId;
  final String stepId;
  final String gameId;

  /// Primul răspuns a fost cel corect (cu sau fără ajutor). În învățarea fără eroare copilul
  /// ajunge oricum la răspuns, deci „a ajuns la corect” n-ar măsura nimic.
  final bool correct;
  final DateTime at;

  /// Nivelul MAXIM de ajutor primit în încercare.
  final PromptLevel promptLevel;

  /// Câte atingeri pe variante până la corect (1 = din prima).
  final int attempts;

  /// De la finalul instrucțiunii până la primul răspuns.
  final int? latencyMs;

  /// Nivelul exact, reproductibil (ADR-027): generator + axe + seed.
  final int? seed;
  final Map<String, Object?> config;
  final Map<String, double> axes;

  /// Rating-ul copilului pe treaptă înainte de încercare.
  final double? rating;
  final String? stimulusId;
  final String? stimulusSet;
  final bool selfCorrected;

  /// Atingeri în afara variantelor (impulsivitate / motricitate).
  final int offTargetTaps;
  final int idleMs;
  final TrialMode mode;

  /// Răspuns independent: corect, din prima, fără niciun ajutor. KPI-ul principal.
  bool get independent => correct && attempts == 1 && promptLevel == PromptLevel.p0;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'stepId': stepId,
        'gameId': gameId,
        'correct': correct,
        'at': at.toUtc().toIso8601String(),
        'promptLevel': promptLevel.code,
        'attempts': attempts,
        if (latencyMs != null) 'latencyMs': latencyMs,
        if (seed != null) 'seed': seed,
        if (config.isNotEmpty) 'config': config,
        if (axes.isNotEmpty) 'axes': axes,
        if (rating != null) 'rating': rating,
        if (stimulusId != null) 'stimulusId': stimulusId,
        if (stimulusSet != null) 'stimulusSet': stimulusSet,
        if (selfCorrected) 'selfCorrected': true,
        if (offTargetTaps > 0) 'offTargetTaps': offTargetTaps,
        if (idleMs > 0) 'idleMs': idleMs,
        'mode': mode.name,
      };
}
