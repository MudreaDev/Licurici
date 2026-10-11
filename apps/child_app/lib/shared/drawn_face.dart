import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:licurici_core/licurici_core.dart';

/// O față desenată din cod ([FaceSpec], `licurici_core/face.dart`): același stil cald, rotund,
/// ca personajele pictate, dar cu oricâte identități (ten, păr, coafură, ochi, accesorii) și cu
/// emoția la orice intensitate. Fără text, fără detalii care să distragă: doar ce poartă emoția
/// (ochii, sprâncenele, gura, obrajii).
class DrawnFace extends StatelessWidget {
  const DrawnFace(this.spec, {super.key, required this.size, this.semanticLabel});

  final FaceSpec spec;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel ?? 'o față',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: FacePainter(spec)),
      );
}

const _skins = [Color(0xFFF7D7C4), Color(0xFFEFC09E), Color(0xFFD9A07A), Color(0xFFB0774F), Color(0xFF7E5236)];
const _hairs = [Color(0xFF3B2A20), Color(0xFF6B4226), Color(0xFFB9783F), Color(0xFFE2C27A), Color(0xFF1F1B1A), Color(0xFFA54B2A)];
const _irises = [Color(0xFF5A3A22), Color(0xFF3E6D8C), Color(0xFF4F7A45), Color(0xFF2E2A28)];
const _ink = Color(0xFF3A2C28);
const _hats = [Color(0xFF4FA383), Color(0xFF7B6FC2), Color(0xFFE07A5F), Color(0xFF3F7D96), Color(0xFFE0A93B), Color(0xFFD45D79)];

class FacePainter extends CustomPainter {
  FacePainter(this.spec);

  final FaceSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final look = spec.look;
    final shape = spec.shape;
    final skin = _skins[look.skin % _skins.length];
    final hair = _hairs[look.hair % _hairs.length];
    final c = Offset(s * 0.5, s * 0.54);
    final r = s * 0.38;
    Paint fill(Color color) => Paint()..color = color..isAntiAlias = true;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.028
      ..isAntiAlias = true;

