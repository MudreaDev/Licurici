/// Modelul de dezvoltare (plan §3, ADR-026): arii → trasee → trepte → exerciții.
/// Traseele sunt DATE (JSON în `game_content/trasee/`), nu cod: un specialist le poate corecta.
library;

/// Ariile de dezvoltare (plan §3.1). Codul e stabil (apare în date și în `stepId`).
enum Domain {
  atn('ATN', 'Atenție și atenție comună'),
  imi('IMI', 'Imitație'),
  pot('POT', 'Potrivire și percepție vizuală'),
  lrc('LRC', 'Limbaj receptiv'),
  com('COM', 'Comunicare și limbaj expresiv'),
  cog('COG', 'Cogniție'),
  emo('EMO', 'Emoții și cogniție socială'),
  fex('FEX', 'Funcții executive și autoreglare'),
  aut('AUT', 'Autonomie și rutine'),
  mot('MOT', 'Motricitate fină'),
  pac('PAC', 'Pre-academic și academic');

  const Domain(this.code, this.label);

  final String code;
  final String label;

  static Domain fromCode(String code) => values.firstWhere(
        (d) => d.code == code,
        orElse: () => throw FormatException('arie necunoscută: $code'),
      );
}

/// Când e stăpânită o treaptă (plan §3, §4.2). Implicit: ≥ 80% independent, 2 sesiuni la rând,
/// ≥ 2 seturi de stimuli, cu minimum 5 încercări pe sesiune (altfel „date insuficiente”).
class MasteryCriterion {
  const MasteryCriterion({
    this.independence = 0.8,
    this.sessions = 2,
    this.stimulusSets = 2,
    this.minTrials = 5,
  })  : assert(independence > 0 && independence <= 1),
        assert(sessions >= 1),
        assert(stimulusSets >= 1),
        assert(minTrials >= 1);

  factory MasteryCriterion.fromJson(Map<String, Object?> json, [MasteryCriterion? base]) {
    final b = base ?? const MasteryCriterion();
    return MasteryCriterion(
      independence: (json['independence'] as num?)?.toDouble() ?? b.independence,
      sessions: json['sessions'] as int? ?? b.sessions,
      stimulusSets: json['stimulusSets'] as int? ?? b.stimulusSets,
      minTrials: json['minTrials'] as int? ?? b.minTrials,
    );
  }

  /// Proporția de încercări independente cerută pe sesiune.
  final double independence;

  /// Câte sesiuni consecutive trebuie să atingă pragul.
  final int sessions;

  /// Câte seturi de stimuli diferite (generalizare, nu memorare).
  final int stimulusSets;

  /// Sub atâtea încercări, o sesiune nu contează (nici pro, nici contra).
  final int minTrials;

  Map<String, Object?> toJson() => {
        'independence': independence,
        'sessions': sessions,
        'stimulusSets': stimulusSets,
        'minTrials': minTrials,
      };
}

/// Un exercițiu al unei trepte: jocul + parametrii lui (`GameConfig`, ADR-025).
class Exercise {
  const Exercise(this.gameId, [this.config = const {}]);

  factory Exercise.fromJson(Map<String, Object?> json) => Exercise(
        json['game']! as String,
        Map.unmodifiable(json['config'] as Map<String, Object?>? ?? const {}),
      );

  final String gameId;
  final Map<String, Object?> config;
}

/// O treaptă: un obiectiv concret, măsurabil (ex. POT4 = potrivire neidentică).
class LadderStep {
  const LadderStep({
    required this.id,
    required this.ladderId,
    required this.domain,
    required this.order,
    required this.title,
    required this.goal,
    required this.criterion,
    this.exercises = const [],
  });

  final String id;
  final String ladderId;
  final Domain domain;

  /// Poziția în traseu, de la 1.
  final int order;
  final String title;
  final String goal;
  final MasteryCriterion criterion;
  final List<Exercise> exercises;

  Iterable<String> get gameIds => exercises.map((e) => e.gameId);

  @override
  String toString() => 'LadderStep($id)';
}

/// Un traseu: treptele unei arii (sau ale unei ramuri, ex. PAC-N = numerație), de la mic la mare.
class Ladder {
  Ladder({
    required this.id,
    required this.domain,
    required this.version,
    required this.title,
    required List<LadderStep> steps,
  }) : steps = List.unmodifiable(steps) {
    final ids = <String>{};
    for (final (i, s) in steps.indexed) {
      if (!ids.add(s.id)) throw FormatException('treaptă duplicat: ${s.id}');
      if (s.order != i + 1) throw FormatException('ordine greșită la ${s.id}');
      if (!s.id.startsWith(id)) throw FormatException('${s.id} nu aparține traseului $id');
    }
    if (steps.isEmpty) throw FormatException('traseul $id nu are trepte');
  }

  factory Ladder.fromJson(Map<String, Object?> json) {
    final id = json['id']! as String;
    final domain = Domain.fromCode(json['domain']! as String);
    final base = MasteryCriterion.fromJson(json['criterion'] as Map<String, Object?>? ?? const {});
    final steps = [
      for (final (i, raw) in (json['steps']! as List).cast<Map<String, Object?>>().indexed)
        LadderStep(
          id: raw['id']! as String,
          ladderId: id,
          domain: domain,
          order: i + 1,
          title: raw['title']! as String,
          goal: raw['goal']! as String,
          criterion: raw['criterion'] == null
              ? base
              : MasteryCriterion.fromJson(raw['criterion']! as Map<String, Object?>, base),
          exercises: [
            for (final e in (raw['exercises'] as List? ?? const []).cast<Map<String, Object?>>())
              Exercise.fromJson(e),
          ],
        ),
    ];
    return Ladder(
      id: id,
      domain: domain,
      version: json['version'] as int? ?? 1,
      title: json['title']! as String,
      steps: steps,
    );
  }

  final String id;
  final Domain domain;
  final int version;
  final String title;
  final List<LadderStep> steps;

  LadderStep? step(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Treapta următoare sau `null` la capătul traseului.
  LadderStep? next(LadderStep s) => s.order < steps.length ? steps[s.order] : null;

  /// Treapta anterioară (pentru încălzire / menținere) sau `null` la început.
  LadderStep? previous(LadderStep s) => s.order > 1 ? steps[s.order - 2] : null;

  /// Treptele servite de un joc (un joc poate servi mai multe trepte, pe mai multe trasee).
  List<LadderStep> stepsFor(String gameId) => [
        for (final s in steps)
          if (s.gameIds.contains(gameId)) s,
      ];
}
