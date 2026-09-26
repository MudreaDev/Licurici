import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings.dart';

/// Intensitatea animațiilor (README §15.1). O singură sursă de adevăr: nicio animație
/// nu ocolește această politică.
enum MotionLevel {
  /// Toate straturile: idle, particule, parallax, sărbătoare.
  full,

  /// Modul calm: doar feedback scurt (estompare/schimbare de culoare), fără idle și particule.
  gentle,

  /// „Reduce motion” din sistem: fără mișcare.
  off,
}

class MotionPolicy {
  const MotionPolicy(this.level);

  final MotionLevel level;

  bool get ambient => level == MotionLevel.full;
  bool get particles => level == MotionLevel.full;
  bool get feedback => level != MotionLevel.off;

  /// Mișcări (săritură, clătinare, glisare) — doar la `full`; `gentle` rămâne la estompări.
  bool get movement => level == MotionLevel.full;

  Duration d(int ms) => level == MotionLevel.off ? Duration.zero : Duration(milliseconds: ms);

  static MotionPolicy of(BuildContext context, WidgetRef ref) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const MotionPolicy(MotionLevel.off);
    }
    return ref.watch(settingsProvider.select((s) => s.calm))
        ? const MotionPolicy(MotionLevel.gentle)
        : const MotionPolicy(MotionLevel.full);
  }
}
