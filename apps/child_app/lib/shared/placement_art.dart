import 'package:flutter/material.dart';
import 'package:licurici_core/licurici_core.dart';

import 'stimulus_art.dart';

/// O mică scenă spațială (LRC6): reperul (masă sau cutie, desenat din cod) și obiectul
/// pictat așezat față de el — pe, sub, în, lângă, deasupra. Reperul stă mereu în același loc,
/// ca variantele să difere doar prin poziția obiectului.
class PlacementArt extends StatelessWidget {
  const PlacementArt(this.placement, {super.key, required this.size});

  final Placement placement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final obj = s * 0.32;
    final box = placement.landmark == Landmark.cutie;
    // Reperul: x 0.16…0.66 (lasă loc în dreapta pentru „lângă”).
    const left = 0.16, right = 0.66;
    const cx = (left + right) / 2;
    final topY = box ? 0.52 : 0.56; // marginea de sus a mesei / gura cutiei
    final (ox, oy) = switch (placement.relation) {
      Relation.pe => (cx, topY - 0.16),
      Relation.sub => (cx, 0.8),
      Relation.inauntru => (cx, topY + 0.1),
      Relation.langa => (0.84, 0.95 - 0.16),
      Relation.deasupra => (cx, 0.17),
    };
    final object = Positioned(
      left: ox * s - obj / 2,
      top: oy * s - obj / 2,
      width: obj,
      height: obj,
      child: StimulusArt(placement.emoji, size: obj),
    );
    return Semantics(
      label: '${placement.relation.word} ${placement.landmark.word}',
      child: SizedBox.square(
        dimension: s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Podeaua.
            Positioned(
              left: 0,
              right: 0,
              top: s * 0.95,
              height: 3,
              child: const ColoredBox(color: Color(0x33A9805F)),
            ),
            if (placement.relation == Relation.deasupra)
              // Liniuțe care arată că plutește (nu stă pe ceva).
              Positioned(
                left: cx * s - obj * 0.35,
                top: 0.17 * s + obj * 0.55,
                width: obj * 0.7,
                height: s * 0.08,
                child: CustomPaint(painter: _FloatLines()),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LandmarkPainter(
                  placement.landmark,
                  left: left,
                  right: right,
                  top: topY,
                  front: false,
                ),
              ),
            ),
            object,
            // Peretele din față al cutiei acoperă obiectul care e „în” ea.
            if (box)
              Positioned.fill(
                child: CustomPaint(
                  painter: _LandmarkPainter(
                    placement.landmark,
                    left: left,
                    right: right,
                    top: topY,
                    front: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter(
    this.landmark, {
    required this.left,
    required this.right,
    required this.top,
    required this.front,
  });

  final Landmark landmark;
  final double left, right, top;
  final bool front;

  static const _wood = Color(0xFFC8935F);
  static const _woodDark = Color(0xFF9C6B3E);
  static const _box = Color(0xFFE9B97A);
  static const _boxDark = Color(0xFFC08A4E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..color = const Color(0xFF6E4A2A);
    if (landmark == Landmark.masa) {
      if (front) return;
      final legW = s * 0.05;
      for (final x in [left + 0.04, right - 0.04 - 0.05]) {
        final leg = Rect.fromLTWH(x * s, top * s, legW, (0.95 - top) * s);
        canvas.drawRect(leg, Paint()..color = _woodDark);
        canvas.drawRect(leg, outline);
      }
      final board = RRect.fromRectAndRadius(
        Rect.fromLTRB(left * s, top * s, right * s, (top + 0.07) * s),
        Radius.circular(s * 0.02),
      );
      canvas.drawRRect(board, Paint()..color = _wood);
      canvas.drawRRect(board, outline);
      return;
    }
    // Cutia: interiorul (spate) se desenează înaintea obiectului, peretele din față după.
    final body = Rect.fromLTRB(left * s, top * s, right * s, 0.95 * s);
    if (!front) {
      canvas.drawRect(
        Rect.fromLTRB(
          body.left,
          body.top - s * 0.06,
          body.right,
          body.top + s * 0.06,
        ),
        Paint()..color = _boxDark,
      );
      // Clapele deschise.
      final flap = Paint()..color = _box;
      canvas.drawPath(
        Path()
          ..moveTo(body.left, body.top)
          ..lineTo(body.left - s * 0.08, body.top - s * 0.1)
          ..lineTo(body.left + s * 0.1, body.top - s * 0.1)
          ..lineTo(body.left + s * 0.12, body.top)
          ..close(),
        flap,
      );
      canvas.drawPath(
        Path()
          ..moveTo(body.right, body.top)
          ..lineTo(body.right + s * 0.08, body.top - s * 0.1)
          ..lineTo(body.right - s * 0.1, body.top - s * 0.1)
          ..lineTo(body.right - s * 0.12, body.top)
          ..close(),
        flap,
      );
      return;
    }
    final wall = Rect.fromLTRB(
      body.left,
      body.top + s * 0.05,
      body.right,
      body.bottom,
    );
    canvas.drawRect(wall, Paint()..color = _box);
    canvas.drawRect(wall, outline);
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.landmark != landmark || old.front != front || old.top != top;
}

class _FloatLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x667A8296)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in [0.2, 0.5, 0.8]) {
      canvas.drawLine(
        Offset(x * size.width, 0),
        Offset(x * size.width, size.height),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_FloatLines old) => false;
}
