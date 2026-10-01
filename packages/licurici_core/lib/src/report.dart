/// Jurnalul unei sesiuni și raportul calculat din el (plan §4), pentru panoul părintelui și al
/// specialistului.
///
/// Principiu: **faptele le calculează codul** (determinist, testat); AI-ul (din backend, cu
/// consimțământ) primește doar `SessionReport.toAiJson()` — agregate pseudonimizate, fără nume,
/// text liber, audio sau imagini — și doar le formulează. Până atunci (și ca rezervă când AI-ul
/// nu e disponibil) rezumatele text se generează din reguli: [parentSummary], [specialistNotes].
library;

import 'dart:math';

import 'development.dart';
import 'trial.dart';

/// Cum se simte copilul — ales chiar de copil la începutul și la finalul sesiunii („Cum te simți?”).
enum Mood {
  bucuros('😊', 'bucuros'),
  linistit('😌', 'liniștit'),
  obosit('😴', 'obosit'),
  trist('😢', 'trist'),
  suparat('😠', 'supărat');

  const Mood(this.emoji, this.label);
  final String emoji;
  final String label;

  /// Scală simplă pentru tendință: plăcut > neutru > greu.
  int get valence => switch (this) {
        Mood.bucuros => 2,
        Mood.linistit => 1,
        Mood.obosit => 0,
        Mood.trist || Mood.suparat => -1,
      };
}

enum SessionEventKind {
  /// Copilul a cerut pauză (autoreglare — nu e un eșec).
  pause,

  /// A folosit exercițiul de respirație.
  breathing,

  /// A ieșit înainte de final.
  abandoned,

  /// A ales singur o activitate (când i s-au oferit două).
  choiceMade,
}

class SessionEvent {
  const SessionEvent(this.kind, this.at, {this.gameId});
  final SessionEventKind kind;
  final DateTime at;
  final String? gameId;
}

/// Tot ce s-a întâmplat într-o sesiune. [childId] e un UUID pseudonim.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.childId,
    required this.start,
    required this.end,
    required this.trials,
    this.events = const [],
    this.moodBefore,
    this.moodAfter,
  });

  final String id;
  final String childId;
  final DateTime start;
  final DateTime end;
  final List<Trial> trials;
  final List<SessionEvent> events;
  final Mood? moodBefore;
  final Mood? moodAfter;

  Map<String, Object?> toJson() => {
        'id': id,
        'childId': childId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'trials': [for (final t in trials) t.toJson()],
        'events': [
          for (final e in events)
            {'kind': e.kind.name, 'at': e.at.toUtc().toIso8601String(), 'gameId': e.gameId},
        ],
        'moodBefore': moodBefore?.name,
        'moodAfter': moodAfter?.name,
      };

  factory SessionRecord.fromJson(Map<String, Object?> j) {
    Mood? mood(Object? v) => v == null ? null : Mood.values.byName(v as String);
    return SessionRecord(
      id: j['id']! as String,
      childId: j['childId']! as String,
      start: DateTime.parse(j['start']! as String),
      end: DateTime.parse(j['end']! as String),
      trials: [for (final t in j['trials']! as List) Trial.fromJson((t as Map).cast<String, Object?>())],
      events: [
        for (final e in j['events']! as List)
          SessionEvent(
            SessionEventKind.values.byName((e as Map)['kind'] as String),
            DateTime.parse(e['at'] as String),
            gameId: e['gameId'] as String?,
          ),
      ],
      moodBefore: mood(j['moodBefore']),
      moodAfter: mood(j['moodAfter']),
    );
  }
}

/// Statisticile pe o treaptă într-o sesiune.
class StepReport {
  StepReport(this.stepId, List<Trial> trials)
      : stats = TrialStats(trials),
        games = {for (final t in trials) t.gameId};

  final String stepId;
  final TrialStats stats;
  final Set<String> games;

  Step? get step => stepById(stepId);
  String get objective => step?.objective ?? stepId;
}

/// O confuzie frecventă: ținta și ce a ales copilul în loc.
class Confusion {
  const Confusion(this.target, this.chosen, this.count);
  final String target;
  final String chosen;
  final int count;
}

class SessionReport {
  SessionReport._({
    required this.record,
    required this.steps,
    required this.confusions,
    required this.fatigue,
    this.previous,
  });

