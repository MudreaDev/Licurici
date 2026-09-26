import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Explozie scurtă de steluțe (stratul 4 din §15.1). ≤ 12 particule, ~900 ms, fără clipiri.
/// Se redeclanșează când se schimbă [trigger]; nu desenează nimic dacă [enabled] e fals.
class StarBurst extends StatefulWidget {
  const StarBurst({super.key, required this.trigger, this.enabled = true, this.count = 10});

  final int trigger;
  final bool enabled;
  final int count;

  @override
  State<StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<StarBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(StarBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.enabled) {
      final rnd = math.Random();
      _particles = List.generate(widget.count, (i) {
        final angle = (i / widget.count) * 2 * math.pi + rnd.nextDouble() * 0.5;
        return _Particle(angle, 90 + rnd.nextDouble() * 70, 10 + rnd.nextDouble() * 10,
            _palette[i % _palette.length]);
      });
      _c.forward(from: 0);
    }
  }

  static const _palette = [Color(0xFFF2CF6B), Color(0xFF7FC0A3), Color(0xFFA9A3D1), Color(0xFFF0B9A0)];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _c.isAnimating
                ? CustomPaint(
                    size: Size.infinite,
                    painter: _BurstPainter(_particles, Curves.easeOutCubic.transform(_c.value)))
                : const SizedBox.expand(),
          ),
        ),
      );
}

class _Particle {
  const _Particle(this.angle, this.distance, this.size, this.color);
  final double angle;
  final double distance;
  final double size;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final p in particles) {
      final pos = center + Offset(math.cos(p.angle), math.sin(p.angle)) * p.distance * t;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(t * math.pi);
      canvas.drawPath(_star(p.size * (0.6 + 0.4 * fade)), Paint()..color = p.color.withValues(alpha: fade));
      canvas.restore();
    }
  }

  Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(math.cos(a) * radius, math.sin(a) * radius);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
