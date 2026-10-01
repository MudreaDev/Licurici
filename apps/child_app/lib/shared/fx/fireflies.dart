import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Licurici care plutesc în fundal: fiecare are o traiectorie proprie (sume de sinusoide,
/// din seed) și o lumină care pulsează lent (≤ 0,4 Hz — departe de pragul de 3 clipiri/s).
/// Cel mult 40 de particule (README §15.1).
class FireflyField extends StatelessWidget {
  const FireflyField({
    super.key,
    required this.count,
    required this.seed,
    required this.color,
    required this.time,
    this.region = const Rect.fromLTRB(0, 0.08, 1, 0.85),
  });

  final int count;
  final int seed;
  final Color color;

  /// Timpul scenei, în secunde.
  final ValueListenable<double> time;

  /// Zona (fracțiuni din lățime/înălțime) în care plutesc.
  final Rect region;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _FireflyPainter(
      flies: _Firefly.swarm(math.min(count, 40), seed, region),
      color: color,
      time: time,
    ),
  );
}

class _Firefly {
  const _Firefly(
    this.x,
    this.y,
    this.ax,
    this.ay,
    this.fx,
    this.fy,
    this.phase,
    this.size,
    this.pulse,
  );

  final double x, y, ax, ay, fx, fy, phase, size, pulse;

  static List<_Firefly> swarm(int n, int seed, Rect region) {
    final r = math.Random(seed ^ 0x5eed);
    double between(double a, double b) => a + r.nextDouble() * (b - a);
    return [
      for (var i = 0; i < n; i++)
        _Firefly(
          between(region.left, region.right),
          between(region.top, region.bottom),
          between(0.02, 0.06),
          between(0.015, 0.04),
          between(0.05, 0.14),
          between(0.04, 0.12),
          r.nextDouble() * math.pi * 2,
          between(3, 6),
          between(0.15, 0.4),
        ),
    ];
  }

  Offset at(double t, Size size) => Offset(
    (x +
            ax * math.sin(t * fx * math.pi * 2 + phase) +
            ax * 0.4 * math.sin(t * fx * 2.7 + phase * 2)) *
        size.width,
    (y + ay * math.cos(t * fy * math.pi * 2 + phase)) * size.height,
  );

  /// 0..1, netedă.
  double light(double t) =>
      0.5 + 0.5 * math.sin(t * pulse * math.pi * 2 + phase);
}

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.flies,
    required this.color,
    required this.time,
  }) : super(repaint: time);

  final List<_Firefly> flies;
  final Color color;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final f in flies) {
      final c = f.at(t, size);
      final l = f.light(t);
      final radius = f.size * (2.6 + l);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.55 * (0.35 + 0.65 * l)),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
      canvas.drawCircle(
        c,
        f.size * 0.45,
        Paint()
          ..color = const Color(0xFFFFFBEA).withValues(alpha: 0.6 + 0.4 * l),
      );
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) =>
      old.flies != flies || old.color != color;
}
