import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fx/mesh_warp.dart';
import 'illustration.dart';
import 'motion.dart';

enum MascotMood {
  idle,
  happy,
  encourage,
  think,
  wave,

  /// Brațele sus — finalul unui joc.
  celebrate,

  /// Ochii închiși, aripile în repaus — pauză, „pe mâine”.
  sleep,
}

/// Rig-ul ilustrației (coordonate normalizate pe pânza pătrată a cadrelor, vezi
/// `packages/game_content/art/illustrations/README.md`).
abstract final class MascotRig {
  static const wingLeftPivot = Offset(0.44, 0.47);
  static const wingRightPivot = Offset(0.56, 0.47);
  static const belly = Offset(0.5, 0.68);
  static const bellyRadius = 0.2;

  static AssetImage frame(String name) => illustration('mascot/$name');
  static final wingLeft = frame('wing_left');
  static final wingRight = frame('wing_right');
  static final blink = frame('blink');

  static AssetImage forMood(MascotMood mood) => frame(mood.name);

  static Iterable<AssetImage> get all => [
    for (final m in MascotMood.values) forMood(m),
    blink,
    wingLeft,
    wingRight,
  ];

  static Future<bool>? _available;

  /// Dacă ilustrațiile există în pachet (altfel rămâne mascota desenată în cod).
  static Future<bool> available() => _available ??= () async {
    try {
      await rootBundle.load(
        'packages/game_content/art/illustrations/mascot/idle.webp',
      );
      return true;
    } on Object {
      return false;
    }
  }();

  /// Pre-încărcare (ecranul de pornire), ca schimbarea expresiei să nu clipească.
  static Future<void> precache(BuildContext context) async {
    if (!await available() || !context.mounted) return;
    await Future.wait([for (final i in all) precacheImage(i, context)]);
  }
}

/// Mascota din ilustrații, pe straturi (lumina burticii, aripi în spate, corp), animată
/// procedural. Primește controlerele de la `Mascot`, care decide politica de mișcare.
class LayeredMascot extends StatelessWidget {
  const LayeredMascot({
    super.key,
    required this.size,
    required this.mood,
    required this.motion,
    required this.idle,
    required this.react,
    required this.blink,
  });

  final double size;
  final MascotMood mood;
  final MotionPolicy motion;

  /// 0..1 repetat (2,4 s): plutire, respirație, bătaia aripilor.
  final Animation<double> idle;

  /// 0..1 o dată, la fiecare reacție.
  final Animation<double> react;

  /// 0..1 repetat (4,2 s): ochii se închid în ultimele ~180 ms.
  final Animation<double> blink;

  bool get _happy => mood == MascotMood.happy || mood == MascotMood.celebrate;
  bool get _asleep => mood == MascotMood.sleep;
  double get _t => idle.value * 2 * math.pi;

  double get _bump => motion.movement
      ? math.sin(Curves.easeOut.transform(react.value) * math.pi)
      : 0;

  /// Aripile bat de trei ori pe ciclu; mai repede și mai larg când se bucură.
  double get _flap => motion.ambient
      ? math.sin(_t * (_happy ? 5 : (_asleep ? 1 : 3))) *
            (_asleep ? 0.04 : 0.16 + (_happy ? _bump * 0.12 : 0))
      : 0;

  /// Respirație + turtire la aterizarea după săritură.
  double get _squash {
    final breath = motion.ambient
        ? math.sin(_t) * (_asleep ? 0.022 : 0.012)
        : 0.0;
    final land = _happy && motion.movement
        ? math.min(0.0, math.sin(react.value * math.pi * 2)) * 0.06
        : 0.0;
    return breath + land;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([idle, react, blink]),
    builder: (context, _) {
      final dy =
          (motion.ambient ? math.sin(_t) * size * 0.025 : 0.0) -
          (_happy ? _bump * size * 0.16 : 0.0);
      final tilt = switch (mood) {
        MascotMood.encourage || MascotMood.think =>
          motion.movement ? math.sin(react.value * math.pi) * 0.08 : 0.0,
        MascotMood.wave => motion.ambient ? math.sin(_t) * 0.03 : 0.0,
        _ => 0.0,
      };
      final glow =
          0.55 +
          (motion.ambient ? math.sin(_t) * 0.15 : 0.0) +
          (_happy ? _bump * 0.35 : 0.0);
      final closed =
          motion.ambient && mood == MascotMood.idle && blink.value > 0.957;
      return Transform.translate(
        offset: Offset(0, dy),
        child: Transform.rotate(
          angle: tilt,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BellyGlow(glow)),
              WarpedImage(
                image: MascotRig.wingLeft,
                warp: () =>
                    Warps.flap(pivot: MascotRig.wingLeftPivot, angle: -_flap),
                cols: 10,
                rows: 10,
              ),
              WarpedImage(
                image: MascotRig.wingRight,
                warp: () =>
                    Warps.flap(pivot: MascotRig.wingRightPivot, angle: _flap),
                cols: 10,
                rows: 10,
              ),
              WarpedImage(
                image: closed ? MascotRig.blink : MascotRig.forMood(mood),
                warp: () => Warps.squash(_squash, anchorY: 0.95),
                cols: 6,
                rows: 8,
              ),
              if (_happy &&
                  motion.particles &&
                  react.value > 0 &&
                  react.value < 1)
                CustomPaint(painter: _Sparkles(react.value)),
            ],
          ),
        ),
      );
    },
  );
}

/// Lumina caldă din spatele burticii-felinar.
class _BellyGlow extends CustomPainter {
  _BellyGlow(this.intensity);

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
      MascotRig.belly.dx * size.width,
      MascotRig.belly.dy * size.height,
    );
    final r = MascotRig.bellyRadius * size.width * (1.4 + intensity * 0.6);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(
              0xFFFFF3B0,
            ).withValues(alpha: (0.75 * intensity).clamp(0.0, 1.0)),
            const Color(0x00F6DF84),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BellyGlow old) => old.intensity != intensity;
}

/// Câteva sclipiri care se depărtează și se sting (8 particule).
class _Sparkles extends CustomPainter {
  _Sparkles(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final fade = (1 - t).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFFF2CF6B).withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2 + 0.3;
      final d = size.width * (0.3 + 0.25 * Curves.easeOut.transform(t));
      final p = center + Offset(math.cos(a), math.sin(a)) * d;
      final r = size.width * 0.025 * (1 - t * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - r * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + r * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - r * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Sparkles old) => old.t != t;
}
