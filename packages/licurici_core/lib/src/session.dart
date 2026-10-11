/// Planificarea unei sesiuni (plan §3.4): orarul vizual al zilei („Drumul de azi”), construit
/// din progresul copilului pe trepte și din jocurile alocate de specialist / părinte.
///
/// Structura: încălzire (succes sigur) → blocuri țintă (≈ 70% cunoscut / 30% nou) →
/// verificare de menținere (treaptă stăpânită acum ~7 sau ~30 de zile) → final pe succes.
library;

import 'dart:math';

import 'development.dart';
import 'report.dart';
import 'trial.dart';

/// Progresul copilului pe o treaptă (vine din Drift / sincronizare).
class StepProgress {
  const StepProgress({
    required this.stepId,
    this.mastered = false,
    this.rating = 1000,
    this.masteredAt,
    this.lastPracticed,
    this.recentIndependence = const [],
    this.gameIndependence = const {},
    this.gameTrials = const {},
    this.gameLastPlayed = const {},
  });

  final String stepId;
  final bool mastered;
  final double rating;
  final DateTime? masteredAt;
  final DateTime? lastPracticed;

  /// Independența (0..1) în ultimele sesiuni pe treaptă, de la veche la nouă (cel mult 3).
  final List<double> recentIndependence;

  /// Independența în ultima sesiune cu destule încercări (cel puțin 4) în fiecare joc al treptei.
  final Map<String, double> gameIndependence;

  /// Câte încercări a făcut copilul în fiecare joc al treptei (cât de cunoscut îi e jocul).
  final Map<String, int> gameTrials;

  /// Când a jucat ultima dată fiecare joc al treptei.
  final Map<String, DateTime> gameLastPlayed;

  /// Ultimele două sesiuni pe treaptă au fost foarte grele (sub 30% independență, cu destule
  /// încercări cât să conteze): copilul are nevoie de un pas înapoi, nu de mai multă presiune.
  /// Stăpânită și arătată independent (≥ 80%) în cel puțin două jocuri diferite ale treptei.
  bool get generalized => mastered && gameIndependence.values.where((i) => i >= 0.8).length >= 2;

  bool get struggling =>
      !mastered && recentIndependence.length >= 2 && recentIndependence.reversed.take(2).every((i) => i < 0.3);
}

/// [generalization] = verificarea generalizării: o treaptă stăpânită pe un singur joc, jucată pe
/// altul (plan §4: abilitatea se arată pe materiale diferite, nu doar în jocul în care a învățat-o).
enum ActivityKind { warmUp, target, maintenance, generalization, finale }

/// O activitate din orar: un joc pe o treaptă, cu câte runde.
class SessionActivity {
  const SessionActivity({
    required this.kind,
    required this.stepId,
    required this.gameId,
    required this.rounds,
    this.knownMix = 0,
    this.mixStepId,
    this.bridgeFor,
  });

  final ActivityKind kind;
  final String stepId;
  final String gameId;
  final int rounds;

  /// Proporția de runde din [mixStepId] (treaptă stăpânită) amestecate printre cele noi.
  final double knownMix;
  final String? mixStepId;

  /// Pas înapoi: treapta grea (ultimele sesiuni sub 30% independență) pentru care s-a ales azi
  /// treapta de dinainte. null = activitate obișnuită.
  final String? bridgeFor;

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
    List<String> gamesOf(String stepId) =>
        stepById(stepId)?.games.where(allowedGames.contains).toList() ?? const [];

    /// Jocul treptei ales după [score] (mai mic = mai bun); la egalitate decide ziua (aleator).
    String pick(StepProgress p, num Function(String game) score) {
      final games = gamesOf(p.stepId)..shuffle(rnd);
      final order = {for (final (i, g) in games.indexed) g: i};
      games.sort((a, b) {
        final c = score(a).compareTo(score(b));
        return c != 0 ? c : order[a]!.compareTo(order[b]!);
      });
      return games.first;
    }

    // Încălzirea și finalul: jocul cel mai cunoscut (previzibil, succes sigur).
    String familiarGame(StepProgress p) => pick(p, (g) => -(p.gameTrials[g] ?? 0));
    // Același obiectiv pe alt material: jocul jucat cel mai demult (niciodată = primul) —
    // generalizarea (plan §4: stăpânirea pe un singur joc nu e încă o abilitate).
    String freshGame(StepProgress p) =>
        pick(p, (g) => p.gameLastPlayed[g]?.millisecondsSinceEpoch ?? -1);
    // Un obiectiv în lucru: cât e încă greu (rating sub start), rămâne pe jocul cunoscut
    // (consecvență în achiziție); când merge, trece pe alt joc al treptei.
    String targetGame(StepProgress p) => p.rating >= EloRating.start ? freshGame(p) : familiarGame(p);

