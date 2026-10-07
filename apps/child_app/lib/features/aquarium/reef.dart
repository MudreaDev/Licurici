import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Recif desenat din cod (rezerva până vin straturile pictate `scenes/aquarium_*`):
/// apă în degrade, stânci și corali în depărtare, nisip cu valuri, corali în față.
/// Toate pozițiile vin din [seed], deci acvariul arată la fel la fiecare deschidere.

/// Linia nisipului la x (fracție din înălțime).
double sandLine(double x, double width) => 0.865 + 0.018 * math.sin(x / width * 5.1 + 1) + 0.01 * math.sin(x / width * 13);

const _waterTop = Color(0xFF8FE0E6);
const _waterMid = Color(0xFF34A7C2);
const _waterDeep = Color(0xFF1C6F9C);
const _waterLow = Color(0xFF2A84A6);

/// Fundalul static (apa, depărtarea, nisipul, corali). Se desenează o dată pe dimensiune.
class ReefBackdropPainter extends CustomPainter {
  const ReefBackdropPainter({this.seed = 7});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = math.Random(seed);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [_waterTop, _waterMid, _waterDeep, _waterLow], [0, 0.28, 0.7, 1]),
    );
    // Lumina de sus, ca un halou moale.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.42, -h * 0.2), h * 1.1, [
          const Color(0x66FFFFFF),
          const Color(0x00FFFFFF),
        ]),
    );

    // Depărtarea: dealuri de stâncă și corali, estompate în albastru.
    for (final (depth, color) in [(0.0, const Color(0x552F7FA6)), (1.0, const Color(0x6629698E))]) {
      final base = h * (0.7 + depth * 0.06);
      final hills = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 40; x += 40) {
        final y = base - h * (0.06 + 0.05 * math.sin(x / w * (4 + depth * 3) + depth * 2 + seed) + 0.03 * math.sin(x / w * 17 + depth));
        hills.lineTo(x, y);
      }
      hills
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(hills, Paint()..color = color);
      for (var i = 0; i < 5; i++) {
        _branchCoral(
          canvas,
          Offset(r.nextDouble() * w, base - h * 0.04),
          h * (0.09 + r.nextDouble() * 0.06),
          color.withValues(alpha: color.a * 1.1),
          r,
          tipColor: null,
        );
      }
    }

    // Nisipul.
    final sand = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 8; x += 8) {
      sand.lineTo(x, h * sandLine(x, w));
    }
    sand
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      sand,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.85), Offset(0, h), [const Color(0xFFF1DCA6), const Color(0xFFDDBB7E)]),
    );
    canvas.save();
    canvas.clipPath(sand);
    // Valurile din nisip și pietricele.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.004
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55FFF6DC);
    for (var i = 0; i < 26; i++) {
      final c = Offset(r.nextDouble() * w, h * (0.9 + r.nextDouble() * 0.1));
      final len = h * (0.05 + r.nextDouble() * 0.08);
      canvas.drawArc(Rect.fromCenter(center: c, width: len, height: len * 0.25), math.pi * 1.1, math.pi * 0.8, false, ripple);
    }
    for (var i = 0; i < 60; i++) {
      final c = Offset(r.nextDouble() * w, h * (0.88 + r.nextDouble() * 0.12));
      final s = h * (0.003 + r.nextDouble() * 0.006);
      final shade = [const Color(0xFFC9A877), const Color(0xFFE9D3A3), const Color(0xFFB79A72), const Color(0xFFF4E6C4)][i % 4];
      canvas.drawOval(Rect.fromCenter(center: c, width: s * 2.4, height: s * 1.5), Paint()..color = shade);
    }
    canvas.restore();

    // Stânci în spate, pe nisip.
    for (final (fx, fw, fh) in [(0.08, 0.2, 0.16), (0.9, 0.24, 0.2), (0.6, 0.12, 0.08)]) {
      _rock(canvas, Offset(w * fx, h * sandLine(w * fx, w) + h * 0.01), h * fw, h * fh, r);
    }

    // Corali în prim-plan, la margini (mijlocul rămâne liber pentru pești).
    _branchCoral(canvas, Offset(w * 0.13, h * 0.9), h * 0.22, const Color(0xFFF07C8C), r, tipColor: const Color(0xFFFFB3BE));
    _branchCoral(canvas, Offset(w * 0.86, h * 0.88), h * 0.2, const Color(0xFFF59A45), r, tipColor: const Color(0xFFFFD39A));
    _tubes(canvas, Offset(w * 0.27, h * 0.92), h, r);
    _brain(canvas, Offset(w * 0.72, h * 0.915), h * 0.075);
    _fan(canvas, Offset(w * 0.035, h * 0.88), h * 0.28, r);
    _starfish(canvas, Offset(w * 0.47, h * 0.95), h * 0.035, 0.3);
    _shell(canvas, Offset(w * 0.6, h * 0.965), h * 0.025);
  }

  @override
  bool shouldRepaint(ReefBackdropPainter old) => old.seed != seed;
}

