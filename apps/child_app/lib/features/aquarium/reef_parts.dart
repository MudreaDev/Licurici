import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Piesele recifului, desenate cu volum (lumina vine de sus, puțin din stânga):
/// stânci, corali, bureți, scoici. Fiecare primește `fog` ∈ [0, 1] — cât de departe e
/// (se pierde în albastrul apei). Toate dimensiunile sunt în pixeli.

const reefFog = Color(0xFF2E86AE);

Color fogged(Color c, double fog) => Color.lerp(c, reefFog, fog.clamp(0.0, 1.0))!;

Color lighten(Color c, double k) => Color.lerp(c, const Color(0xFFFFFFFF), k)!;
Color darken(Color c, double k) => Color.lerp(c, const Color(0xFF0A1E2A), k)!;

/// Netezește un poligon închis: curbe prin mijloacele laturilor.
Path smoothClosed(List<Offset> pts) {
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

/// O stâncă așezată pe fund: contur rotunjit cu umflături, partea de jos dreaptă.
Path rockShape(Offset base, double width, double height, math.Random r, {int bumps = 9, double rough = 0.22}) {
  final pts = <Offset>[Offset(base.dx + width * 0.52, base.dy + height * 0.06)];
  for (var i = 0; i <= bumps; i++) {
    final a = i / bumps; // 0 = dreapta, 1 = stânga
    final ang = math.pi * a;
    final j = 1 - rough / 2 + r.nextDouble() * rough;
    // Mai înaltă spre mijloc, cu umeri rotunzi.
    final y = math.pow(math.sin(ang), 0.7) * height * j;
    pts.add(Offset(base.dx + math.cos(ang) * width / 2 * (0.9 + 0.12 * r.nextDouble()), base.dy - y));
  }
  pts.add(Offset(base.dx - width * 0.52, base.dy + height * 0.06));
  return smoothClosed(pts);
}

/// Stânca cu volum: lumină sus, umbră jos, muchie luminată, pori, mușchi.
void paintRock(Canvas canvas, Path shape, math.Random r, {double fog = 0, Color tone = const Color(0xFF7D93A0), bool moss = true}) {
  final b = shape.getBounds();
  canvas.drawPath(
    shape,
    Paint()
      ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
        fogged(lighten(tone, 0.18), fog),
        fogged(tone, fog),
        fogged(darken(tone, 0.45), fog),
      ], [0, 0.45, 1]),
  );
  canvas.save();
  canvas.clipPath(shape);
  // Umbra din dreapta-jos (lumina vine din stânga-sus).
  canvas.drawOval(
    Rect.fromCenter(center: b.bottomRight + Offset(-b.width * 0.1, 0), width: b.width * 1.1, height: b.height * 1.3),
    Paint()
      ..shader = ui.Gradient.radial(b.bottomRight, b.width * 0.6, [
        fogged(darken(tone, 0.5), fog).withValues(alpha: 0.6),
        const Color(0x00000000),
      ]),
  );
  // Pori și adâncituri: o pată închisă cu o buză luminată jos.
  for (var i = 0; i < (b.width * b.height / 900).clamp(4, 30); i++) {
    final c = Offset(b.left + r.nextDouble() * b.width, b.top + b.height * (0.25 + r.nextDouble() * 0.7));
    final s = b.height * (0.02 + r.nextDouble() * 0.05);
    canvas.drawOval(Rect.fromCenter(center: c, width: s * 1.8, height: s), Paint()..color = fogged(darken(tone, 0.35), fog).withValues(alpha: 0.55));
    canvas.drawArc(
      Rect.fromCenter(center: c + Offset(0, s * 0.2), width: s * 1.8, height: s),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.25
        ..color = fogged(lighten(tone, 0.3), fog).withValues(alpha: 0.5),
    );
  }
  // Mușchi și alge pe creștet (unde bate lumina).
  if (moss) {
    for (var i = 0; i < 5; i++) {
      final c = Offset(b.left + b.width * (0.15 + r.nextDouble() * 0.7), b.top + b.height * (0.02 + r.nextDouble() * 0.15));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: b.width * (0.2 + r.nextDouble() * 0.25), height: b.height * 0.16),
        Paint()..color = fogged(const Color(0xFF6FAF5E), fog).withValues(alpha: 0.45),
      );
    }
  }
  // Muchia de sus, luminată.
  canvas.drawPath(
    shape.shift(Offset(b.width * 0.012, b.height * 0.03)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = b.height * 0.05
      ..color = fogged(lighten(tone, 0.5), fog).withValues(alpha: 0.5),
  );
  canvas.restore();
}