    final byId = {for (final p in progress) p.stepId: p};
    final playable = progress.where((p) => gamesOf(p.stepId).isNotEmpty).toList();
    final mastered = playable.where((p) => p.mastered).toList()..shuffle(rnd);
    // Obiectivele cu cel mai mic rating primesc întâi timp (cele mai grele acum); la egalitate
    // (de exemplu, trepte încă neîncepute) ordinea zilei e aleatoare, ca ariile să se rotească de
    // la o zi la alta. Ce s-a exersat deja azi trece la coadă (practica distribuită).
    final open = playable.where((p) => !p.mastered).toList()..shuffle(rnd);
    final today = DateTime(now.year, now.month, now.day);
    int key(StepProgress p) =>
        ((p.lastPracticed != null && !p.lastPracticed!.isBefore(today)) ? 1 << 20 : 0) + (p.rating / 25).round();
    open.sort((a, b) => key(a).compareTo(key(b)));
    // Pas înapoi: o treaptă la care ultimele două sesiuni au fost foarte grele cedează locul
    // treptei dinaintea ei din traseu (dacă are jocuri) — copilul revine la ce îi reușește
    // (momentum comportamental), apoi urcă din nou. Treapta grea rămâne obiectiv în plan.
    final candidates = <StepProgress>[];
    final bridgeFor = <String, String>{};
    for (final p in open) {
      final prev = p.struggling ? previousStep(p.stepId) : null;
      final next = prev != null && gamesOf(prev.id).isNotEmpty ? (byId[prev.id] ?? StepProgress(stepId: prev.id)) : p;
      if (candidates.any((c) => c.stepId == next.stepId)) continue;
      if (next != p) bridgeFor[next.stepId] = p.stepId;
      candidates.add(next);
    }
    // Blocurile de obiective din arii diferite, cât se poate (variație, mai puțină oboseală).
    final targets = <StepProgress>[];
    final domains = <Domain>{};
    for (final p in candidates) {
      if (targets.length == config.targetBlocks) break;
      if (domains.add(stepById(p.stepId)!.domain)) targets.add(p);
    }
    for (final p in candidates) {
      if (targets.length == config.targetBlocks) break;
      if (!targets.contains(p)) targets.add(p);
    }

    final out = <SessionActivity>[];
    if (mastered.isNotEmpty) {
      // Încălzirea nu repetă o treaptă care e deja pas înapoi azi.
      final w = mastered.where((m) => !bridgeFor.containsKey(m.stepId)).firstOrNull ?? mastered.first;
      out.add(SessionActivity(
        kind: ActivityKind.warmUp,
        stepId: w.stepId,
        gameId: familiarGame(w),
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
        // Pasul înapoi rămâne pe jocul cunoscut: azi contează reușita, nu materialul nou.
        gameId: bridgeFor.containsKey(t.stepId) ? familiarGame(t) : targetGame(t),
        rounds: config.roundsPerBlock,
        knownMix: known == null ? 0 : config.knownMix,
        mixStepId: known?.stepId,
        bridgeFor: bridgeFor[t.stepId],
      ));
    }

    final due = mastered.where((m) => _maintenanceDue(m, now)).firstOrNull;
    if (due != null) {
      out.add(SessionActivity(
        kind: ActivityKind.maintenance,
        stepId: due.stepId,
        gameId: freshGame(due),
        rounds: config.warmUpRounds,
      ));
    } else {
      // Verificarea generalizării (doar dacă azi nu e și o menținere — sesiunea rămâne scurtă):
      // o treaptă stăpânită, încă negeneralizată, pe un joc al ei în care n-a arătat-o încă.
      for (final m in mastered) {
        if (m.generalized) continue;
        final others = gamesOf(m.stepId).where((g) => (m.gameIndependence[g] ?? 0) < 0.8).toList();
        if (others.isEmpty) continue;
        out.add(SessionActivity(
          kind: ActivityKind.generalization,
          stepId: m.stepId,
          gameId: pick(m, (g) => others.contains(g) ? (m.gameLastPlayed[g]?.millisecondsSinceEpoch ?? -1) : 1 << 62),
          rounds: config.warmUpRounds + 1,
        ));
        break;
      }
    }

    // Final pe succes: o treaptă stăpânită, diferită de încălzire când se poate.
    if (mastered.isNotEmpty && out.last.kind != ActivityKind.maintenance) {
      final f = mastered.length > 1 ? mastered[1] : mastered.first;
      out.add(SessionActivity(
        kind: ActivityKind.finale,
        stepId: f.stepId,
        gameId: familiarGame(f),
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