  /// [previous] = raportul sesiunii anterioare (pentru „a crescut / a scăzut”).
  factory SessionReport.from(SessionRecord record, {SessionReport? previous}) {
    final byStep = <String, List<Trial>>{};
    for (final t in record.trials) {
      byStep.putIfAbsent(t.stepId, () => []).add(t);
    }
    final pairs = <(String, String), int>{};
    for (final t in record.trials) {
      if (t.targetId != null && t.chosenId != null && t.targetId != t.chosenId) {
        final k = (t.targetId!, t.chosenId!);
        pairs[k] = (pairs[k] ?? 0) + 1;
      }
    }
    final confusions = [for (final e in pairs.entries) Confusion(e.key.$1, e.key.$2, e.value)]
      ..sort((a, b) => b.count.compareTo(a.count));
    return SessionReport._(
      record: record,
      steps: [for (final e in byStep.entries) StepReport(e.key, e.value)],
      confusions: confusions,
      fatigue: _fatigue(record.trials),
      previous: previous,
    );
  }

  final SessionRecord record;
  final List<StepReport> steps;
  final List<Confusion> confusions;

  /// Creșterea relativă a latenței mediane în a doua jumătate față de prima (0.4 = +40%).
  /// Null dacă sunt prea puține încercări.
  final double? fatigue;
  final SessionReport? previous;

  TrialStats get overall => TrialStats(record.trials);
  int get minutes => max(1, record.end.difference(record.start).inMinutes);
  Set<String> get games => {for (final t in record.trials) t.gameId};
  int count(SessionEventKind k) => record.events.where((e) => e.kind == k).length;
  bool get abandoned => count(SessionEventKind.abandoned) > 0;

  /// Diferența de independență față de sesiunea anterioară, pe treaptă (puncte procentuale).
  double? independenceDelta(String stepId) {
    final before = previous?.steps.where((s) => s.stepId == stepId).firstOrNull;
    final now = steps.where((s) => s.stepId == stepId).firstOrNull;
    if (before == null || now == null) return null;
    return (now.stats.independence - before.stats.independence) * 100;
  }

  /// Sub atâtea încercări pe treaptă, procentele sunt zgomot: nu tragem concluzii pentru părinte.
  static const minTrials = 5;

  /// Treptele aproape de stăpânire (≥ 70% independent azi).
  List<StepReport> get nearMastery =>
      steps.where((s) => s.stats.count >= minTrials && s.stats.independence >= 0.7).toList();

  /// Treptele grele azi (sub 50% acuratețe) — de discutat cu specialistul, nu „eșecuri”.
  List<StepReport> get struggling =>
      steps.where((s) => s.stats.count >= minTrials && s.stats.accuracy < 0.5).toList();

  static double? _fatigue(List<Trial> trials) {
    final lat = [for (final t in trials) ?t.latencyMs];
    if (lat.length < 8) return null;
    int median(List<int> xs) {
      final s = List.of(xs)..sort();
      return s[s.length ~/ 2];
    }

    final half = lat.length ~/ 2;
    final a = median(lat.sublist(0, half));
    final b = median(lat.sublist(half));
    return a == 0 ? null : (b - a) / a;
  }

  /// Datele pentru AI: agregate, pseudonimizate, fără nume și fără text liber.
  Map<String, Object?> toAiJson() => {
        'durationMin': minutes,
        'games': games.toList()..sort(),
        'trials': overall.count,
        'accuracy': _r(overall.accuracy),
        'independence': _r(overall.independence),
        'meanPromptLevel': _r(overall.meanPromptLevel),
        'medianLatencyMs': overall.medianLatencyMs,
        'steps': [
          for (final s in steps)
            {
              'stepId': s.stepId,
              'objective': s.objective,
              'trials': s.stats.count,
              'accuracy': _r(s.stats.accuracy),
              'independence': _r(s.stats.independence),
              'meanPromptLevel': _r(s.stats.meanPromptLevel),
              'medianLatencyMs': s.stats.medianLatencyMs,
              'independenceDeltaPts': independenceDelta(s.stepId)?.round(),
            },
        ],
        'topConfusions': [
          for (final c in confusions.take(3)) {'target': c.target, 'chosen': c.chosen, 'count': c.count},
        ],
        'fatigueLatencyIncrease': fatigue == null ? null : _r(fatigue!),
        'pauses': count(SessionEventKind.pause),
        'breathingUsed': count(SessionEventKind.breathing),
        'abandoned': abandoned,
        'moodBefore': record.moodBefore?.name,
        'moodAfter': record.moodAfter?.name,
      };