/// Umbra moale de contact de sub un obiect, pe nisip.
void paintContactShadow(Canvas canvas, Offset c, double width, {double alpha = 0.32}) {
  canvas.drawOval(
    Rect.fromCenter(center: c, width: width, height: width * 0.16),
    Paint()..shader = ui.Gradient.radial(c, width / 2, [Color.fromRGBO(18, 40, 50, alpha), const Color(0x00122832)]),
  );
}

/// Coral ramificat cu ramuri „tubulare”: umbră, culoare, luciu, vârfuri deschise.
void paintBranchCoral(
  Canvas canvas,
  Offset base,
  double height,
  Color color,
  math.Random r, {
  double fog = 0,
  int depth = 3,
  double spread = 0.55,
}) {
  final segs = <(Offset, Offset, Offset, double, bool)>[];
  void grow(Offset from, double angle, double len, double width, int d) {
    final to = from + Offset(math.sin(angle), -math.cos(angle)) * len;
    final bend = from + Offset(math.sin(angle + 0.25), -math.cos(angle + 0.25)) * len * 0.5;
    segs.add((from, bend, to, width, d == 0));
    if (d == 0) return;
    final kids = 2 + (r.nextDouble() < 0.45 ? 1 : 0);
    for (var k = 0; k < kids; k++) {
      final s = (k - (kids - 1) / 2) * spread + (r.nextDouble() - 0.5) * 0.3;
      grow(to, angle * 0.55 + s, len * (0.66 + r.nextDouble() * 0.16), width * 0.72, d - 1);
    }
  }

  grow(base, (r.nextDouble() - 0.5) * 0.3, height * 0.36, height * 0.1, depth);
  Path seg((Offset, Offset, Offset, double, bool) s, Offset o) => Path()
    ..moveTo(s.$1.dx + o.dx, s.$1.dy + o.dy)
    ..quadraticBezierTo(s.$2.dx + o.dx, s.$2.dy + o.dy, s.$3.dx + o.dx, s.$3.dy + o.dy);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final dark = fogged(darken(color, 0.35), fog), mid = fogged(color, fog), light = fogged(lighten(color, 0.4), fog);
  for (final s in segs) {
    canvas.drawPath(seg(s, Offset.zero), stroke
      ..strokeWidth = s.$4
      ..color = dark);
  }
  for (final s in segs) {
    canvas.drawPath(seg(s, Offset(-s.$4 * 0.12, -s.$4 * 0.08)), stroke
      ..strokeWidth = s.$4 * 0.7
      ..color = mid);
  }
  for (final s in segs) {
    canvas.drawPath(seg(s, Offset(-s.$4 * 0.22, -s.$4 * 0.1)), stroke
      ..strokeWidth = s.$4 * 0.22
      ..color = light.withValues(alpha: 0.7));
    if (s.$5) {
      canvas.drawCircle(s.$3, s.$4 * 0.62, Paint()..color = light);
      canvas.drawCircle(s.$3 + Offset(-s.$4 * 0.15, -s.$4 * 0.15), s.$4 * 0.25, Paint()..color = const Color(0xAAFFFFFF));
    }
  }
}

