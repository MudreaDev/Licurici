import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mascot_layers.dart';
import 'motion.dart';

export 'mascot_layers.dart' show MascotMood, MascotRig;

/// Licurici, mascota (ADR-028). Din ilustrațiile generate, pe straturi animate din cod
/// (`LayeredMascot`); până se încarcă ele (sau dacă lipsesc) — desenată în cod.
///
/// Animații: plutire + aripi care bat + burtica-felinar care pulsează + clipit (idle, doar la
/// motion `full`); săritură și strălucire la `happy`; înclinare blândă la `encourage`/`think`.
/// Schimbă [reaction] (ex. un contor) ca să redeclanșezi aceeași stare.
class Mascot extends ConsumerStatefulWidget {
  const Mascot({
    super.key,
    this.size = 120,
    this.mood = MascotMood.idle,
    this.reaction = 0,
  });

  final double size;
  final MascotMood mood;
  final int reaction;

  @override
  ConsumerState<Mascot> createState() => _MascotState();
}

class _MascotState extends ConsumerState<Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _images = false;

  @override
  void initState() {
    super.initState();
    MascotRig.available().then((ok) {
      if (mounted && ok) setState(() => _images = true);
    });
  }

  @override
  void didUpdateWidget(Mascot old) {
    super.didUpdateWidget(old);
    if (old.reaction != widget.reaction || old.mood != widget.mood) {
      if (widget.mood != MascotMood.idle) _react.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    for (final c in [_idle, _blink]) {
      if (motion.ambient && !c.isAnimating) {
        c.repeat();
      } else if (!motion.ambient && c.isAnimating) {
        c.stop();
      }
    }
    return RepaintBoundary(
      child: Semantics(
        label: 'Licurici',
        image: true,
        child: SizedBox.square(
          dimension: widget.size,
          child: _images
              ? LayeredMascot(
                  size: widget.size,
                  mood: widget.mood,
                  motion: motion,
                  idle: _idle,
                  react: _react,
                  blink: _blink,
                )
              : AnimatedBuilder(
                  animation: Listenable.merge([_idle, _react]),
                  builder: (context, _) {
                    final t = _idle.value * 2 * math.pi;
                    final r = motion.movement
                        ? Curves.easeOut.transform(_react.value)
                        : 0.0;
                    final bump = math.sin(r * math.pi); // 0 → 1 → 0
                    final happy = widget.mood == MascotMood.happy;
                    final dy =
                        math.sin(t) * 4 -
                        (happy ? bump * widget.size * 0.18 : 0);
                    final tilt = widget.mood == MascotMood.encourage
                        ? math.sin(r * math.pi * 2) * 0.12
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.rotate(
                        angle: tilt,
                        child: CustomPaint(
                          painter: _FireflyPainter(
                            wing: math.sin(t * 3) * 0.12,
                            glow:
                                0.75 +
                                math.sin(t) * 0.15 +
                                (happy ? bump * 0.5 : 0),
                            smile: happy ? 1 + bump : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  _FireflyPainter({
    required this.wing,
    required this.glow,
    required this.smile,
  });

  final double wing;
  final double glow;
  final double smile;

  static const _body = Color(0xFF6F9A6B);
  static const _head = Color(0xFF7BA676);
  static const _eye = Color(0xFF3A3A3A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    // strălucirea cozii
    final glowR = 34 * glow.clamp(0.5, 1.4);
    canvas.drawCircle(
      const Offset(50, 70),
      glowR,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xFFFFF6C2), Color(0xFFF6DF84), Color(0x00F6DF84)],
              stops: [0, 0.45, 1],
            ).createShader(
              Rect.fromCircle(center: const Offset(50, 70), radius: glowR),
            ),
    );

    // aripioare (bat ușor)
    final wingPaint = Paint()..color = const Color(0xD9EAF1FF);
    for (final (cx, base) in [(34.0, -0.31), (66.0, 0.31)]) {
      canvas.save();
      canvas.translate(cx, 46);
      canvas.rotate(base + (cx < 50 ? -wing : wing));
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 36, height: 24),
        wingPaint,
      );
      canvas.restore();
    }

    // antene
    final stroke = Paint()
      ..color = _body
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(44, 30)
        ..quadraticBezierTo(40, 20, 34, 17),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(56, 30)
        ..quadraticBezierTo(60, 20, 66, 17),
      stroke,
    );
    canvas.drawCircle(const Offset(33, 16), 3.4, Paint()..color = _body);
    canvas.drawCircle(const Offset(67, 16), 3.4, Paint()..color = _body);

    // corp + cap
    const bodyRect = Rect.fromLTRB(32, 32, 68, 76);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FB389), _body],
        ).createShader(bodyRect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 38), width: 30, height: 26),
      Paint()..color = _head,
    );

    // ochi
    for (final x in [44.0, 56.0]) {
      canvas.drawCircle(Offset(x, 37), 5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x + 1, 38), 2.4, Paint()..color = _eye);
    }

    // zâmbet (mai larg când e fericit)
    canvas.drawPath(
      Path()
        ..moveTo(45, 45)
        ..quadraticBezierTo(50, 45 + 4 * smile, 55, 45),
      Paint()
        ..color = _eye
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // coada strălucitoare
    canvas.drawCircle(
      const Offset(50, 70),
      9,
      Paint()
        ..color = const Color(0xFFFFF3AD)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawCircle(
      const Offset(50, 70),
      6,
      Paint()..color = const Color(0xFFFFFBE0),
    );
  }

  @override
  bool shouldRepaint(_FireflyPainter old) =>
      old.wing != wing || old.glow != glow || old.smile != smile;
}