void _rock(Canvas canvas, Offset base, double width, double height, math.Random r) {
  final p = Path()..moveTo(base.dx - width / 2, base.dy);
  const n = 7;
  for (var i = 0; i <= n; i++) {
    final a = math.pi * (1 - i / n);
    final j = 0.85 + r.nextDouble() * 0.25;
    p.lineTo(base.dx + math.cos(a) * width / 2 * j, base.dy - math.sin(a) * height * j);
  }
  p.close();
  final smooth = _smoothPath(p);
  canvas.drawPath(
    smooth,
    Paint()
      ..shader = ui.Gradient.linear(Offset(base.dx, base.dy - height), base, [const Color(0xFF8DA3A8), const Color(0xFF55707A)]),
  );
  // Mușchi verde pe creștet.
  canvas.save();
  canvas.clipPath(smooth);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(base.dx - width * 0.08, base.dy - height * 0.95), width: width * 0.8, height: height * 0.5),
    Paint()..color = const Color(0x5580B36A),
  );
  canvas.restore();
}

/// Netezește un poligon: curbe prin mijloacele laturilor.
Path _smoothPath(Path poly) {
  final m = poly.computeMetrics().first;
  final pts = <Offset>[];
  for (var d = 0.0; d < m.length; d += m.length / 40) {
    pts.add(m.getTangentForOffset(d)!.position);
  }
  final p = Path();
  final n = pts.length;
  Offset mid(int i) => (pts[i % n] + pts[(i + 1) % n]) / 2;
  p.moveTo(mid(0).dx, mid(0).dy);
  for (var i = 1; i <= n; i++) {
    final c = pts[i % n], e = mid(i);
    p.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
  }
  return p..close();
}

void _branchCoral(Canvas canvas, Offset base, double height, Color color, math.Random r, {Color? tipColor}) {
  final paint = Paint()
    ..color = color
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  void grow(Offset from, double angle, double len, double width, int depth) {
    final to = from + Offset(math.sin(angle), -math.cos(angle)) * len;
    final bend = from + Offset(math.sin(angle + 0.3), -math.cos(angle + 0.3)) * len * 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy),
      paint..strokeWidth = width,
    );
    if (depth == 0) {
      if (tipColor != null) canvas.drawCircle(to, width * 0.55, Paint()..color = tipColor);
      return;
    }
    final kids = 2 + (r.nextDouble() < 0.4 ? 1 : 0);
    for (var k = 0; k < kids; k++) {
      final spread = (k - (kids - 1) / 2) * 0.55 + (r.nextDouble() - 0.5) * 0.3;
      grow(to, angle * 0.6 + spread, len * (0.66 + r.nextDouble() * 0.15), width * 0.72, depth - 1);
    }
  }

  grow(base, (r.nextDouble() - 0.5) * 0.3, height * 0.38, height * 0.1, 3);
}

