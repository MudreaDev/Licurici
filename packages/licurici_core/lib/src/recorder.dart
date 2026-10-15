/// Înregistrarea unei sesiuni pe dispozitiv: jocurile raportează încercări și evenimente,
/// copilul își alege dispoziția la început și la final, iar la închidere rezultă un
/// [SessionRecord] (salvat local, sincronizat doar cu cont + consimțământ — ADR-004, ADR-011).
library;

import 'dart:math';

import 'development.dart';
import 'game.dart';
import 'build_copy.dart';
import 'cause_effect.dart';
import 'change.dart';
import 'fitts.dart';
import 'number_line.dart';
import 'stop_signal.dart';
import 'delay.dart';
import 'stacking.dart';
import 'fetch.dart';
import 'paint_by_ear.dart';
import 'place.dart';
import 'sound_memory.dart';
import 'mirror.dart';
import 'feeding.dart';
import 'gaze.dart';
import 'imitation.dart';
import 'instructions.dart';
import 'maze.dart';
import 'memory.dart';
import 'ordering.dart';
import 'puzzle.dart';
import 'reaction.dart';
import 'report.dart';
import 'rhythm.dart';
import 'search.dart';
import 'sequence.dart';
import 'shop.dart';
import 'shell.dart';
import 'sorting.dart';
import 'spot_diff.dart';
import 'switching.dart';
import 'trace.dart';
import 'tracking.dart';
import 'turns.dart';
import 'writing.dart';
import 'waiting.dart';
import 'trial.dart';

/// Treapta pe care o exersează un joc (prima din trasee) — încercările se leagă de ea.
String stepFor(String gameId) {
  final steps = stepsForGame(gameId);
  return steps.isEmpty ? 'NONE' : steps.first.id;
}

/// Ajutorul maxim primit într-o rundă `choice`, din ce a arătat ecranul (plan §3.3):
/// mânuța care arată răspunsul (model complet) → P4; ghidaj vizual (ținta pulsează) → P3;
/// indiciu vocal / variante estompate după greșeală → P2; altfel P0.
PromptLevel choicePromptLevel({
  required int wrongAttempts,
  required bool guideShown,
  bool handShown = false,
}) {
  if (handShown) return PromptLevel.p4;
  if (guideShown) return PromptLevel.p3;
  if (wrongAttempts > 0) return PromptLevel.p2;
  return PromptLevel.p0;
}

/// Câte reușite independente (P0, din prima) pe o treaptă o fac „cunoscută”.
const knownStepTrials = 5;

/// Strategia de ajutor pentru un joc (plan §3.3): pe o treaptă **nouă** (sub
/// [knownStepTrials] reușite independente în istoric) — most-to-least, cu întârziere
/// progresivă; pe o treaptă cunoscută — least-to-most (ajutorul vine doar dacă e nevoie).
PromptStrategy promptStrategyFor(String gameId, Iterable<SessionRecord> history) {
  final step = stepFor(gameId);
  var independent = 0;
  for (final s in history) {
    for (final t in s.trials) {
      if (t.stepId == step && t.correct && t.promptLevel == PromptLevel.p0) independent++;
    }
  }
  return independent >= knownStepTrials ? PromptStrategy.leastToMost : PromptStrategy.mostToLeast;
}

class SessionRecorder {
  SessionRecorder({required this.childId, DateTime Function()? clock, String? id})
      : _clock = clock ?? DateTime.now,
        id = id ?? _newId() {
    start = _clock();
  }

  final String id;
  final String childId;
  final DateTime Function() _clock;
  late final DateTime start;

  final List<Trial> _trials = [];
  final List<SessionEvent> _events = [];
  Mood? moodBefore;
  Mood? moodAfter;
  bool _closed = false;

  List<Trial> get trials => List.unmodifiable(_trials);
  List<SessionEvent> get events => List.unmodifiable(_events);
  /// Nimic de păstrat: nicio încercare și nicio cerere cu tabla de comunicare.
  bool get isEmpty =>
      _trials.isEmpty && !_events.any((e) => e.kind == SessionEventKind.request);
  bool get closed => _closed;

  void add(Trial t) {
    if (!_closed) _trials.add(t);
  }

  void event(SessionEventKind kind, {String? gameId}) {
    if (!_closed) _events.add(SessionEvent(kind, _clock(), gameId: gameId));
  }

