import 'dart:math' as math;

import '../motion.dart';

enum MascotMood { idle, happy, encourage, sleep }

/// Poza personajului la un moment dat: o funcție PURĂ de timp, stare și [MotionPolicy]
/// (ADR-028). Unghiurile sunt în radiani, distanțele în unitățile cadrului (1024).
class RigPose {
  const RigPose({
    this.hover = 0,
    this.breath = 0,
    this.squash = 0,
    this.tilt = 0,
    this.wing = 0,
    this.wingRest = 0,
    this.arm = 0,
    this.blink = 0,
    this.glow = 0.75,
    this.sparkle,
  });

  /// Deplasare pe verticală (negativ = în sus): plutire + săritură.
  final double hover;

  /// Respirația: +/- pe înălțimea corpului (scara Y − 1), ancorată la picioare.
  final double breath;

  /// Squash & stretch pe tot personajul: pozitiv = turtit (lat și scund).
  final double squash;

  /// Înclinarea întregului personaj.
  final double tilt;

  /// Bătaia aripilor (pozitiv = ridicate), simetrică stânga/dreapta.
  final double wing;

  /// Poziția de repaus a aripilor (negativ = lăsate în jos, ca la somn).
  final double wingRest;

  /// Rotația brațului în jurul umărului (negativ = ridică bagheta).
  final double arm;

  /// Pleoapele: 0 = deschise, 1 = închise.
  final double blink;

  /// Lumina lanternei (burta): ~0.3 stinsă … 1.5 foarte puternică.
  final double glow;

  /// Progresul scânteilor din baghetă (0..1) sau `null` = fără scântei.
  final double? sparkle;

  /// Perioada buclei de idle: toate frecvențele de mai jos intră de un număr întreg de ori,
  /// deci bucla se reia fără salt.
  static const loop = 12.0;

  /// [t] = secunde în bucla de idle (0..[loop]); [r] = progresul reacției (0..1, 0 = fără reacție).
  static RigPose of({
    required MascotMood mood,
    required double t,
    required double r,
    required MotionPolicy motion,
  }) {
    // Mișcarea de fond (idle) doar la `full`; reacțiile cu mișcare doar dacă `movement`;
    // `gentle` păstrează numai feedback-ul de lumină; `off` = poză statică.
    final amb = motion.ambient ? 1.0 : 0.0;
    final mov = motion.movement ? 1.0 : 0.0;
    final fb = motion.feedback ? 1.0 : 0.0;
    final ta = t * amb;
    double wave(double period, [double phase = 0]) =>
        math.sin(2 * math.pi * (ta / period + phase)) * amb;

    final bump = math.sin(math.pi * r.clamp(0.0, 1.0)); // 0 → 1 → 0

    switch (mood) {
      case MascotMood.sleep:
        return RigPose(
          hover: 6 * wave(4),
          breath: 0.018 * wave(4),
          wingRest: -0.14,
          blink: 1,
          glow: 0.35 + 0.12 * wave(4),
        );
      case MascotMood.happy:
        final jump = _phase(r, 0.12, 0.72);
        final squash =
            0.09 * _bell(r, 0, 0.12) -
            0.06 * _bell(r, 0.12, 0.4) +
            0.1 * _bell(r, 0.72, 1);
        return RigPose(
          hover: 28 * wave(2.4) - 150 * math.sin(math.pi * jump) * mov,
          breath: 0.012 * wave(3),
          squash: squash * mov,
          wing:
              0.1 * wave(12 / 18) +
              0.3 * math.sin(r * 2 * math.pi * 4).abs() * bump * mov,
          arm: -0.55 * bump * mov,
          blink: _blink(ta) * amb,
          glow: 0.75 + 0.12 * wave(2.4) + 0.65 * bump * fb,
          sparkle: motion.particles && r > 0 && r < 1 ? r : null,
        );
      case MascotMood.encourage:
        return RigPose(
          hover: 28 * wave(2.4),
          breath: 0.012 * wave(3),
          tilt: 0.12 * math.sin(r * math.pi * 2) * mov,
          wing: 0.1 * wave(12 / 18),
          arm: (-0.22 + 0.1 * math.sin(r * math.pi * 4)) * bump * mov,
          blink: math.max(
            _blink(ta) * amb,
            0.35 * bump * mov,
          ), // privire blândă
          glow: 0.75 + 0.12 * wave(2.4) + 0.25 * bump * fb,
        );
      case MascotMood.idle:
        return RigPose(
          hover: 28 * wave(2.4),
          breath: 0.012 * wave(3),
          wing: 0.1 * wave(12 / 18),
          arm: 0.04 * wave(6, 0.25),
          blink: _blink(ta) * amb,
          glow: 0.75 + 0.12 * wave(2.4),
        );
    }
  }

  /// Clipitul: momente fixe în buclă (unul dublu), fiecare ~160 ms.
  static double _blink(double t) {
    const at = [2.8, 6.1, 6.45, 9.9];
    const half = 0.08;
    var v = 0.0;
    for (final c in at) {
      final d = (t - c).abs();
      if (d < half) v = math.max(v, 1 - d / half);
    }
    return v;
  }

  /// 0 → 1 între [a] și [b] (liniar, cu capete fixe).
  static double _phase(double r, double a, double b) =>
      ((r - a) / (b - a)).clamp(0.0, 1.0);

  /// Clopot 0 → 1 → 0 între [a] și [b], zero în afară.
  static double _bell(double r, double a, double b) =>
      r <= a || r >= b ? 0 : math.sin(math.pi * _phase(r, a, b));
}