void _tubes(Canvas canvas, Offset base, double h, math.Random r) {
  for (var i = 0; i < 6; i++) {
    final x = base.dx + (i - 2.5) * h * 0.028 + (r.nextDouble() - 0.5) * h * 0.01;
    final top = base.dy - h * (0.06 + r.nextDouble() * 0.09);
    final w = h * (0.022 + r.nextDouble() * 0.008);
    final rect = RRect.fromRectAndRadius(Rect.fromLTRB(x - w / 2, top, x + w / 2, base.dy), Radius.circular(w * 0.4));
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(x - w / 2, 0), Offset(x + w / 2, 0), [const Color(0xFF9D6BD3), const Color(0xFF6E45A8)]),
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(x, top + w * 0.15), width: w * 0.9, height: w * 0.4), Paint()..color = const Color(0xFF3E2466));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, top + w * 0.15), width: w * 1.05, height: w * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.12
        ..color = const Color(0xFFD2B4F5),
    );
  }
}

void _brain(Canvas canvas, Offset base, double radius) {
  final dome = Rect.fromCenter(center: base, width: radius * 2.6, height: radius * 2);
  final path = Path()..addArc(dome, math.pi, math.pi);
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.radial(base - Offset(radius * 0.4, radius * 0.6), radius * 1.6, [const Color(0xFFF7D77A), const Color(0xFFD9A441)]),
  );
  canvas.save();
  canvas.clipPath(path);
  final groove = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.06
    ..color = const Color(0x66A8741E);
  for (var i = 0; i < 7; i++) {
    final p = Path()..moveTo(base.dx - radius * 1.3, base.dy - radius * (0.15 + i * 0.14));
    for (var x = -1.3; x <= 1.3; x += 0.1) {
      p.lineTo(base.dx + x * radius, base.dy - radius * (0.15 + i * 0.14) + math.sin(x * 9 + i * 2) * radius * 0.05);
    }
    canvas.drawPath(p, groove);
  }
  canvas.restore();
}

void _fan(Canvas canvas, Offset base, double height, math.Random r) {
  final paint = Paint()
    ..color = const Color(0xCCB76FCF)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  void grow(Offset from, double angle, double len, double width, int depth) {
    final to = from + Offset(math.sin(angle), -math.cos(angle)) * len;
    canvas.drawLine(from, to, paint..strokeWidth = width);
    if (depth == 0) return;
    grow(to, angle - 0.32, len * 0.72, width * 0.7, depth - 1);
    grow(to, angle + 0.32, len * 0.72, width * 0.7, depth - 1);
  }

  grow(base, 0.25, height * 0.3, height * 0.025, 5);
}

void _starfish(Canvas canvas, Offset c, double r, double rot) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = rot + i * math.pi / 5 - math.pi / 2;
    final rr = i.isEven ? r : r * 0.45;
    final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.6);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  p.close();
  canvas.drawPath(
    p,
    Paint()
      ..color = const Color(0xFFF2775A)
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.35,
  );
  canvas.drawPath(p, Paint()..color = const Color(0xFFF2775A));
  for (var i = 0; i < 5; i++) {
    final a = rot + i * math.pi * 2 / 5 - math.pi / 2;
    canvas.drawCircle(c + Offset(math.cos(a) * r * 0.5, math.sin(a) * r * 0.3), r * 0.08, Paint()..color = const Color(0xFFFFD0B8));
  }
}