    // Părul din spate (lung, codițe).
    if (look.hairStyle == 1) {
      canvas.drawRRect(
        // Cade pe lângă obraji și se termină în spatele bărbiei (altfel ar părea barbă).
        RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -r * 0.05), width: r * 2.32, height: r * 1.9), Radius.circular(r * 0.9)),
        fill(hair),
      );
    } else if (look.hairStyle == 2) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(side * r * 1.08, r * 0.35), width: r * 0.55, height: r * 0.95), fill(hair));
      }
    }
    // Urechile.
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(c.translate(side * r * 0.98, r * 0.05), r * 0.2, fill(skin));
    }
    // Capul.
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 2.08), fill(skin));
    // Părul de deasupra / căciula.
    _hair(canvas, look.hairStyle, c, r, hair, look);

    // Obrajii (bucurie): rumeni.
    if (shape.blush > 0.05) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: c.translate(side * r * 0.55, r * 0.32), width: r * 0.34, height: r * 0.2),
          fill(const Color(0xFFF08A8A).withValues(alpha: 0.45 * shape.blush)),
        );
      }
    }
    // Pistrui.
    if (look.accessory == 3) {
      final freckle = fill(const Color(0xFFB0774F).withValues(alpha: 0.55));
      for (final side in [-1.0, 1.0]) {
        for (final (dx, dy) in const [(0.42, 0.18), (0.55, 0.24), (0.48, 0.3)]) {
          canvas.drawCircle(c.translate(side * r * dx, r * dy), r * 0.03, freckle);
        }
      }
    }

    // Ochii: deschiderea vine din emoție; irisul din identitate.
    final eyeY = c.dy + r * 0.02;
    final eyeDx = r * 0.37;
    final eyeW = r * 0.36, eyeH = r * 0.34 * shape.eyeOpen;
    for (final side in [-1.0, 1.0]) {
      final e = Offset(c.dx + side * eyeDx, eyeY);
      canvas.drawOval(Rect.fromCenter(center: e, width: eyeW, height: math.max(eyeH, r * 0.05)), fill(const Color(0xFFFFFFFF)));
      final iris = math.min(eyeW, math.max(eyeH, r * 0.12)) * 0.62;
      canvas.drawCircle(e, iris / 2, fill(_irises[look.eyes % _irises.length]));
      // Pupila se strânge de frică.
      final pupil = iris * (shape.eyeOpen > 1.15 ? 0.32 : 0.45);
      canvas.drawCircle(e, pupil / 2, fill(_ink));
      canvas.drawCircle(e.translate(-iris * 0.18, -iris * 0.18), iris * 0.12, fill(const Color(0xFFFFFFFF)));
      // Pleoapa de sus (îngroșată ca un contur).
      canvas.drawArc(Rect.fromCenter(center: e, width: eyeW, height: math.max(eyeH, r * 0.05)), math.pi * 1.05, math.pi * 0.9, false,
          line..strokeWidth = s * 0.018);
    }
    line.strokeWidth = s * 0.028;

    // Ochelarii.
    if (look.accessory == 1) {
      final g = Paint()
        ..color = const Color(0xFF3F7D96)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02;
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(c.dx + side * eyeDx, eyeY), r * 0.27, g);
      }
      canvas.drawLine(Offset(c.dx - eyeDx + r * 0.27, eyeY), Offset(c.dx + eyeDx - r * 0.27, eyeY), g);
    }

    // Sprâncenele: înclinarea (tristețe ↑ spre nas, furie ↓) și înălțimea.
    final browY = eyeY - eyeH / 2 - r * (0.16 + 0.22 * shape.browLift);
    for (final side in [-1.0, 1.0]) {
      final inner = Offset(c.dx + side * r * 0.16, browY - r * 0.22 * shape.browTilt);
      final outer = Offset(c.dx + side * r * 0.58, browY + r * 0.08 * shape.browTilt);
      canvas.drawLine(inner, outer, Paint()
        ..color = Color.lerp(hair, _ink, 0.55)!
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round);
    }

    // Gura: curbura (zâmbet / colțuri în jos), deschiderea și lățimea.
    final mouthY = c.dy + r * 0.55;
    final half = r * shape.mouthWidth * 0.85;
    final curve = shape.mouthCurve * r * 0.34;
    final open = shape.mouthOpen * r * 0.5;
    line.strokeWidth = s * 0.034;
    final left = Offset(c.dx - half, mouthY - curve * 0.4);
    final right = Offset(c.dx + half, mouthY - curve * 0.4);
    if (open < r * 0.03) {
      final p = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(c.dx, mouthY + curve, right.dx, right.dy);
      canvas.drawPath(p, line);
    } else {
      final top = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(c.dx, mouthY + curve * 0.6 - open * 0.3, right.dx, right.dy)
        ..quadraticBezierTo(c.dx, mouthY + curve + open, left.dx, left.dy)
        ..close();
      canvas.drawPath(top, fill(const Color(0xFF7A2E2E)));
      // Limba, la gura larg deschisă.
      if (shape.mouthOpen > 0.45) {
        canvas.save();
        canvas.clipPath(top);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, mouthY + curve * 0.8 + open * 0.75), width: half * 1.1, height: open * 0.7),
            fill(const Color(0xFFE48A8A)));
        canvas.restore();
      }
      canvas.drawPath(top, line..strokeWidth = s * 0.02);
    }

    // Lacrima (tristețe clară).
    if (shape.tear > 0) {
      final t = Offset(c.dx + eyeDx + eyeW * 0.2, eyeY + eyeH * 0.6 + r * 0.12);
      final drop = Path()
        ..moveTo(t.dx, t.dy - r * 0.12)
        ..quadraticBezierTo(t.dx + r * 0.08, t.dy, t.dx, t.dy + r * 0.06)
        ..quadraticBezierTo(t.dx - r * 0.08, t.dy, t.dx, t.dy - r * 0.12);
      canvas.drawPath(drop, fill(const Color(0xFF7FC3E8)));
    }
    canvas.restore();
  }

  void _hair(Canvas canvas, int style, Offset c, double r, Color hair, FaceLook look) {
    final paint = Paint()..color = hair..isAntiAlias = true;
    switch (style) {
      case 3: // creț: bucle pe creștet
        for (var i = 0; i < 9; i++) {
          final a = math.pi * (1.05 + 0.9 * i / 8);
          canvas.drawCircle(c + Offset(math.cos(a) * r * 0.92, math.sin(a) * r * 0.92), r * 0.26, paint);
        }
      case 4: // căciulă
        final hat = Paint()..color = _hats[look.hair % _hats.length];
        canvas.drawArc(Rect.fromCenter(center: c.translate(0, -r * 0.1), width: r * 2.1, height: r * 2.0), math.pi, math.pi, true, hat);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -r * 0.12), width: r * 2.2, height: r * 0.3), Radius.circular(r * 0.15)),
            Paint()..color = Color.lerp(hat.color, const Color(0xFFFFFFFF), 0.35)!);
        canvas.drawCircle(c.translate(0, -r * 1.12), r * 0.16, Paint()..color = const Color(0xFFFFFFFF));
      default: // scurt, lung, codițe: calota de păr peste creștet, cu breton în valuri
        final top = Rect.fromCenter(center: c, width: r * 2.12, height: r * 2.18);
        final cap = Path()
          ..moveTo(c.dx - r * 1.06, c.dy - r * 0.05)
          ..arcTo(top, math.pi, math.pi, false)
          ..lineTo(c.dx + r * 0.98, c.dy - r * 0.32);
        // Bretonul: patru valuri de la dreapta la stânga, deasupra sprâncenelor.
        const waves = 4;
        for (var i = 0; i < waves; i++) {
          final x0 = c.dx + r * 0.98 - (i + 1) * r * 1.96 / waves;
          final xm = x0 + r * 1.96 / waves / 2;
          cap.quadraticBezierTo(xm, c.dy - r * (0.32 + (i.isEven ? 0.08 : 0.16)), x0, c.dy - r * (i == waves - 1 ? 0.32 : 0.5));
        }
        cap.close();
        canvas.drawPath(cap, paint);
    }
    // Bentița.
    if (look.accessory == 2 && style != 4) {
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -r * 0.05), width: r * 1.95, height: r * 1.9), math.pi * 1.12, math.pi * 0.76, false,
          Paint()
            ..color = const Color(0xFFE48A8A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(FacePainter old) => old.spec.art != spec.art;
}