  /// O rundă `choice` terminată. [chosenKey] = prima variantă greșită aleasă (dacă a existat).
  void choiceRound({
    required String gameId,
    required ChoiceRound round,
    required int wrongAttempts,
    required bool guideShown,
    required int latencyMs,
    bool handShown = false,
    String? chosenKey,
    int? seed,
    /// Nivelul jocului (la jocurile cu alegere: treapta de dificultate, `Difficulty.tier`).
    int? level,
  }) {
    final prompt = choicePromptLevel(
      wrongAttempts: wrongAttempts,
      guideShown: guideShown,
      handShown: handShown,
    );
    add(Trial(
      level: level,
      stepId: stepFor(gameId),
      gameId: gameId,
      // Runda se termină mereu pe răspunsul corect (învățare fără eroare); încercarea e
      // „corectă” doar dacă primul răspuns a fost cel bun.
      correct: wrongAttempts == 0,
      promptLevel: prompt,
      attempts: wrongAttempts + 1,
      latencyMs: latencyMs,
      at: _clock(),
      seed: seed,
      stimulusId: round.stimulusId,
      targetId: round.choices.firstWhere((c) => c.correct).key,
      chosenId: chosenKey,
    ));
  }

  /// Un nivel `reaction`: câte o încercare pe stimul (atinge / se abține).
  void reactionLevel(ReactionLevel level, List<ReactionResponse> responses) {
    final byIndex = {for (final r in responses) r.index: r};
    final step = stepFor(level.gameId);
    for (final s in level.stimuli) {
      final r = byIndex[s.index];
      final tapped = r?.tapped ?? false;
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: s.isGo == tapped,
        promptLevel: PromptLevel.p0,
        latencyMs: tapped ? r?.reactionMs : null,
        at: _clock(),
        seed: level.seed,
        stimulusId: s.kind.name,
        targetId: s.isGo ? 'atinge' : 'nu-atinge',
        chosenId: tapped ? 'atinge' : 'nu-atinge',
      ));
    }
  }

  /// Un nivel `perechi`: câte o încercare pe mutare (două cărți). Corectă = pereche găsită;
  /// la greșeală, ținta e prima carte și „alegerea” a doua (confuzii vizuale între imagini).
  void memoryLevel(MemoryResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final m in result.moves) {
      final match = result.isMatch(m);
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: match,
        promptLevel: PromptLevel.p0,
        latencyMs: m.ms,
        at: _clock(),
        seed: level.seed,
        targetId: level.cards[m.first],
        chosenId: match ? null : level.cards[m.second],
      ));
    }
  }

  /// Un nivel `sortam`: câte o încercare pe lucru pus. Corectă = din prima; la greșeală,
  /// ținta e grupa lui și „alegerea” prima grupă greșită (confuzii între categorii).
  void sortLevel(SortResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final p in result.placements) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: p.firstTry,
        // Lucrul greșit se întoarce înapoi: o nouă încercare, fără ajutor suplimentar.
        promptLevel: p.firstTry ? PromptLevel.p0 : PromptLevel.p2,
        attempts: p.wrongDrops + 1,
        latencyMs: p.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: p.item.emoji,
        targetId: p.item.binId,
        chosenId: p.firstWrongBin,
      ));
    }
  }

  /// Un nivel „pune în ordine” (`pasii-rutinei`, `ce-urmeaza`): câte o încercare pe poveste.
  /// Corectă = toți pașii puși din prima; ținta / alegerea = primul pas greșit (erori de ordine).
  void orderLevel(OrderResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.attempts) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: a.hinted ? PromptLevel.p3 : (a.clean ? PromptLevel.p0 : PromptLevel.p2),
        attempts: a.wrongTaps + 1,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: a.round.story.id,
        stimulusSet: level.gameId,
        difficulty: a.round.steps.length.toDouble(),
        targetId: a.expected,
        chosenId: a.firstWrong,
      ));
    }
  }

  /// Un nivel `la-magazin`: câte o încercare pe listă; produsele luate în plus =
  /// `offTargetTaps` (impulsivitate); dificultatea = lungimea listei.
  void shopLevel(ShopResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final t in result.trips) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: t.clean,
        promptLevel: PromptLevel.p0,
        latencyMs: t.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'lista-${t.round.list.length}',
        difficulty: t.round.list.length.toDouble(),
        offTargetTaps: t.extra,
      ));
    }
  }

  /// Un nivel `construieste`: câte o încercare pe model; mutările greșite ca încercări;
  /// modelul revăzut = ajutor P3; dificultatea = numărul de piese.
  void buildLevel(BuildResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final s in result.solves) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: s.clean,
        promptLevel: s.peeked ? PromptLevel.p3 : PromptLevel.p0,
        attempts: s.wrongMoves + 1,
        latencyMs: s.ms,
        at: _clock(),
        seed: level.seed,
        stimulusSet: level.axes.hideModelMs == null ? 'model-vizibil' : 'din-memorie',
        difficulty: s.round.model.length.toDouble(),
      ));
    }
  }

  /// Un nivel `diferente`: câte o încercare pe pereche de scene; atingerile greșite =
  /// `offTargetTaps`; dificultatea = numărul de diferențe.
  void diffLevel(DiffResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final s in result.solves) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: s.clean,
        promptLevel: PromptLevel.p0,
        latencyMs: s.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: '${s.scene.differences.length}-diferente',
        difficulty: s.scene.differences.length.toDouble(),
        offTargetTaps: s.wrongTaps,
      ));
    }
  }

  /// Un nivel `labirint`: câte o încercare pe labirint. Corectă = drum eficient (≥ 75% din cel
  /// mai scurt); lovirile de pereți = `offTargetTaps`; latența = timpul de gândire.
  void mazeLevel(MazeResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final r in result.runs) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.clean,
        promptLevel: PromptLevel.p0,
        latencyMs: r.planMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'eficienta-${(r.efficiency * 100).round()}',
        difficulty: (r.maze.cols * r.maze.rows).toDouble(),
        offTargetTaps: r.bumps,
      ));
    }
  }

  /// Un nivel „Linia numerelor”: câte o încercare pe număr; corectă dacă e la cel mult 10% din
  /// linie; ținta și estimarea (rotunjită) se păstrează, ca PAE să se poată calcula oricând;
  /// dificultatea = capătul liniei.
  void numberLineLevel(NumberLineResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final m in result.marks) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: result.isClose(m),
        promptLevel: PromptLevel.p0,
        latencyMs: m.latencyMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'eroare-${(result.paeOf(m) * 100).round()}',
        targetId: '${m.round.target}',
        chosenId: m.estimate.toStringAsFixed(1),
        difficulty: level.axes.max.toDouble(),
      ));
    }
  }

  /// Un nivel „Adu-mi”: câte o încercare pe cerere; corectă = niciun obiect greșit în coș;
  /// ținta = primul cuvânt cerut, „alegerea” = primul obiect greșit (confuzii între cuvinte).
  void fetchLevel(FetchResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.answers) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: PromptLevel.p0,
        attempts: a.wrong + 1,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: a.round.wanted.map((w) => w.word).join('+'),
        targetId: a.round.wanted.first.word,
        chosenId: a.firstWrong?.word,
        difficulty: a.round.table.length.toDouble(),
      ));
    }
  }

  /// Un nivel „Pune ursulețul”: câte o încercare pe propoziție; corectă = nicio așezare greșită;
  /// ținta = locul cerut („sub masă”), „alegerea” = primul loc greșit (confuzii pe / deasupra);
  /// dificultatea = câte locuri erau pe scenă.
  void placeLevel(PlaceResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.answers) {
      final r = a.round;
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: PromptLevel.p0,
        attempts: a.wrong + 1,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.tasks.map((t) => t.relation.name).join('+'),
        targetId: r.tasks.first.relation.at(r.landmark),
        chosenId: a.firstWrong?.at(r.landmark),
        difficulty: r.spots.length.toDouble(),
      ));
    }
  }

  /// Un nivel „Colorează ce auzi”: câte o încercare pe cerere; corectă = nicio colorare greșită;
  /// ținta = „obiect:culoare” cerut, „alegerea” = prima greșeală; dificultatea = culori în paletă.
  void paintLevel(PaintResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.answers) {
      final r = a.round;
      final t = r.tasks.first;
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: PromptLevel.p0,
        attempts: a.wrong + 1,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.tasks.map((t) => t.color.name).join('+'),
        targetId: '${r.slots[t.slot].name}:${t.color.word}',
        chosenId: a.firstWrong,
        difficulty: r.palette.length.toDouble(),
      ));
    }
  }

  /// Un nivel „Memorie cu sunete”: câte o încercare pe mutare (ca la Perechi); corectă = pereche
  /// animal–sunet; ținta = prima carte, „alegerea” = a doua, la greșeală.
  void soundMemoryLevel(SoundMemoryResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final m in result.moves) {
      final match = result.isMatch(m);
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: match,
        promptLevel: PromptLevel.p0,
        latencyMs: m.ms,
        at: _clock(),
        seed: level.seed,
        targetId: level.cards[m.first].id,
        chosenId: match ? null : level.cards[m.second].id,
        difficulty: level.pairs.toDouble(),
      ));
    }
  }

  /// Un nivel „Oglinda”: câte o încercare pe imitație; treapta după câte atingeri sunt de repetat
  /// (IMI1–3); ajutorul prin model repetat se notează ca P4, ca la „Fă ca Licurici”.
  void mirrorLevel(MirrorResult result) {
    final level = result.level;
    for (final a in result.answers) {
      final n = a.round.touches.length;
      add(Trial(
        level: level.level,
        stepId: 'IMI${n.clamp(1, 3)}',
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: a.modelRepeated ? PromptLevel.p4 : (a.clean ? PromptLevel.p0 : PromptLevel.p2),
        attempts: a.wrong + 1,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: a.round.touches.map((t) => t.id).join('+'),
        targetId: a.round.touches.first.id,
        chosenId: a.firstWrong?.id,
        difficulty: n.toDouble(),
      ));
    }
  }

  /// Un nivel „Turnul”: câte o încercare pe turn; corectă = fără alegeri greșite; încercările =
  /// alegeri greșite + 1; dificultatea = numărul de inele.
  void stackingLevel(StackingResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final b in result.builds) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: b.clean,
        promptLevel: PromptLevel.p0,
        attempts: b.wrong + 1,
        latencyMs: b.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'inele-${b.tower.size}',
        difficulty: b.tower.size.toDouble(),
        offTargetTaps: b.wrong,
      ));
    }
  }

  /// Un nivel „Acum sau mai mult?”: câte o încercare pe ofertă; corectă = a așteptat până la
  /// capăt; latența = cât s-a gândit; dificultatea = așteptarea cerută (secunde); `stimulusId`
  /// spune ce a ales (`acum` / `asteapta` / `a-renuntat`).
  void delayLevel(DelayResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final c in result.choices) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: c.completed,
        promptLevel: PromptLevel.p0,
        latencyMs: c.latencyMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: !c.waited ? 'acum' : (c.completed ? 'asteapta' : 'a-renuntat'),
        difficulty: c.offer.waitMs / 1000,
      ));
    }
  }

  /// Un nivel „Stop!”: câte o încercare pe aprindere; corectă = atins la verde / neatins la roșu;
  /// latența = timpul de reacție; la oprire, dificultatea = întârzierea semnalului (SSD, ms).
  void stopLevel(StopResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final t in result.trials) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: t.correct,
        promptLevel: PromptLevel.p0,
        latencyMs: t.rtMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: t.stop ? 'stop' : 'go',
        difficulty: t.ssdMs?.toDouble(),
      ));
    }
  }

  /// Un nivel „Atinge rapid”: câte o încercare pe bulă; corectă = atinsă din prima; latența =
  /// timpul de mișcare; dificultatea = indicele Fitts (biți).
  void fittsLevel(FittsResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final h in result.hits) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: h.misses == 0,
        promptLevel: PromptLevel.p0,
        latencyMs: h.movementMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'id-${(result.idOf(h.index) * 10).round()}',
        difficulty: result.idOf(h.index),
        offTargetTaps: h.misses,
      ));
    }
  }

  /// Un nivel `puzzle`: câte o încercare pe imagine; încercările = mutări greșite + 1;
  /// dificultatea = numărul de piese.
  void puzzleLevel(PuzzleResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final s in result.solves) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: s.clean,
        promptLevel: level.axes.model ? PromptLevel.p2 : PromptLevel.p0,
        attempts: s.wrongMoves + 1,
        latencyMs: s.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: s.round.image,
        difficulty: s.round.pieces.toDouble(),
      ));
    }
  }

  /// Un nivel `ce-s-a-schimbat`: câte o încercare pe rundă; tipul schimbării în `stimulusSet`
  /// (acuratețea pe tip de schimbare), numărul de obiecte ca dificultate.
  void changeLevel(ChangeResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.answers) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.correct,
        promptLevel: PromptLevel.p0,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: a.round.target.word,
        stimulusSet: a.round.kind.name,
        difficulty: level.axes.items.toDouble(),
        targetId: a.correct ? null : a.round.target.word,
        chosenId: a.correct ? null : a.chosen,
      ));
    }
  }

  /// Un nivel `atinge-si-vezi`: câte o încercare pe atingerea unui obiect (intenționată);
  /// atingerile pe lângă de dinainte se adună în `offTargetTaps` (KPI: proporția celor țintite).
  void causeLevel(CauseResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    var misses = 0;
    for (final t in result.touches) {
      if (!t.onObject) {
        misses++;
        continue;
      }
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: true,
        promptLevel: PromptLevel.p0,
        latencyMs: t.sinceLastMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: t.object,
        difficulty: level.objects.length.toDouble(),
        offTargetTaps: misses,
      ));
      misses = 0;
    }
  }

  /// Un nivel `hraneste-pestii`: câte o încercare pe pește hrănit. Corectă = din prima, la
  /// peștele flămând; încercările = trageri ratate + 1; dificultatea = viteza peștilor.
  void feedLevel(FeedResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final f in result.feeds) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: f.clean,
        promptLevel: PromptLevel.p0,
        attempts: f.misses + f.wrongFish + 1,
        latencyMs: f.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'precizie-${(f.precision * 100).round()}',
        difficulty: level.axes.speed,
        targetId: f.wrongFish > 0 ? 'pestele-flamand' : null,
        chosenId: f.wrongFish > 0 ? 'alt-peste' : null,
        offTargetTaps: f.misses,
      ));
    }
  }

  /// Un nivel `toba-magica`: câte o încercare pe ritm. Corectă = aceleași bătăi și tobe, în
  /// ritm; dificultatea = numărul de bătăi; modelul ascultat din nou = ajutor P4.
  void rhythmLevel(RhythmResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final p in result.plays) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: p.correct,
        promptLevel: p.replays > 0 ? PromptLevel.p4 : PromptLevel.p0,
        attempts: p.replays + 1,
        latencyMs: p.startMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: p.pattern.code,
        difficulty: p.pattern.beats.length.toDouble(),
        targetId: p.correct ? null : '${p.pattern.beats.length} bătăi',
        chosenId: p.correct ? null : '${p.taps.length} bătăi',
      ));
    }
  }

  /// Un nivel `fa-ca-licuriciul`: câte o încercare pe rundă. Corectă = repetat fără greșeli;
  /// modelul arătat din nou = ajutor P4; latența = cât a așteptat până la prima acțiune.
  void imitationLevel(ImitationResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.attempts) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: a.modelRepeated ? PromptLevel.p4 : (a.clean ? PromptLevel.p0 : PromptLevel.p2),
        attempts: a.wrong + 1,
        latencyMs: a.startMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: a.round.actions.map((x) => x.kind.name).join('+'),
        difficulty: a.round.actions.length.toDouble(),
        targetId: a.firstWrong == null ? null : a.round.actions.map((x) => x.id).join(','),
        chosenId: a.firstWrong,
      ));
    }
  }

  /// Un nivel `regula-se-schimba`: câte o încercare pe cartonaș. Ținta = regula; la greșeală,
  /// alegerea = cealaltă regulă (perseverare). Dificultatea: 1 = bloc, 2 = imediat după o
  /// schimbare (costul schimbării se calculează din latențe).
  void switchLevel(SwitchResult result) {
    final level = result.level;
    final step = level.axes.blocks > 1 || level.axes.mixed ? 'FEX4' : stepFor(level.gameId);
    final switches = level.switches.toSet();
    for (final r in result.responses) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.correct,
        promptLevel: PromptLevel.p0,
        latencyMs: r.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.item.card.id,
        difficulty: switches.contains(r.item.index) ? 2 : 1,
        targetId: r.item.rule.name,
        chosenId: r.correct ? null : (r.item.rule == SortRule.color ? SortRule.shape : SortRule.color).name,
      ));
    }
  }

  /// Un nivel `unde-se-uita`: câte o încercare pe rundă; corectă = prima atingere pe obiectul
  /// privit. Gestul adăugat după greșeală (când cerința era doar privirea) = ajutor P3.
  void gazeLevel(GazeResult result) {
    final level = result.level;
    final step = level.axes.cue == GazeCue.point ? 'ATN3' : 'ATN4';
    for (final a in result.answers) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.correct,
        promptLevel: a.extraCue ? PromptLevel.p3 : PromptLevel.p0,
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: level.axes.cue.name,
        stimulusSet: level.axes.similar ? 'asemanatoare' : 'diferite',
        targetId: a.round.side == 0 ? 'stanga' : 'dreapta',
        chosenId: a.correct ? null : (a.firstChoice == 0 ? 'stanga' : 'dreapta'),
      ));
    }
  }

  /// Un nivel `cauta`: câte o încercare pe obiect căutat. Latența = timpul de căutare;
  /// dificultatea = câte obiecte erau pe ecran (din ele: panta căutării vizuale).
  void searchLevel(SearchResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final f in result.finds) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: f.clean,
        promptLevel: PromptLevel.p0,
        attempts: f.wrongTaps + 1,
        latencyMs: f.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: f.round.target.word,
        stimulusSet: level.axes.similar ? 'asemanatoare' : 'diferite',
        difficulty: level.axes.items.toDouble(),
        targetId: f.round.target.word,
        chosenId: f.firstWrong,
        offTargetTaps: f.wrongTaps,
      ));
    }
  }

  /// Un nivel `urmareste-pestele`: câte o încercare pe rundă. Corectă = a atins peștele lui
  /// după oprire; alegerea greșită = pierderea urmăririi (`chosenId`); atingerile din timpul
  /// înotului = `offTargetTaps`; dificultatea = numărul de pești; setul = asemănarea.
  void trackLevel(TrackResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final r in result.responses) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.correct,
        promptLevel: PromptLevel.p0,
        attempts: 1,
        latencyMs: r.rtMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.trial.fish[r.trial.target].species,
        stimulusSet: level.axes.similarity.name,
        difficulty: level.axes.fish.toDouble(),
        targetId: 'peste${r.trial.target}',
        chosenId: r.chosen == null ? null : 'peste${r.chosen}',
        offTargetTaps: r.earlyTaps,
      ));
    }
  }

  /// Un nivel `scriem-cifrele` / `scriem-literele`: câte o încercare pe semn. Corectă = toate
  /// trăsăturile duse la capăt fără ieșiri; încercările = ieșiri + 1; stimulul = semnul;
  /// dificultatea = cât de îngust e drumul (1 / lățime). Cu puncte de ghidaj = ajutor P3.
  void writingLevel(WritingResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final r in result.runs) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.clean,
        promptLevel: level.axes.guide == TraceGuide.dots ? PromptLevel.p3 : PromptLevel.p0,
        attempts: r.exits + 1,
        latencyMs: r.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.glyph.char,
        difficulty: 1 / level.axes.width,
        targetId: r.glyph.char,
        offTargetTaps: r.exits,
      ));
    }
  }

  /// Un nivel `pe-rand`: câte o încercare pe ciclu (rândul lui Licurici + al copilului).
  /// Corectă = n-a atins nimic în rândul lui Licurici și, când trebuia, a dat singur rândul;
  /// atingerile în rândul celuilalt = `offTargetTaps`; rândul dat abia după întrebarea lui
  /// Licurici = ajutor verbal (P2); dificultatea = secundele de așteptare.
  void turnLevel(TurnResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final c in result.cycles) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: c.clean,
        promptLevel: c.passPrompted ? PromptLevel.p2 : PromptLevel.p0,
        attempts: c.earlyTaps + 1,
        latencyMs: c.placeMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: level.axes.passTurn ? 'da-randul' : 'asteapta',
        difficulty: level.axes.waitMs / 1000,
        offTargetTaps: c.earlyTaps,
      ));
    }
  }

  /// Un nivel `asculta-si-fa`: câte o încercare pe instrucțiune. Corectă = toți pașii în ordine,
  /// din prima; ajutorul = repetarea (P2) sau pozele în ordine (P3); dificultatea = numărul de
  /// pași; confuzia = primul obiect atins greșit.
  void instructionLevel(InstructionResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final a in result.attempts) {
      final r = a.round;
      String? wrong;
      for (var i = 0; i < a.taps.length; i++) {
        if (i >= r.order.length || a.taps[i] != r.order[i]) {
          wrong = r.table[a.taps[i]].word;
          break;
        }
      }
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: a.clean,
        promptLevel: a.prompt,
        attempts: max(1, a.taps.length - r.order.length + 1),
        latencyMs: a.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.reversedWording ? 'invers' : '${r.order.length}-pasi',
        difficulty: r.order.length.toDouble(),
        targetId: r.table[r.order.first].word,
        chosenId: wrong,
      ));
    }
  }

  /// Un nivel `semaforul`: câte o încercare pe așteptare. Corectă = n-a atins înainte de verde
  /// și a atins la verde; atingerile anticipate = `offTargetTaps`; dificultatea = secundele de
  /// așteptare (KPI: cât poate aștepta).
  void waitLevel(WaitResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final r in result.responses) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.clean,
        promptLevel: PromptLevel.p0,
        attempts: r.anticipations + 1,
        latencyMs: r.rtMs,
        at: _clock(),
        seed: level.seed,
        stimulusId: 'verde',
        difficulty: r.trial.waitMs / 1000,
        offTargetTaps: r.anticipations,
      ));
    }
  }

  /// Un nivel `traseaza`: câte o încercare pe drum. Corectă = dus până la capăt fără ieșiri;
  /// încercările = ieșiri + 1; dificultatea = cât de îngust e drumul (1 / lățime).
  void traceLevel(TraceResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final r in result.runs) {
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: r.clean,
        promptLevel: level.axes.guide == TraceGuide.dots ? PromptLevel.p3 : PromptLevel.p0,
        attempts: r.exits + 1,
        latencyMs: r.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: r.path.shape.name,
        difficulty: 1 / level.axes.width,
      ));
    }
  }

  /// Un nivel `cucu-bau`: câte o încercare pe rundă; dificultatea = numărul de mutări
  /// (KPI: acuratețea în funcție de mutări).
  void shellLevel(ShellResult result) {
    final level = result.level;
    final step = stepFor(level.gameId);
    for (final p in result.picks) {
      final round = level.rounds[p.round];
      add(Trial(
        level: level.level,
        stepId: step,
        gameId: level.gameId,
        correct: result.isCorrect(p),
        promptLevel: PromptLevel.p0,
        latencyMs: p.ms,
        at: _clock(),
        seed: level.seed,
        stimulusId: round.thing.emoji,
        difficulty: round.swaps.length.toDouble(),
        targetId: 'pahar-${round.answer}',
        chosenId: result.isCorrect(p) ? null : 'pahar-${p.slot}',
      ));
    }
  }

  /// O secvență `simon` (o încercare; corectă dacă a fost repetată complet).
  void sequence(SequenceResult result, {required bool secondChance, int? latencyMs}) {
    add(Trial(
      level: result.level.level,
      stepId: stepFor(result.level.gameId),
      gameId: result.level.gameId,
      correct: result.complete,
      // A doua vizionare a secvenței e un ajutor (model repetat).
      promptLevel: secondChance ? PromptLevel.p4 : PromptLevel.p0,
      attempts: secondChance ? 2 : 1,
      latencyMs: latencyMs,
      at: _clock(),
      seed: result.level.seed,
      stimulusId: 'span-${result.level.expected.length}',
    ));
  }

  /// Închide sesiunea. Null dacă nu s-a jucat nimic (nu salvăm sesiuni goale).
  SessionRecord? close() {
    if (_closed) return null;
    _closed = true;
    if (isEmpty) return null;
    return SessionRecord(
      id: id,
      childId: childId,
      start: start,
      end: _clock(),
      trials: List.unmodifiable(_trials),
      events: List.unmodifiable(_events),
      moodBefore: moodBefore,
      moodAfter: moodAfter,
    );
  }

  static final _rnd = Random.secure();

  /// UUID v4 (fără dependențe).
  static String _newId() {
    final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i, int j) => [for (var k = i; k < j; k++) b[k].toRadixString(16).padLeft(2, '0')].join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }
}