void _shell(Canvas canvas, Offset c, double r) {
  final rect = Rect.fromCenter(center: c, width: r * 2.2, height: r * 1.8);
  final p = Path()
    ..moveTo(c.dx, c.dy + r * 0.8)
    ..arcTo(rect, math.pi * 0.85, math.pi * 1.3, false)
    ..close();
  canvas.drawPath(p, Paint()..color = const Color(0xFFFBE3D6));
  final rib = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.08
    ..color = const Color(0xFFE5B39E);
  for (var i = -2; i <= 2; i++) {
    canvas.drawLine(c + Offset(0, r * 0.8), c + Offset(i * r * 0.42, -r * 0.7 + i.abs() * r * 0.18), rib);
  }
}

/// Ce se mișcă în fundal: razele de lumină, sclipirile de pe nisip, suprafața apei,
/// algele, bulele și particulele care plutesc. Totul lent (≤ 0,5 Hz), fără clipiri.
class ReefAmbiencePainter extends CustomPainter {
  ReefAmbiencePainter(this.time, {this.seed = 7}) : super(repaint: time);

  final ValueListenable<double> time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, w = size.width, h = size.height;
    final r = math.Random(seed);

    // Suprafața: o bandă luminoasă care unduiește.
    final surface = Path()..moveTo(0, 0);
    for (var x = 0.0; x <= w + 10; x += 10) {
      surface.lineTo(x, h * (0.045 + 0.008 * math.sin(x / w * 9 + t * 0.8) + 0.005 * math.sin(x / w * 23 - t * 1.1)));
    }
    surface
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(surface, Paint()..color = const Color(0x55E8FFFF));

    // Razele de lumină.
    canvas.save();
    for (var i = 0; i < 6; i++) {
      final x = w * (0.08 + i * 0.17 + 0.03 * math.sin(t * 0.13 + i));
      final a = 0.5 + 0.5 * math.sin(t * 0.35 + i * 1.9);
      final top = w * (0.035 + 0.02 * (i % 3));
      final ray = Path()
        ..moveTo(x - top, 0)
        ..lineTo(x + top, 0)
        ..lineTo(x + top * 2.2 + h * 0.25, h * 0.85)
        ..lineTo(x - top * 0.4 + h * 0.25, h * 0.85)
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x + h * 0.2, h * 0.85), [
            Color.fromRGBO(255, 255, 255, 0.10 + 0.08 * a),
            const Color(0x00FFFFFF),
          ]),
      );
    }
    canvas.restore();

    // Sclipiri pe nisip (reflexele luminii prin valuri).
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < 16; i++) {
      final x0 = r.nextDouble() * w, len = h * (0.05 + r.nextDouble() * 0.07);
      final x = x0 + math.sin(t * 0.3 + i) * h * 0.03;
      final y = h * (sandLine(x, w) + 0.012 + r.nextDouble() * 0.09);
      final a = (0.5 + 0.5 * math.sin(t * (0.5 + r.nextDouble() * 0.4) + i * 2.3)) * 0.35;
      final p = Path()..moveTo(x, y);
      p.cubicTo(x + len * 0.3, y - len * 0.12, x + len * 0.6, y + len * 0.1, x + len, y - len * 0.04);
      canvas.drawPath(
        p,
        glint
          ..strokeWidth = h * 0.004
          ..color = Color.fromRGBO(255, 255, 230, a),
      );
    }

    // Algele din spate, legănate de curent.
    _seaweed(canvas, size, t, r, count: 9, back: true);

    // Particule care plutesc.
    final dust = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 40; i++) {
      final sx = r.nextDouble(), sy = r.nextDouble(), sp = 0.004 + r.nextDouble() * 0.008;
      final x = (sx * w + math.sin(t * 0.2 + i) * h * 0.02) % w;
      final y = ((sy - t * sp) % 1) * h * 0.85;
      canvas.drawCircle(Offset(x, y), h * (0.0015 + r.nextDouble() * 0.002), dust);
    }

    // Bule din două locuri în nisip.
    for (final (src, n) in [(0.2, 7), (0.79, 9)]) {
      for (var i = 0; i < n; i++) {
        final speed = 0.06 + r.nextDouble() * 0.05;
        final life = ((t * speed + i / n) % 1);
        final y = h * (sandLine(w * src, w) - 0.02) - life * h * 0.85;
        final x = w * src + math.sin(t * 2 + i * 1.7) * h * 0.012 * (0.5 + life);
        final rad = h * (0.006 + 0.006 * r.nextDouble()) * (0.7 + life * 0.6);
        _bubble(canvas, Offset(x, y), rad, life < 0.9 ? 1 : (1 - life) * 10);
      }
    }
  }

  @override
  bool shouldRepaint(ReefAmbiencePainter old) => false;
}

