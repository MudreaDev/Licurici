/// Strategia de ajutor (plan §3.3): cât ajutor primește copilul, când, și cum se estompează.
library;

import 'trial.dart';

enum PromptOrder {
  /// Treaptă cunoscută: pornește fără ajutor; ajutorul crește doar după greșeală sau pauză.
  leastToMost,

  /// Treaptă nouă: pornește cu ajutor mult, care scade după reușite (fading).
  mostToLeast,

  /// Întârziere progresivă: ajutorul „care garantează reușita” vine după 0 s, apoi 2 s, 4 s…
  timeDelay,
}

/// Planul de ajutor pentru O încercare (decis înainte ca ea să înceapă).
class PromptPlan {
  const PromptPlan({
    this.start = PromptLevel.p0,
    this.delay,
    this.controlling = PromptLevel.p3,
  });

  /// Ajutorul dat de la început.
  final PromptLevel start;

  /// La `timeDelay`: după cât timp vine ajutorul [controlling]; `null` = fără întârziere programată.
  final Duration? delay;
  final PromptLevel controlling;
}

/// Strategia (fixată de specialist pe obiectiv sau aleasă implicit după starea treptei).
class PromptStrategy {
  const PromptStrategy({
    this.order = PromptOrder.leastToMost,
    this.maxLevel = PromptLevel.p4,
    this.idleDelay = const Duration(seconds: 5),
    this.delays = const [Duration.zero, Duration(seconds: 2), Duration(seconds: 4)],
    this.fadeAfter = 2,
  })  : assert(fadeAfter >= 1),
        assert(delays != const <Duration>[]);

  final PromptOrder order;

  /// Plafonul (ex. „fără P4: copilul se enervează la mâna animată”).
  final PromptLevel maxLevel;

  /// După cât timp fără răspuns crește ajutorul cu un nivel.
  final Duration idleDelay;

  /// Treptele întârzierii progresive (timeDelay).
  final List<Duration> delays;

  /// Câte reușite la rând la același nivel până coborâm ajutorul (mostToLeast / timeDelay).
  final int fadeAfter;

  /// Planul pentru încercarea următoare, din încercările anterioare ale treptei (cele mai noi
  /// la final). Fading-ul e deterministic: aceleași date → același plan.
  PromptPlan planFor(List<Trial> history) {
    switch (order) {
      case PromptOrder.leastToMost:
        return const PromptPlan();
      case PromptOrder.mostToLeast:
        // pornim de la plafon; după [fadeAfter] reușite la rând cu nivelul de start, coborâm un nivel;
        // o greșeală (sau un ajutor peste start) ne urcă înapoi un nivel.
        var level = maxLevel;
        var streak = 0;
        for (final t in history) {
          final ok = t.correct && t.attempts == 1 && !(t.promptLevel > level);
          if (ok) {
            if (++streak >= fadeAfter && level > PromptLevel.p0) {
              level = level - 1;
              streak = 0;
            }
          } else {
            level = PromptLevel.min(level + 1, maxLevel);
            streak = 0;
          }
        }
        return PromptPlan(start: level);
      case PromptOrder.timeDelay:
        var i = 0;
        var streak = 0;
        for (final t in history) {
          if (t.correct && t.attempts == 1) {
            if (++streak >= fadeAfter && i < delays.length - 1) {
              i++;
              streak = 0;
            }
          } else {
            i = i > 0 ? i - 1 : 0;
            streak = 0;
          }
        }
        return PromptPlan(delay: delays[i], controlling: PromptLevel.min(PromptLevel.p3, maxLevel));
    }
  }

  /// Ajutorul activ la [elapsed] de la finalul instrucțiunii, după [errors] greșeli, în [plan].
  /// Crește cu un nivel la fiecare greșeală și la fiecare [idleDelay] fără răspuns (învățare fără
  /// eroare: copilul ajunge mereu la răspunsul corect).
  PromptLevel levelAt(PromptPlan plan, {required Duration elapsed, int errors = 0}) {
    var level = plan.start;
    if (plan.delay case final d? when elapsed >= d) {
      level = PromptLevel.max(level, plan.controlling);
    }
    final idleSteps = idleDelay > Duration.zero ? elapsed.inMicroseconds ~/ idleDelay.inMicroseconds : 0;
    level = level + (errors + idleSteps);
    return PromptLevel.min(level, maxLevel);
  }

  /// Implicit: treaptă nouă → mult la puțin; treaptă în lucru cu independență bună → puțin la mult.
  static PromptStrategy defaultFor(List<Trial> history, {PromptLevel maxLevel = PromptLevel.p4}) {
    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
    final independent = recent.where((t) => t.independent).length;
    final known = recent.length >= 5 && independent / recent.length >= 0.6;
    return PromptStrategy(
      order: known ? PromptOrder.leastToMost : PromptOrder.mostToLeast,
      maxLevel: maxLevel,
    );
  }
}