  static double _r(double x) => (x * 100).round() / 100;

  static String _pct(double x) => '${(x * 100).round()}%';

  /// Rezumatul pentru părinte: cald, simplu, fără jargon, fără „note”.
  String get parentSummary {
    final b = StringBuffer()
      ..write('În această sesiune s-a jucat $minutes ${minutes == 1 ? 'minut' : 'minute'}');
    b.write(games.length == 1 ? ', un singur joc. ' : ', ${games.length} jocuri. ');
    if (nearMastery.isNotEmpty) {
      b.write('A lucrat foarte bine la: ${nearMastery.map((s) => _lower(s.objective)).join('; ')}. ');
    }
    final improved = steps
        .where((s) => s.stats.count >= minTrials && (independenceDelta(s.stepId) ?? 0) >= 10)
        .toList();
    if (improved.isNotEmpty) {
      b.write('Se vede un progres față de data trecută la: '
          '${improved.map((s) => _lower(s.objective)).join('; ')}. ');
    }
    if (count(SessionEventKind.pause) + count(SessionEventKind.breathing) > 0) {
      b.write('A cerut o pauză când a avut nevoie — e un lucru bun. ');
    }
    if ((fatigue ?? 0) >= 0.4) {
      b.write('Spre final a apărut puțină oboseală; sesiunile ceva mai scurte pot ajuta. ');
    }
    if (record.moodBefore != null && record.moodAfter != null) {
      b.write('Cum s-a simțit, ales chiar de copil: la început ${record.moodBefore!.emoji} '
          '„${record.moodBefore!.label}”, la final ${record.moodAfter!.emoji} „${record.moodAfter!.label}”. ');
    }
    if (confusions.isNotEmpty && confusions.first.count >= 2) {
      final c = confusions.first;
      b.write('Idee pentru acasă: vorbiți despre diferența dintre „${c.target}” și „${c.chosen}”. ');
    }
    return b.toString().trim();
  }

  /// Notițele pentru specialist: indicatori și observații concrete.
  List<String> get specialistNotes => [
        'Durată $minutes min · ${overall.count} încercări · acuratețe ${_pct(overall.accuracy)} · '
            'independență ${_pct(overall.independence)} · ajutor mediu P${overall.meanPromptLevel.toStringAsFixed(1)}'
            '${overall.medianLatencyMs == null ? '' : ' · latență mediană ${overall.medianLatencyMs} ms'}.',
        for (final s in steps)
          '${s.stepId} — ${s.objective}: ${s.stats.count} încercări, independență ${_pct(s.stats.independence)}'
              '${independenceDelta(s.stepId) == null ? '' : ' (${_signed(independenceDelta(s.stepId)!)} pp față de sesiunea anterioară)'}'
              ', ajutor mediu P${s.stats.meanPromptLevel.toStringAsFixed(1)}.',
        if (nearMastery.isNotEmpty)
          'Aproape de criteriul de stăpânire: ${nearMastery.map((s) => s.stepId).join(', ')} — de confirmat în sesiunea următoare.',
        if (struggling.isNotEmpty)
          'Dificultate: ${struggling.map((s) => s.stepId).join(', ')} (acuratețe < 50%) — de luat în calcul coborârea treptei sau mai mult ajutor.',
        for (final c in confusions.take(3)) 'Confuzie: ${c.target} → ${c.chosen} (${c.count}×).',
        if ((fatigue ?? 0) >= 0.4)
          'Oboseală probabilă: latența mediană crește cu ${_pct(fatigue!)} în a doua jumătate.',
        if (count(SessionEventKind.pause) > 0) 'Pauze cerute: ${count(SessionEventKind.pause)}.',
        if (abandoned) 'Sesiune întreruptă înainte de final.',
        if (record.moodBefore != null || record.moodAfter != null)
          'Autoevaluare: ${record.moodBefore?.label ?? '—'} → ${record.moodAfter?.label ?? '—'}.',
      ];

  static String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
  static String _signed(double x) => x >= 0 ? '+${x.round()}' : '${x.round()}';
}
