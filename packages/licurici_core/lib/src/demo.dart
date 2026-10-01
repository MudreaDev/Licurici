/// Date demonstrative, deterministe, pentru panouri (până există sincronizarea cu backend-ul).
/// Copii inventați; progresul e simulat realist: independența crește în timp, ajutorul scade,
/// unele trepte rămân grele, apar confuzii, oboseală și pauze.
library;

import 'dart:math';

import 'report.dart';
import 'trial.dart';

/// Profilul unui copil, așa cum îl vede adultul (porecla e aleasă de părinte).
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.ageYears,
    required this.activeSteps,
    required this.masteredSteps,
  });

  final String id;
  final String nickname;
  final int ageYears;

  /// Obiectivele curente (treptele din plan).
  final List<String> activeSteps;
  final List<String> masteredSteps;
}

/// Un copil cu istoricul lui de sesiuni (cronologic) și rapoartele calculate.
class ChildHistory {
  ChildHistory(this.child, this.sessions)
      : reports = _reports(sessions);

  final ChildProfile child;
  final List<SessionRecord> sessions;
  final List<SessionReport> reports;

  static List<SessionReport> _reports(List<SessionRecord> sessions) {
    final out = <SessionReport>[];
    for (final s in sessions) {
      out.add(SessionReport.from(s, previous: out.isEmpty ? null : out.last));
    }
    return out;
  }

  SessionReport? get latest => reports.isEmpty ? null : reports.last;

  /// Independența pe o treaptă, sesiune cu sesiune (pentru graficul de progres, tip ABA).
  List<(DateTime, double)> independenceSeries(String stepId) => [
        for (final r in reports)
          for (final s in r.steps)
            if (s.stepId == stepId) (r.record.start, s.stats.independence),
      ];
}

const _emotionKeys = ['fericit', 'trist', 'suparat', 'speriat', 'surprins', 'obosit'];
const _likelyConfusion = {
  'fericit': 'surprins',
  'trist': 'suparat',
  'suparat': 'trist',
  'speriat': 'surprins',
  'surprins': 'speriat',
  'obosit': 'trist',
};

const _stepGames = {
  'EMO2': 'emotii',
  'EMO3': 'ce-simte',
  'EMO4': 'ce-ma-ajuta',
  'EMO5': 'cine-stie',
  'EMO6': 'situatii',
  'FEX2': 'pescarul',
  'FEX5': 'simon',
  'ATN2': 'prinde-licuriciul',
  'PAC-N2': 'numaram',
  'PAC-N4': 'comparam',
};

/// Copiii demo, fiecare cu ~[sessions] sesiuni în ultimele săptămâni până la [now].
List<ChildHistory> demoChildren({DateTime? now, int sessions = 12, int seed = 7}) {
  final end = now ?? DateTime.utc(2026, 10, 1, 17);
  final random = Random(seed);
  const children = [
    ChildProfile(
      id: '7f1c2a90-0000-4000-8000-000000000001',
      nickname: 'Ilinca',
      ageYears: 6,
      activeSteps: ['EMO3', 'EMO4', 'FEX2'],
      masteredSteps: ['EMO2', 'PAC-N2'],
    ),
    ChildProfile(
      id: '7f1c2a90-0000-4000-8000-000000000002',
      nickname: 'Tudor',
      ageYears: 8,
      activeSteps: ['EMO5', 'EMO6', 'FEX5'],
      masteredSteps: ['EMO3', 'ATN2'],
    ),
    ChildProfile(
      id: '7f1c2a90-0000-4000-8000-000000000003',
      nickname: 'Mara',
      ageYears: 5,
      activeSteps: ['EMO2', 'ATN2', 'PAC-N4'],
      masteredSteps: ['PAC-N2'],
    ),
  ];
  return [
    for (final (ci, c) in children.indexed)
      ChildHistory(c, [
        for (var i = 0; i < sessions; i++)
          _session(c, i, sessions, end.subtract(Duration(days: (sessions - i) * 2 + ci)), random),
      ]),
  ];
}

SessionRecord _session(ChildProfile c, int i, int total, DateTime start, Random r) {
  final progress = i / max(1, total - 1); // 0 → 1 de-a lungul istoricului
  final trials = <Trial>[];
  var t = start;
  final steps = [c.masteredSteps.first, ...c.activeSteps, c.masteredSteps.last];
  for (final (si, step) in steps.indexed) {
    final mastered = c.masteredSteps.contains(step);
    // A doua treaptă activă rămâne mai grea (realist: nu progresează totul la fel).
    final hard = !mastered && si == 2;
    final skill = mastered ? 0.92 : (hard ? 0.35 + 0.25 * progress : 0.45 + 0.45 * progress);
    final n = mastered ? 3 : 6 + r.nextInt(3);
    for (var k = 0; k < n; k++) {
      final late = k / n; // oboseală ușoară spre finalul blocului
      final correct = r.nextDouble() < skill - 0.08 * late;
      final helped = !correct || r.nextDouble() > skill;
      final prompt = correct
          ? (helped ? PromptLevel.values[1 + r.nextInt(2)] : PromptLevel.p0)
          : PromptLevel.values[2 + r.nextInt(3)];
      final target = _emotionKeys[r.nextInt(_emotionKeys.length)];
      // Confuzii plauzibile (ca la copiii reali): emoții apropiate, nu alese la întâmplare.
      final confusedWith = _likelyConfusion[target]!;
      final isEmotion = step.startsWith('EMO');
      t = t.add(Duration(seconds: 8 + r.nextInt(10)));
      trials.add(Trial(
        stepId: step,
        gameId: _stepGames[step] ?? 'emotii',
        correct: correct,
        promptLevel: prompt,
        attempts: correct && prompt == PromptLevel.p0 ? 1 : 2,
        latencyMs: (1400 + 2600 * (1 - skill) + 900 * late + r.nextInt(600)).round(),
        stimulusSet: 'set-${1 + r.nextInt(3)}',
        at: t,
        targetId: isEmotion ? target : null,
        chosenId: isEmotion && !correct && confusedWith != target ? confusedWith : null,
      ));
    }
  }
  final events = <SessionEvent>[
    if (r.nextDouble() < 0.3) SessionEvent(SessionEventKind.pause, start.add(const Duration(minutes: 9))),
    if (r.nextDouble() < 0.2) SessionEvent(SessionEventKind.breathing, start.add(const Duration(minutes: 10))),
    if (r.nextDouble() < 0.08) SessionEvent(SessionEventKind.abandoned, t),
  ];
  Mood mood(double bias) {
    final x = r.nextDouble() + bias;
    return x > 1.0 ? Mood.bucuros : (x > 0.7 ? Mood.linistit : (x > 0.45 ? Mood.obosit : (x > 0.25 ? Mood.trist : Mood.suparat)));
  }

  return SessionRecord(
    id: '${c.id.substring(0, 8)}-s$i',
    childId: c.id,
    start: start,
    end: t.add(const Duration(seconds: 20)),
    trials: trials,
    events: events,
    moodBefore: mood(0.2 * progress),
    moodAfter: mood(0.25 + 0.2 * progress),
  );
}
