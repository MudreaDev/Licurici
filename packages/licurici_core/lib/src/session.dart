/// Planificarea unei sesiuni (plan §3.4): orarul vizual al zilei („Drumul de azi”), construit
/// din progresul copilului pe trepte și din jocurile alocate de specialist / părinte.
///
/// Structura: încălzire (succes sigur) → blocuri țintă (≈ 70% cunoscut / 30% nou) →
/// verificare de menținere (treaptă stăpânită acum ~7 sau ~30 de zile) → final pe succes.
library;

import 'dart:math';

import 'development.dart';
import 'report.dart';

/// Progresul copilului pe o treaptă (vine din Drift / sincronizare).
class StepProgress {
  const StepProgress({
    required this.stepId,
    this.mastered = false,
    this.rating = 1000,
    this.masteredAt,
    this.lastPracticed,
  });

  final String stepId;
  final bool mastered;
  final double rating;
  final DateTime? masteredAt;
  final DateTime? lastPracticed;
}

enum ActivityKind { warmUp, target, maintenance, finale }

/// O activitate din orar: un joc pe o treaptă, cu câte runde.
class SessionActivity {
  const SessionActivity({
    required this.kind,
    required this.stepId,
    required this.gameId,
    required this.rounds,
    this.knownMix = 0,
    this.mixStepId,
  });

  final ActivityKind kind;
  final String stepId;
  final String gameId;
  final int rounds;

  /// Proporția de runde din [mixStepId] (treaptă stăpânită) amestecate printre cele noi.
  final double knownMix;
  final String? mixStepId;

  @override
  String toString() => '${kind.name}:$gameId@$stepId×$rounds';
}

class SessionConfig {
  const SessionConfig({
    this.targetBlocks = 2,
    this.roundsPerBlock = 6,
    this.warmUpRounds = 3,
    this.knownMix = 0.3,
    this.maintenanceDays = const [7, 30],
    this.maintenanceTolerance = 2,
  });

  final int targetBlocks;
  final int roundsPerBlock;
  final int warmUpRounds;

  /// Cât din fiecare bloc țintă e din material cunoscut (plan: ~30%, ca să nu apară frustrarea).
  final double knownMix;
  final List<int> maintenanceDays;
  final int maintenanceTolerance;
}

/// „Drumul de azi” după cum e copilul azi (plan §3.4, autoreglare): obosit, trist sau supărat
/// la început → un singur bloc de obiective, mai scurt; la fel dacă sesiunea trecută s-a
/// încheiat cu oboseală mare (timpii au crescut cu ≥ 40%) sau a fost abandonată. Încălzirea și
/// finalul pe succes rămân — ziua se termină tot cu ceva reușit.
SessionConfig gentleConfig(SessionConfig base, {Mood? mood, SessionReport? last}) {
  final hardDay = mood == Mood.obosit || mood == Mood.trist || mood == Mood.suparat;
  final tiredLastTime = last != null && (last.abandoned || (last.fatigue ?? 0) >= 0.4);
  if (!hardDay && !tiredLastTime) return base;
  return SessionConfig(
    targetBlocks: base.targetBlocks > 1 ? 1 : base.targetBlocks,
    roundsPerBlock: (base.roundsPerBlock * (hardDay ? 0.6 : 0.8)).round().clamp(3, base.roundsPerBlock),
    warmUpRounds: base.warmUpRounds,
    // O zi grea: mai mult material cunoscut în blocul de lucru.
    knownMix: hardDay ? 0.5 : base.knownMix,
    maintenanceDays: base.maintenanceDays,
    maintenanceTolerance: base.maintenanceTolerance,
  );
}

class SessionPlan {
  const SessionPlan(this.activities);

  final List<SessionActivity> activities;

  /// Orarul vizual: jocurile în ordine (copilul vede doar ilustrațiile lor).
  List<String> get schedule => [for (final a in activities) a.gameId];

  int get totalRounds => activities.fold(0, (s, a) => s + a.rounds);

  bool get isEmpty => activities.isEmpty;
}