/// Coral-creier: cupolă cu șanțuri șerpuite.
void paintBrainCoral(Canvas canvas, Offset base, double radius, {double fog = 0, Color color = const Color(0xFFF2C65C)}) {
  final dome = Rect.fromCenter(center: base, width: radius * 2.6, height: radius * 2.1);
  final path = Path()
    ..addArc(dome, math.pi, math.pi)
    ..close();
  paintContactShadow(canvas, base + Offset(0, radius * 0.05), radius * 3.2);
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.radial(base - Offset(radius * 0.5, radius * 0.75), radius * 1.9, [
        fogged(lighten(color, 0.35), fog),
        fogged(color, fog),
        fogged(darken(color, 0.4), fog),
      ], [0, 0.45, 1]),
  );
  canvas.save();
  canvas.clipPath(path);
  final groove = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.07
    ..strokeCap = StrokeCap.round
    ..color = fogged(darken(color, 0.4), fog).withValues(alpha: 0.65);
  final ridge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.035
    ..strokeCap = StrokeCap.round
    ..color = fogged(lighten(color, 0.45), fog).withValues(alpha: 0.6);
  for (var i = 0; i < 8; i++) {
    final yk = 0.1 + i * 0.12;
    final g = Path(), l = Path();
    for (var x = -1.35; x <= 1.35; x += 0.06) {
      // Șanțurile urmează curbura cupolei.
      final curve = math.sqrt(math.max(0, 1 - (x / 1.35) * (x / 1.35)));
      final y = base.dy - radius * yk * 1.05 * (0.4 + 0.6 * curve) * (1 + 0.1 * i) + math.sin(x * 10 + i * 2.1) * radius * 0.05;
      final px = base.dx + x * radius;
      x == -1.35 ? g.moveTo(px, y) : g.lineTo(px, y);
      x == -1.35 ? l.moveTo(px, y - radius * 0.045) : l.lineTo(px, y - radius * 0.045);
    }
    canvas.drawPath(l, ridge);
    canvas.drawPath(g, groove);
  }
  canvas.restore();
}

/// Bureți-tub: cilindri cu gura întunecată și buza luminată.
void paintTubes(Canvas canvas, Offset base, double h, math.Random r, {double fog = 0, Color color = const Color(0xFF9D6BD3), int count = 6}) {
  paintContactShadow(canvas, base + Offset(0, h * 0.005), h * count * 0.035);
  for (var i = 0; i < count; i++) {
    final x = base.dx + (i - (count - 1) / 2) * h * 0.028 + (r.nextDouble() - 0.5) * h * 0.01;
    final top = base.dy - h * (0.06 + r.nextDouble() * 0.1);
    final w = h * (0.022 + r.nextDouble() * 0.009);
    final rect = RRect.fromRectAndRadius(Rect.fromLTRB(x - w / 2, top, x + w / 2, base.dy), Radius.circular(w * 0.4));
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(x - w / 2, 0), Offset(x + w / 2, 0), [
          fogged(lighten(color, 0.25), fog),
          fogged(color, fog),
          fogged(darken(color, 0.4), fog),
        ], [0, 0.4, 1]),
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(x, top + w * 0.15), width: w * 0.9, height: w * 0.4), Paint()..color = fogged(darken(color, 0.65), fog));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, top + w * 0.15), width: w * 1.05, height: w * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..color = fogged(lighten(color, 0.55), fog),
    );
  }
}