/// Algele din față (peste pești): câteva, la margini, ca acvariul să aibă adâncime.
class ReefFrontPainter extends CustomPainter {
  ReefFrontPainter(this.time, {this.seed = 11}) : super(repaint: time);

  final ValueListenable<double> time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) => _seaweed(canvas, size, time.value, math.Random(seed), count: 4, back: false);

  @override
  bool shouldRepaint(ReefFrontPainter old) => false;
}

void _seaweed(Canvas canvas, Size size, double t, math.Random r, {required int count, required bool back}) {
  final w = size.width, h = size.height;
  for (var i = 0; i < count; i++) {
    // În față doar pe margini; în spate peste tot.
    final fx = back ? r.nextDouble() : (i.isEven ? 0.01 + r.nextDouble() * 0.1 : 0.89 + r.nextDouble() * 0.1);
    final x = w * fx;
    final baseY = h * (sandLine(x, w) + (back ? 0.005 : 0.07));
    final height = h * (back ? 0.25 + r.nextDouble() * 0.3 : 0.35 + r.nextDouble() * 0.2);
    final width = h * (back ? 0.022 : 0.04);
    final phase = r.nextDouble() * 6;
    final color = back
        ? [const Color(0xFF3E9A6A), const Color(0xFF4FAE73), const Color(0xFF2F8A66)][i % 3]
        : [const Color(0xFF2E7D4F), const Color(0xFF3B8F55)][i % 2];
    const segs = 14;
    final left = <Offset>[], right = <Offset>[];
    for (var s = 0; s <= segs; s++) {
      final k = s / segs;
      final sway = math.sin(t * 0.9 + phase + k * 2.4) * h * 0.035 * k * k + math.sin(t * 0.37 + phase) * h * 0.012 * k;
      final cx = x + sway + math.sin(k * 5 + phase) * width * 0.4;
      final y = baseY - height * k;
      final half = width * (1 - k * 0.75) * (0.75 + 0.25 * math.sin(k * 9 + phase));
      left.add(Offset(cx - half, y));
      right.add(Offset(cx + half, y));
    }
    final p = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = ui.Gradient.linear(Offset(x, baseY), Offset(x, baseY - height), [
          Color.lerp(color, const Color(0xFF0E3B33), 0.35)!,
          color,
          Color.lerp(color, const Color(0xFFC8F0A0), 0.25)!,
        ], [0, 0.6, 1]),
    );
    // Nervura din mijloc.
    final vein = Path()..moveTo((left[0].dx + right[0].dx) / 2, left[0].dy);
    for (var s = 1; s <= segs; s++) {
      vein.lineTo((left[s].dx + right[s].dx) / 2, left[s].dy);
    }
    canvas.drawPath(
      vein,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.12
        ..color = const Color(0x33FFFFFF),
    );
  }
}

void _bubble(Canvas canvas, Offset c, double r, double alpha) {
  canvas.drawCircle(c, r, Paint()..color = Color.fromRGBO(220, 250, 255, 0.18 * alpha));
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..color = Color.fromRGBO(255, 255, 255, 0.7 * alpha),
  );
  canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.25, Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * alpha));
}

/// Bule pentru alte straturi (de ex. când mănâncă un pește).
void paintBubble(Canvas canvas, Offset c, double r, double alpha) => _bubble(canvas, c, r, alpha);
