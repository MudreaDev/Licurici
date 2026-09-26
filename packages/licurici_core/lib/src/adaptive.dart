/// Dificultate adaptivă pe o abilitate (README §15): pe ultimele [window] încercări,
/// acuratețe sub [lowerBound] → mai ușor; peste [upperBound] → mai greu.
library;

import 'difficulty.dart';

enum AdaptiveDecision { easier, keep, harder }

class AdaptiveRule {
  const AdaptiveRule({this.window = 20, this.lowerBound = 0.6, this.upperBound = 0.9})
      : assert(window > 0),
        assert(lowerBound < upperBound);

  final int window;
  final double lowerBound;
  final double upperBound;

  /// [recent] = rezultatele încercărilor, cele mai noi la final (`true` = corect din prima).
  /// Nu decide nimic până nu există o fereastră completă.
  AdaptiveDecision decide(List<bool> recent) {
    if (recent.length < window) return AdaptiveDecision.keep;
    final last = recent.sublist(recent.length - window);
    final accuracy = last.where((ok) => ok).length / window;
    if (accuracy < lowerBound) return AdaptiveDecision.easier;
    if (accuracy > upperBound) return AdaptiveDecision.harder;
    return AdaptiveDecision.keep;
  }

  Difficulty apply(Difficulty current, List<bool> recent) => switch (decide(recent)) {
        AdaptiveDecision.easier => current.easier(),
        AdaptiveDecision.harder => current.harder(),
        AdaptiveDecision.keep => current,
      };
}