/// Evantai de mare: rețea de ramuri fine, puțin transparentă.
void paintFan(Canvas canvas, Offset base, double height, math.Random r, {double fog = 0, Color color = const Color(0xFFB76FCF), double lean = 0.2}) {
  final paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final tips = <Offset>[];
  void grow(Offset from, double angle, double len, double width, int depth) {
    final to = from + Offset(math.sin(angle), -math.cos(angle)) * len;
    canvas.drawLine(from, to, paint
      ..strokeWidth = width
      ..color = fogged(color, fog).withValues(alpha: 0.85));
    if (depth == 0) {
      tips.add(to);
      return;
    }
    grow(to, angle - 0.3 - r.nextDouble() * 0.1, len * 0.74, width * 0.72, depth - 1);
    grow(to, angle + 0.3 + r.nextDouble() * 0.1, len * 0.74, width * 0.72, depth - 1);
  }

  grow(base, lean, height * 0.3, height * 0.028, 5);
  // Pânza dintre ramuri.
  if (tips.length > 2) {
    tips.sort((a, b) => math.atan2(a.dy - base.dy, a.dx - base.dx).compareTo(math.atan2(b.dy - base.dy, b.dx - base.dx)));
    final web = Path()..moveTo(base.dx, base.dy);
    for (final t in tips) {
      web.lineTo(t.dx, t.dy);
    }
    web.close();
    canvas.drawPath(web, Paint()..color = fogged(color, fog).withValues(alpha: 0.2));
  }
}

/// Coral moale, ca o tufă: bulgări rotunzi luminați de sus.
void paintSoftCoral(Canvas canvas, Offset base, double size, math.Random r, {double fog = 0, Color color = const Color(0xFFE86FA0)}) {
  paintContactShadow(canvas, base, size * 1.3);
  final blobs = <(Offset, double)>[];
  for (var i = 0; i < 14; i++) {
    final a = -math.pi * (0.1 + 0.8 * r.nextDouble());
    final d = size * (0.15 + 0.4 * r.nextDouble());
    blobs.add((base + Offset(math.cos(a) * d * 1.1, math.sin(a) * d - size * 0.15), size * (0.14 + r.nextDouble() * 0.1)));
  }
  blobs.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
  // Tulpina.
  canvas.drawPath(
    Path()
      ..moveTo(base.dx - size * 0.1, base.dy)
      ..quadraticBezierTo(base.dx, base.dy - size * 0.3, base.dx + size * 0.1, base.dy)
      ..close(),
    Paint()..color = fogged(darken(color, 0.3), fog),
  );
  for (final (c, rad) in blobs.reversed) {
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..shader = ui.Gradient.radial(c - Offset(rad * 0.35, rad * 0.45), rad * 1.3, [
          fogged(lighten(color, 0.45), fog),
          fogged(color, fog),
          fogged(darken(color, 0.35), fog),
        ], [0, 0.5, 1]),
    );
    // Polipii: puncte mici deschise.
    for (var k = 0; k < 3; k++) {
      final p = c + Offset((r.nextDouble() - 0.5) * rad, (r.nextDouble() - 0.7) * rad);
      canvas.drawCircle(p, rad * 0.09, Paint()..color = fogged(lighten(color, 0.7), fog).withValues(alpha: 0.8));
    }
  }
}

/// Coral-masă: o farfurie lată pe un picior.
void paintTableCoral(Canvas canvas, Offset base, double width, {double fog = 0, Color color = const Color(0xFF63C2A6)}) {
  final top = base.dy - width * 0.42;
  canvas.drawPath(
    Path()
      ..moveTo(base.dx - width * 0.08, base.dy)
      ..quadraticBezierTo(base.dx - width * 0.03, top + width * 0.1, base.dx - width * 0.06, top)
      ..lineTo(base.dx + width * 0.06, top)
      ..quadraticBezierTo(base.dx + width * 0.03, top + width * 0.1, base.dx + width * 0.08, base.dy)
      ..close(),
    Paint()..color = fogged(darken(color, 0.35), fog),
  );
  final plate = Rect.fromCenter(center: Offset(base.dx, top), width: width, height: width * 0.22);
  // Dedesubtul farfuriei, în umbră.
  canvas.drawOval(plate.shift(Offset(0, width * 0.035)), Paint()..color = fogged(darken(color, 0.5), fog));
  canvas.drawOval(
    plate,
    Paint()
      ..shader = ui.Gradient.radial(plate.center - Offset(width * 0.15, width * 0.04), width * 0.6, [
        fogged(lighten(color, 0.4), fog),
        fogged(color, fog),
      ]),
  );
  final dots = Paint()..color = fogged(lighten(color, 0.6), fog).withValues(alpha: 0.7);
  for (var i = 0; i < 18; i++) {
    final a = i * 2.4;
    final rr = 0.15 + (i % 5) * 0.08;
    canvas.drawCircle(plate.center + Offset(math.cos(a) * width * rr, math.sin(a) * width * rr * 0.2), width * 0.012, dots);
  }
}