class SessionPlanner {
  const SessionPlanner({this.config = const SessionConfig()});

  final SessionConfig config;

  /// [progress] = treptele active ale copilului (obiectivele din plan + cele stăpânite);
  /// [allowedGames] = jocurile alocate copilului (plan §5.1). Doar ele apar în orar.
  SessionPlan plan({
    required List<StepProgress> progress,
    required Set<String> allowedGames,
    required DateTime now,
    Random? random,
  }) {
    final rnd = random ?? Random();
    String? gameFor(String stepId) {
      final games = stepById(stepId)?.games.where(allowedGames.contains).toList() ?? const [];
      return games.isEmpty ? null : games[rnd.nextInt(games.length)];
    }

    final playable = progress.where((p) => gameFor(p.stepId) != null).toList();
    final mastered = playable.where((p) => p.mastered).toList()..shuffle(rnd);
    // Obiectivele cu cel mai mic rating primesc întâi timp (cele mai grele acum); la egalitate
    // (de exemplu, trepte încă neîncepute) ordinea zilei e aleatoare, ca ariile să se rotească de
    // la o zi la alta. Ce s-a exersat deja azi trece la coadă (practica distribuită).
    final open = playable.where((p) => !p.mastered).toList()..shuffle(rnd);
    final today = DateTime(now.year, now.month, now.day);
    int key(StepProgress p) =>
        ((p.lastPracticed != null && !p.lastPracticed!.isBefore(today)) ? 1 << 20 : 0) + (p.rating / 25).round();
    open.sort((a, b) => key(a).compareTo(key(b)));
    // Blocurile de obiective din arii diferite, cât se poate (variație, mai puțină oboseală).
    final targets = <StepProgress>[];
    final domains = <Domain>{};
    for (final p in open) {
      if (targets.length == config.targetBlocks) break;
      if (domains.add(stepById(p.stepId)!.domain)) targets.add(p);
    }
    for (final p in open) {
      if (targets.length == config.targetBlocks) break;
      if (!targets.contains(p)) targets.add(p);
    }

    final out = <SessionActivity>[];
    if (mastered.isNotEmpty) {
      final w = mastered.first;
      out.add(SessionActivity(
        kind: ActivityKind.warmUp,
        stepId: w.stepId,
        gameId: gameFor(w.stepId)!,
        rounds: config.warmUpRounds,
      ));
    }

    for (final t in targets) {
      // Materialul cunoscut amestecat vine din aceeași arie, dacă există.
      final domain = stepById(t.stepId)!.domain;
      final known = mastered.where((m) => stepById(m.stepId)!.domain == domain).firstOrNull ??
          mastered.firstOrNull;
      out.add(SessionActivity(
        kind: ActivityKind.target,
        stepId: t.stepId,
        gameId: gameFor(t.stepId)!,
        rounds: config.roundsPerBlock,
        knownMix: known == null ? 0 : config.knownMix,
        mixStepId: known?.stepId,
      ));
    }

    final due = mastered.where((m) => _maintenanceDue(m, now)).firstOrNull;
    if (due != null) {
      out.add(SessionActivity(
        kind: ActivityKind.maintenance,
        stepId: due.stepId,
        gameId: gameFor(due.stepId)!,
        rounds: config.warmUpRounds,
      ));
    }

    // Final pe succes: o treaptă stăpânită, diferită de încălzire când se poate.
    if (mastered.isNotEmpty && out.last.kind != ActivityKind.maintenance) {
      final f = mastered.length > 1 ? mastered[1] : mastered.first;
      out.add(SessionActivity(
        kind: ActivityKind.finale,
        stepId: f.stepId,
        gameId: gameFor(f.stepId)!,
        rounds: 2,
      ));
    }
    return SessionPlan(out);
  }

  bool _maintenanceDue(StepProgress p, DateTime now) {
    final at = p.masteredAt;
    if (at == null) return false;
    final days = now.difference(at).inDays;
    return config.maintenanceDays.any((d) => (days - d).abs() <= config.maintenanceTolerance);
  }
}
