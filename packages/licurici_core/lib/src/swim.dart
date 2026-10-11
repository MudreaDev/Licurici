/// Cum înoată o vietate în jocurile cu reacție („Pescarul”): aceeași idee ca peștii din acvariu
/// (`aquarium.dart` — împingere din coadă, apoi alunecare), dar pe un drum fix, dat de nivel:
/// de la punctul de apariție, cu deplasarea (driftX, driftY), în timpul cât stă pe ecran.
///
/// Drumul total și durata nu se schimbă (nivelul și măsurarea timpului de reacție rămân
/// aceleași); se schimbă doar **cum** îl parcurge: în reprize, cu legănare, cu corpul orientat
/// după mers și cu unda din coadă mai rapidă când împinge.
library;

import 'dart:math';

/// Felul în care se mișcă vietatea (după desen).
enum SwimStyle {
  /// Pește: undă prin corp spre coadă, reprize de înot.
  fish,

  /// Caracatiță: se strânge și se întinde (jet), urcă în salturi.
  jet,

  /// Crab: merge pe lângă, legănat, fără undă.
  scuttle,
}

SwimStyle swimStyleFor(String emoji) => switch (emoji) {
      '🐙' || '🦑' || '🪼' => SwimStyle.jet,
      '🦀' || '🦞' => SwimStyle.scuttle,
      _ => SwimStyle.fish,
    };

/// Poziția și forma vietății la un moment dat.
class SwimPose {
  const SwimPose({
    required this.progress,
    required this.sway,
    required this.tilt,
    required this.tailPhase,
    required this.thrust,
    required this.squash,
  });

  /// Cât din drum a parcurs (0 → 1, crescător).
  final double progress;

  /// Abaterea verticală de la drum, ca fracție din înălțimea vietății.
  final double sway;

  /// Înclinarea corpului (radiani; pozitiv = cu capul în jos, în sensul acelor de ceas).
  final double tilt;

  /// Faza undei din corp (radiani), crește mai repede când împinge.
  final double tailPhase;

  /// Cât de tare împinge acum (0 = alunecă, 1 = repriză de înot).
  final double thrust;

  /// Strângerea corpului (doar la jet): 1 = normal, < 1 = strâns pe lățime și alungit.
  final double squash;
}

/// Reprizele pe drum: câte în timpul vizibil (cel puțin una).
int _strokes(int visibleMs) => max(1, (visibleMs / 900).round());

/// Poza la momentul [t] ∈ [0, 1] din timpul vizibil. [phase] decalează vietățile între ele
/// (din indexul stimulului), ca să nu înoate toate la fel.
SwimPose swimPose(
  double t, {
  required SwimStyle style,
  required int visibleMs,
  required double driftX,
  required double driftY,
  double phase = 0,
}) {
  final u = t.clamp(0.0, 1.0);
  final n = _strokes(visibleMs);
  // Viteza 1 + a·cos(2πnu) → drumul u + a/(2πn)·sin(2πnu): crescător (a < 1), 0 → 1.
  const a = 0.65;
  final w = 2 * pi * n;
  final progress = u + a / w * sin(w * u);
  final speed = 1 + a * cos(w * u); // 0.35 … 1.65
  final thrust = ((speed - (1 - a)) / (2 * a)).clamp(0.0, 1.0);
  final seconds = u * visibleMs / 1000;
  final moving = driftX.abs() + driftY.abs() > 1e-6;

  switch (style) {
    case SwimStyle.fish:
      final sway = 0.06 * sin(2 * pi * 0.7 * seconds + phase);
      final dSway = 0.06 * 2 * pi * 0.7 * cos(2 * pi * 0.7 * seconds + phase);
      // Corpul urmează direcția mersului (drum + legănare), cu înclinarea limitată.
      final vx = driftX.abs() * speed + 1e-3;
      final vy = driftY * speed * 0.6 + dSway * 0.15;
      final tilt = moving ? atan2(vy, vx).clamp(-0.35, 0.35) : 0.12 * sin(seconds * 2 + phase);
      // Coada bate mai des când împinge: frecvența 1,6 → 4 bătăi/s.
      final tailPhase = 2 * pi * (2.6 * seconds) + 1.6 * sin(w * u) + phase;
      return SwimPose(progress: progress, sway: sway, tilt: tilt, tailPhase: tailPhase, thrust: thrust, squash: 1);
    case SwimStyle.jet:
      // Se strânge înainte de fiecare impuls, apoi se întinde și alunecă.
      final squash = 1 - 0.18 * thrust;
      final sway = -0.05 * thrust;
      return SwimPose(progress: progress, sway: sway, tilt: 0.08 * sin(w * u + phase), tailPhase: w * u, thrust: thrust, squash: squash);
    case SwimStyle.scuttle:
      // Pași mărunți: un mic salt pe fiecare pas, corpul se leagănă stânga-dreapta.
      final step = sin(2 * pi * 5 * seconds + phase);
      return SwimPose(progress: u, sway: -0.04 * step.abs(), tilt: 0.1 * step, tailPhase: 0, thrust: 0.5, squash: 1);
  }
}

/// Deplasarea laterală a unei felii a corpului de pește la poziția [x] ∈ [0, 1]
/// (0 = vârful botului, 1 = vârful cozii), ca fracție din înălțimea desenului.
/// Capul aproape nu se mișcă; unda crește spre coadă (înot carangiform, ca la majoritatea
/// peștilor de recif).
double bodyWave(double x, SwimPose pose) {
  final envelope = pow(x.clamp(0.0, 1.0), 2).toDouble();
  final amplitude = 0.05 + 0.07 * pose.thrust;
  return amplitude * envelope * sin(pose.tailPhase - 2 * pi * 0.9 * x);
}