/// Steluță de mare.
void paintStarfish(Canvas canvas, Offset c, double r, double rot, {Color color = const Color(0xFFF2775A), double fog = 0}) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = rot + i * math.pi / 5 - math.pi / 2;
    final rr = i.isEven ? r : r * 0.42;
    final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.55);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  p.close();
  paintContactShadow(canvas, c + Offset(0, r * 0.15), r * 2.4, alpha: 0.25);
  final col = fogged(color, fog);
  canvas.drawPath(
    p,
    Paint()
      ..color = col
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.35,
  );
  canvas.drawPath(
    p,
    Paint()
      ..shader = ui.Gradient.radial(c - Offset(r * 0.2, r * 0.25), r, [lighten(col, 0.3), col, darken(col, 0.25)], [0, 0.5, 1]),
  );
  for (var i = 0; i < 5; i++) {
    final a = rot + i * math.pi * 2 / 5 - math.pi / 2;
    for (final k in [0.25, 0.5, 0.72]) {
      canvas.drawCircle(c + Offset(math.cos(a) * r * k, math.sin(a) * r * k * 0.55), r * 0.06, Paint()..color = lighten(col, 0.55));
    }
  }
}

/// Scoică în evantai.
void paintShell(Canvas canvas, Offset c, double r, {double fog = 0, Color color = const Color(0xFFFBE3D6)}) {
  paintContactShadow(canvas, c + Offset(0, r * 0.75), r * 2.4, alpha: 0.25);
  final rect = Rect.fromCenter(center: c, width: r * 2.2, height: r * 1.8);
  final p = Path()
    ..moveTo(c.dx, c.dy + r * 0.8)
    ..arcTo(rect, math.pi * 0.85, math.pi * 1.3, false)
    ..close();
  final col = fogged(color, fog);
  canvas.drawPath(p, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [lighten(col, 0.3), col, darken(col, 0.2)], [0, 0.5, 1]));
  final rib = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.09
    ..strokeCap = StrokeCap.round
    ..color = darken(col, 0.18);
  for (var i = -3; i <= 3; i++) {
    canvas.drawLine(c + Offset(0, r * 0.8), c + Offset(i * r * 0.3, -r * 0.72 + i.abs() * r * 0.12), rib);
  }
}

/// Smoc de iarbă de mare (fire subțiri curbate).
void paintGrassTuft(Canvas canvas, Offset base, double height, math.Random r, {double fog = 0, double sway = 0, Color color = const Color(0xFF5DAA5A)}) {
  for (var i = 0; i < 7; i++) {
    final lean = (i - 3) * 0.12 + (r.nextDouble() - 0.5) * 0.15 + sway;
    final len = height * (0.55 + r.nextDouble() * 0.45);
    final tip = base + Offset(math.sin(lean) * len, -math.cos(lean) * len);
    final ctrl = base + Offset(math.sin(lean * 0.4) * len * 0.5, -len * 0.55);
    final w = height * 0.045;
    final col = fogged(Color.lerp(color, const Color(0xFF9ED36A), r.nextDouble() * 0.5)!, fog);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - w, base.dy)
        ..quadraticBezierTo(ctrl.dx - w * 0.5, ctrl.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrl.dx + w * 0.5, ctrl.dy, base.dx + w, base.dy)
        ..close(),
      Paint()..shader = ui.Gradient.linear(base, tip, [darken(col, 0.3), col, lighten(col, 0.25)], [0, 0.5, 1]),
    );
  }
}
