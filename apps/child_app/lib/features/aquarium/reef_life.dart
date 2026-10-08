import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'reef.dart';
import 'reef_parts.dart';

/// Ce se mișcă în recif (ADR-028: animație procedurală, fără shadere). Totul e lent
/// (≤ 0,5 Hz pentru lumină), fără clipiri.

// ---------------------------------------------------------------------------------------
// Causticele: rețeaua de lumină pe care o fac valurile pe fund.
// ---------------------------------------------------------------------------------------

/// Textura causticelor (256×256, se repetă fără margini): o rețea Voronoi cu muchii
/// luminoase, generată o dată din cod.
abstract final class Caustics {
  static ui.Image? image;
  static Future<ui.Image>? _loading;

  static Future<ui.Image> load() => _loading ??= _build().then((i) => image = i);

  static Future<ui.Image> _build() {
    const size = 256, cells = 5;
    final rnd = math.Random(17);
    final pts = [
      for (var j = 0; j < cells; j++)
        for (var i = 0; i < cells; i++) Offset((i + 0.15 + rnd.nextDouble() * 0.7) / cells, (j + 0.15 + rnd.nextDouble() * 0.7) / cells),
    ];
    final px = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final u = (x + 0.5) / size, v = (y + 0.5) / size;
        var f1 = 9.0, f2 = 9.0;
        final ci = (u * cells).floor(), cj = (v * cells).floor();
        for (var dj = -1; dj <= 1; dj++) {
          for (var di = -1; di <= 1; di++) {
            final i = ci + di, j = cj + dj;
            final p = pts[(j % cells) * cells + (i % cells)];
            // Celulele de dincolo de margine: aceleași puncte, mutate (textura se repetă).
            final px0 = p.dx + (i < 0 ? -1 : (i >= cells ? 1 : 0)), py0 = p.dy + (j < 0 ? -1 : (j >= cells ? 1 : 0));
            final d = math.sqrt((px0 - u) * (px0 - u) + (py0 - v) * (py0 - v));
            if (d < f1) {
              f2 = f1;
              f1 = d;
            } else if (d < f2) {
              f2 = d;
            }
          }
        }
        final e = (f2 - f1) * cells; // 0 pe muchie
        final line = math.pow((1 - (e / 0.32)).clamp(0.0, 1.0), 2.2) + 0.12 * (1 - (e / 0.9).clamp(0.0, 1.0));
        final a = (line.clamp(0.0, 1.0) * 255).round();
        final o = (y * size + x) * 4;
        px[o] = a;
        px[o + 1] = a;
        px[o + 2] = a;
        px[o + 3] = a;
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, size, size, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}

/// Desenează causticele în [area], cu două straturi care se mișcă în sensuri diferite.
/// [squash] turtește rețeaua pe verticală (pe fund, în perspectivă).
/// Desenează causticele în benzile [bands] ale zonei [area] (fiecare bandă cu intensitatea
/// ei), cu două straturi care se mișcă în sensuri diferite. Cele două shadere se fac o dată
/// pe apel, nu pe bandă. [squash] turtește rețeaua pe verticală (pe fund, în perspectivă).
void paintCaustics(
  Canvas canvas,
  Rect area,
  double t,
  double h, {
  required List<(Rect, double)> bands,
  double squash = 0.45,
  double scale = 1,
}) {
  final img = Caustics.image;
  if (img == null) return;
  final s = h * 0.55 * scale / img.width;
  final layers = [
    for (final (dx, dy, k, a) in [(t * 9.0, t * 3.0, 1.0, 1.0), (-t * 7.0, t * 4.5, 0.77, 0.8)])
      (
        ui.ImageShader(
          img,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4Storage.scaleTranslate(s * k, s * k * squash, dx * h / 300, dy * h / 300 + area.top),
        ),
        a,
      ),
  ];
  final paint = Paint()..blendMode = BlendMode.plus;
  for (final (strip, alpha) in bands) {
    for (final (shader, a) in layers) {
      canvas.drawRect(
        strip,
        paint
          ..shader = shader
          ..color = Color.fromRGBO(255, 255, 255, alpha * a),
      );
    }
  }
}

abstract final class Matrix4Storage {
  static Float64List scaleTranslate(double sx, double sy, double tx, double ty) =>
      Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);
}

// ---------------------------------------------------------------------------------------
// Cufărul cu comori: se deschide singur din când în când sau când e atins.
// ---------------------------------------------------------------------------------------

class ReefChest {
  /// Când s-a deschis ultima dată (timpul fundalului).
  double openedAt = -100;

  static const double depth = 0.32;

  static Offset baseAt(Size s) => Offset(s.width * 0.6, s.height * floorY(s.width * 0.6, s.width, depth));
  static double widthFor(Size s) => s.height * 0.13;

  /// Unde se poate atinge cufărul (pixeli).
  static Rect hitRect(Size s) {
    final b = baseAt(s), w = widthFor(s);
    return Rect.fromLTRB(b.dx - w * 0.65, b.dy - w * 0.95, b.dx + w * 0.65, b.dy + w * 0.1);
  }

  void open(double t) {
    if (t - openedAt > 2.2) openedAt = t;
  }

  /// Cât e de deschis capacul acum (0…1). Se deschide și singur, la ~15 s.
  double lid(double t) {
    final auto = t % 15.0;
    double curve(double age) {
      if (age < 0 || age > 2.6) return 0;
      if (age < 0.35) return Curves.easeOutBack.transform(age / 0.35);
      if (age < 1.9) return 1;
      return 1 - Curves.easeIn.transform((age - 1.9) / 0.7);
    }

    return math.max(curve(t - openedAt), curve(auto - 11));
  }

  /// Secunde de la ultima deschidere (pentru bule).
  double sinceOpen(double t) {
    final auto = t % 15.0 - 11;
    final a = t - openedAt;
    return [a, auto].where((x) => x >= 0).fold(99.0, math.min);
  }
}

// ---------------------------------------------------------------------------------------
// Stratul din spatele peștilor.
// ---------------------------------------------------------------------------------------

class ReefAmbiencePainter extends CustomPainter {
  ReefAmbiencePainter(this.time, {required this.chest, this.seed = 7}) : super(repaint: time);

  final ValueListenable<double> time;
  final ReefChest chest;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, w = size.width, h = size.height;
    final r = math.Random(seed);

    _surface(canvas, size, t);

    // Alge înalte în depărtare.
    for (var i = 0; i < 8; i++) {
      final x = w * (0.04 + i * 0.13 + r.nextDouble() * 0.06);
      paintKelp(canvas, Offset(x, h * backFloor(x, w) + h * 0.01), h * (0.22 + r.nextDouble() * 0.2), h * 0.014, t, r.nextDouble() * 6, fog: 0.62);
    }

    _school(canvas, size, t);
    _jellies(canvas, size, t);
    _turtle(canvas, size, t);

    // Causticele pe fund: mai stinse în spate (lumina se pierde în apă).
    final floorArea = Rect.fromLTWH(0, h * 0.74, w, h * 0.26);
    canvas.save();
    canvas.clipPath(floorPath(size));
    paintCaustics(
      canvas,
      floorArea,
      t,
      h,
      bands: [
        for (var i = 0; i < 6; i++)
          (
            Rect.fromLTWH(0, floorArea.top + floorArea.height * i / 6, w, floorArea.height / 6 + 1),
            0.05 + 0.15 * math.min(1.0, i / 3),
          ),
      ],
    );
    canvas.restore();

    // Alge la mijlocul adâncimii.
    for (var i = 0; i < 6; i++) {
      final x = w * (0.1 + i * 0.16 + r.nextDouble() * 0.06);
      final z = 0.45 + r.nextDouble() * 0.4;
      final col = [const Color(0xFF3E9A6A), const Color(0xFF4FAE73), const Color(0xFF2F8A66)][i % 3];
      paintKelp(canvas, Offset(x, h * floorY(x, w, z) + h * 0.005), h * (0.18 + r.nextDouble() * 0.2) * (1.2 - 0.4 * z), h * 0.02 * (1.2 - 0.4 * z), t, r.nextDouble() * 6, fog: z * 0.4, color: col);
    }

    _chest(canvas, size, t);
    _crab(canvas, size, t);

    // Un izvor de bule din nisip, în dreapta.
    final src = Offset(w * 0.79, h * floorY(w * 0.79, w, 0.55));
    for (var i = 0; i < 8; i++) {
      final speed = 0.07 + (i * 37 % 10) / 200;
      final life = (t * speed + i / 8) % 1;
      final y = src.dy - life * h * 0.82;
      final x = src.dx + math.sin(t * 2 + i * 1.7) * h * 0.012 * (0.4 + life);
      final rad = h * (0.004 + 0.004 * ((i * 7) % 3) / 2) * (0.7 + life * 0.7);
      paintBubble(canvas, Offset(x, y), rad, life < 0.88 ? math.min(1, life * 12) : (1 - life) * 8);
    }

    // Plancton care plutește (în spatele peștilor).
    final dust = Paint();
    for (var i = 0; i < 45; i++) {
      final sx = r.nextDouble(), sy = r.nextDouble(), sp = 0.003 + r.nextDouble() * 0.006, z = r.nextDouble();
      final x = (sx * w + math.sin(t * 0.2 + i) * h * 0.02 + t * h * 0.004) % w;
      final y = ((sy + t * sp) % 1) * h * 0.82;
      dust.color = Color.fromRGBO(235, 250, 255, 0.25 + 0.3 * (1 - z));
      canvas.drawCircle(Offset(x, y), h * (0.0012 + 0.002 * (1 - z)), dust);
    }
  }

  /// Suprafața văzută de dedesubt: o bandă luminoasă cu rețeaua valurilor.
  void _surface(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    final band = Rect.fromLTWH(0, 0, w, h * 0.075);
    canvas.drawRect(
      band,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.075), const [Color(0x77FFFFFF), Color(0x00FFFFFF)]),
    );
    // Rețeaua valurilor se vede doar sus și se stinge în jos (benzi tot mai slabe).
    paintCaustics(
      canvas,
      band,
      t * 1.4,
      h,
      squash: 0.2,
      scale: 0.8,
      bands: [for (var i = 0; i < 4; i++) (Rect.fromLTWH(0, band.height * i / 4, w, band.height / 4 + 1), 0.3 * (1 - i / 4))],
    );
    // Marginea de jos a suprafeței, unduită (unde se termină „oglinda” apei).
    final edge = Path()..moveTo(0, 0);
    for (var x = 0.0; x <= w + 10; x += 10) {
      edge.lineTo(x, h * (0.035 + 0.007 * math.sin(x / w * 9 + t * 0.8) + 0.004 * math.sin(x / w * 23 - t * 1.1)));
    }
    edge
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(edge, Paint()..color = const Color(0x44F0FFFF));
  }

  /// Un banc de peștișori argintii în depărtare: trece de la stânga la dreapta, apoi înapoi.
  void _school(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    const period = 56.0;
    final u = (t + 8) % period / period;
    final dir = u < 0.5 ? 1.0 : -1.0;
    final k = u < 0.5 ? u * 2 : (u - 0.5) * 2;
    final lx = dir > 0 ? -0.2 * w + k * 1.4 * w : 1.2 * w - k * 1.4 * w;
    final ly = h * (dir > 0 ? 0.36 : 0.48) + math.sin(t * 0.35) * h * 0.04;
    final r = math.Random(5);
    final body = fogged(const Color(0xFFD7E6EC), 0.5), back = fogged(const Color(0xFF7D9DB0), 0.5);
    for (var i = 0; i < 18; i++) {
      final ox = (r.nextDouble() - 0.5) * h * 0.22, oy = (r.nextDouble() - 0.5) * h * 0.1;
      final ph = r.nextDouble() * 6;
      final c = Offset(lx + ox + math.sin(t * 0.9 + ph) * h * 0.008, ly + oy + math.sin(t * 0.7 + ph * 2) * h * 0.006);
      final len = h * (0.022 + r.nextDouble() * 0.008);
      final wig = math.sin(t * 9 + ph) * 0.3;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(dir, 1);
      canvas.drawPath(
        Path()
          ..moveTo(-len * 0.45, 0)
          ..lineTo(-len * 0.8, -len * (0.22 + wig * 0.2))
          ..lineTo(-len * 0.78, len * (0.22 - wig * 0.2))
          ..close(),
        Paint()..color = back,
      );
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: len, height: len * 0.36), Paint()..color = body);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -len * 0.07), width: len * 0.8, height: len * 0.12), Paint()..color = back.withValues(alpha: 0.6));
      canvas.restore();
    }
  }

  /// O țestoasă care trece prin depărtare, cam o dată pe minut, dând încet din labe.
  void _turtle(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    const period = 64.0, cross = 30.0;
    final u = (t + 20) % period;
    if (u > cross) return;
    final pass = ((t + 20) ~/ period).isEven;
    final k = u / cross;
    final x = pass ? -0.12 * w + k * 1.24 * w : 1.12 * w - k * 1.24 * w;
    final y = h * (0.3 + 0.04 * math.sin(t * 0.3));
    paintTurtle(canvas, Offset(x, y), h * 0.15, t, dir: pass ? 1 : -1, fog: 0.42);
  }

  /// Un crab care se plimbă într-o parte și în alta pe nisip și își ridică uneori cleștii.
  void _crab(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    // Mers lateral cu opriri: poziția urmează o curbă lină, cu pauze.
    final phase = t * 0.12;
    final walk = math.sin(phase) + 0.25 * math.sin(phase * 2.7);
    final moving = (math.cos(phase) + 0.67 * math.cos(phase * 2.7)).abs() > 0.25;
    final x = w * (0.36 + 0.09 * walk);
    final base = Offset(x, h * floorY(x, w, 0.12));
    paintCrab(canvas, base, h * 0.05, t, walking: moving);
  }

  /// Două meduze care urcă încet, pulsând.
  void _jellies(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    for (var i = 0; i < 2; i++) {
      final life = (t * 0.011 + i * 0.5) % 1;
      final y = h * (0.78 - life * 0.75);
      final x = w * (i == 0 ? 0.24 : 0.73) + math.sin(t * 0.12 + i * 3) * w * 0.04;
      final fade = math.min(1.0, math.min(life * 8, (1 - life) * 8));
      paintJelly(canvas, Offset(x, y), h * (i == 0 ? 0.04 : 0.032), t * 1.5 + i * 2, fog: 0.35 + i * 0.15, alpha: fade);
    }
  }

  void _chest(Canvas canvas, Size size, double t) {
    final h = size.height;
    final base = ReefChest.baseAt(size), cw = ReefChest.widthFor(size);
    final open = chest.lid(t);
    paintChest(canvas, base, cw, open, fog: 0.12);
    // Bulele care ies din cufăr când se deschide.
    final since = chest.sinceOpen(t);
    if (since < 3.2) {
      final r = math.Random(3);
      for (var i = 0; i < 14; i++) {
        final delay = r.nextDouble() * 0.8;
        final age = since - delay;
        if (age < 0) continue;
        final rise = age * h * (0.16 + r.nextDouble() * 0.12);
        final c = base + Offset((r.nextDouble() - 0.5) * cw * 0.6 + math.sin(age * 5 + i) * h * 0.01, -cw * 0.6 - rise);
        paintBubble(canvas, c, h * (0.006 + r.nextDouble() * 0.01), (1 - age / 2.4).clamp(0.0, 1.0));
      }
    }
  }

  @override
  bool shouldRepaint(ReefAmbiencePainter old) => false;
}

/// Alga lungă care se leagănă în curent.
void paintKelp(Canvas canvas, Offset base, double height, double width, double t, double phase, {double fog = 0, Color color = const Color(0xFF3E9A6A)}) {
  const segs = 14;
  final left = <Offset>[], right = <Offset>[];
  for (var s = 0; s <= segs; s++) {
    final k = s / segs;
    final sway = math.sin(t * 0.8 + phase + k * 2.4) * height * 0.12 * k * k + math.sin(t * 0.33 + phase) * height * 0.04 * k;
    final cx = base.dx + sway + math.sin(k * 5 + phase) * width * 0.4;
    final y = base.dy - height * k;
    final half = width * (1 - k * 0.7) * (0.75 + 0.25 * math.sin(k * 9 + phase));
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
  final col = fogged(color, fog);
  canvas.drawPath(
    p,
    Paint()
      ..shader = ui.Gradient.linear(base, base - Offset(0, height), [
        darken(col, 0.35),
        col,
        lighten(col, 0.3),
      ], [0, 0.55, 1]),
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
      ..strokeWidth = width * 0.14
      ..color = lighten(col, 0.35).withValues(alpha: 0.4),
  );
}

/// Țestoasa văzută din profil: carapace cu plăci, cap, labe care vâslesc.
void paintTurtle(Canvas canvas, Offset c, double len, double t, {int dir = 1, double fog = 0}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(dir.toDouble(), 1);
  final skin = fogged(const Color(0xFF9CC17A), fog), skinDark = fogged(const Color(0xFF6E9A55), fog);
  final shell = fogged(const Color(0xFF5E8C4A), fog), plate = fogged(const Color(0xFF86B266), fog);
  final stroke = math.sin(t * 1.6);
  Path flipper(Offset root, double l, double angle, double width) {
    final tip = root + Offset(math.cos(angle), math.sin(angle)) * l;
    final n = Offset(-math.sin(angle), math.cos(angle)) * width;
    final d = Offset(math.cos(angle), math.sin(angle)) * l;
    // O vâslă: îngustă la încheietură, lată la mijloc, rotunjită la vârf.
    return Path()
      ..moveTo(root.dx - n.dx, root.dy - n.dy)
      ..cubicTo(root.dx - n.dx * 1.6 + d.dx * 0.45, root.dy - n.dy * 1.6 + d.dy * 0.45, tip.dx - n.dx * 1.1, tip.dy - n.dy * 1.1, tip.dx, tip.dy)
      ..cubicTo(tip.dx + n.dx * 0.9, tip.dy + n.dy * 0.9, root.dx + n.dx * 1.4 + d.dx * 0.5, root.dy + n.dy * 1.4 + d.dy * 0.5, root.dx + n.dx, root.dy + n.dy)
      ..close();
  }

  // Labele din spate (în spatele carapacei).
  canvas.drawPath(flipper(Offset(-len * 0.28, len * 0.1), len * 0.28, 2.5 + stroke * 0.25, len * 0.06), Paint()..color = skinDark);
  canvas.drawPath(flipper(Offset(len * 0.18, len * 0.08), len * 0.42, 1.9 + stroke * 0.55, len * 0.08), Paint()..color = skinDark);
  // Capul și coada.
  canvas.drawOval(Rect.fromCenter(center: Offset(len * 0.5, -len * 0.02), width: len * 0.26, height: len * 0.17), Paint()..color = skin);
  canvas.drawCircle(Offset(len * 0.56, -len * 0.05), len * 0.022, Paint()..color = fogged(const Color(0xFF1E2A22), fog));
  canvas.drawPath(
    Path()
      ..moveTo(-len * 0.4, len * 0.02)
      ..lineTo(-len * 0.52, len * 0.06)
      ..lineTo(-len * 0.4, len * 0.08)
      ..close(),
    Paint()..color = skin,
  );
  // Carapacea: o cupolă cu plăci.
  final dome = Rect.fromCenter(center: Offset.zero, width: len * 0.8, height: len * 0.5);
  final body = Path()
    ..addArc(dome, math.pi, math.pi)
    ..quadraticBezierTo(0, len * 0.16, -len * 0.4, 0)
    ..close();
  canvas.drawPath(body, Paint()..shader = ui.Gradient.linear(dome.topCenter, dome.center + Offset(0, len * 0.12), [lighten(shell, 0.15), shell]));
  canvas.save();
  canvas.clipPath(body);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = len * 0.02
    ..color = darken(shell, 0.25);
  // Plăcile: un rând de hexagoane pe spate, marginea mai deschisă jos.
  canvas.drawPath(
    Path()
      ..addArc(dome.deflate(len * 0.035), math.pi, math.pi)
      ..close(),
    line,
  );
  for (final x in [-0.22, 0.0, 0.22]) {
    final c0 = Offset(len * x, -len * 0.13);
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final q = c0 + Offset(math.cos(a) * len * 0.1, math.sin(a) * len * 0.075);
      i == 0 ? hex.moveTo(q.dx, q.dy) : hex.lineTo(q.dx, q.dy);
    }
    hex.close();
    canvas.drawPath(hex, Paint()..color = plate);
    canvas.drawPath(hex, line);
  }
  canvas.restore();
  // Laba din față (peste carapace).
  canvas.drawPath(flipper(Offset(len * 0.22, len * 0.04), len * 0.46, 2.1 - stroke * 0.6, len * 0.085), Paint()..color = skin);
  canvas.restore();
}

/// Crabul: carapace lată, ochi pe codițe, picioare care pășesc, clești care se ridică.
void paintCrab(Canvas canvas, Offset base, double size, double t, {bool walking = true}) {
  const red = Color(0xFFE5603E), dark = Color(0xFFB8432A), light = Color(0xFFF59A7A);
  final step = walking ? math.sin(t * 12) : 0.0;
  final up = math.sin(t * 0.7) > 0.85 ? 1.0 : 0.0; // din când în când ridică cleștii
  final body = base - Offset(0, size * 0.55 + step.abs() * size * 0.04);
  paintContactShadow(canvas, base, size * 2.6, alpha: 0.3);
  final leg = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = size * 0.1
    ..color = dark;
  for (final side in [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final lift = (i.isEven ? step : -step) * size * 0.12;
      final root = body + Offset(side * size * (0.35 + i * 0.12), size * 0.1);
      final knee = root + Offset(side * size * 0.35, -size * 0.12 - lift);
      final foot = Offset(base.dx + side * size * (0.75 + i * 0.22), base.dy - math.max(0.0, lift));
      canvas.drawPath(
        Path()
          ..moveTo(root.dx, root.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy),
        leg,
      );
    }
    // Brațul și cleștele.
    final shoulder = body + Offset(side * size * 0.45, -size * 0.1);
    final hand = shoulder + Offset(side * size * 0.35, -size * (0.35 + 0.45 * up));
    canvas.drawLine(shoulder, hand, leg..strokeWidth = size * 0.13);
    final open = 0.3 + 0.25 * math.sin(t * 3) * up;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(side * (-0.4 - 0.5 * up));
    canvas.drawPath(
      Path()..addArc(Rect.fromCenter(center: Offset.zero, width: size * 0.5, height: size * 0.44), math.pi + open, 2 * math.pi - open * 2),
      Paint()..color = red,
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(-size * 0.06, -size * 0.06), width: size * 0.16, height: size * 0.1), Paint()..color = light);
    canvas.restore();
  }
  // Carapacea.
  final shell = Rect.fromCenter(center: body, width: size * 1.25, height: size * 0.8);
  canvas.drawOval(shell, Paint()..shader = ui.Gradient.radial(body - Offset(size * 0.2, size * 0.2), size * 0.8, [light, red, dark], [0, 0.5, 1]));
  // Ochii pe codițe.
  for (final side in [-1.0, 1.0]) {
    final eye = body + Offset(side * size * 0.2, -size * 0.55);
    canvas.drawLine(body + Offset(side * size * 0.15, -size * 0.3), eye, leg..strokeWidth = size * 0.07);
    canvas.drawCircle(eye, size * 0.11, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(eye + Offset(0, size * 0.02), size * 0.06, Paint()..color = const Color(0xFF1E1E26));
  }
  // Zâmbetul.
  canvas.drawArc(
    Rect.fromCenter(center: body + Offset(0, size * 0.05), width: size * 0.3, height: size * 0.18),
    0.3,
    math.pi - 0.6,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.05
      ..strokeCap = StrokeCap.round
      ..color = dark,
  );
}

/// Meduza: clopot translucid care se strânge și se desface, cu tentacule unduite.
void paintJelly(Canvas canvas, Offset c, double r, double phase, {double fog = 0, double alpha = 1}) {
  if (alpha <= 0) return;
  final pulse = 0.5 + 0.5 * math.sin(phase);
  final bw = r * (1 - 0.16 * pulse), bh = r * 0.85 * (1 + 0.14 * pulse);
  final pink = fogged(const Color(0xFFF59AC8), fog);
  // Tentaculele.
  final tent = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 6; i++) {
    final x0 = c.dx + (i - 2.5) / 2.5 * bw * 0.8;
    final p = Path()..moveTo(x0, c.dy);
    for (var k = 1; k <= 10; k++) {
      final y = c.dy + k * r * 0.22;
      p.lineTo(x0 + math.sin(phase * 0.8 - k * 0.6 + i) * r * 0.12 * k / 5, y);
    }
    canvas.drawPath(p, tent
      ..strokeWidth = r * 0.05
      ..color = pink.withValues(alpha: 0.45 * alpha));
  }
  // Brațele din mijloc, mai groase.
  for (var i = 0; i < 2; i++) {
    final x0 = c.dx + (i - 0.5) * bw * 0.3;
    final p = Path()..moveTo(x0, c.dy);
    for (var k = 1; k <= 6; k++) {
      p.lineTo(x0 + math.sin(phase * 0.7 - k * 0.8 + i * 2) * r * 0.14, c.dy + k * r * 0.2);
    }
    canvas.drawPath(p, tent
      ..strokeWidth = r * 0.14
      ..color = lighten(pink, 0.2).withValues(alpha: 0.5 * alpha));
  }
  // Clopotul.
  final bell = Path()
    ..moveTo(c.dx - bw, c.dy)
    ..cubicTo(c.dx - bw, c.dy - bh * 1.3, c.dx + bw, c.dy - bh * 1.3, c.dx + bw, c.dy);
  for (var i = 0; i < 8; i++) {
    final x1 = c.dx + bw - (i + 1) * bw * 2 / 8;
    bell.quadraticBezierTo(x1 + bw / 8, c.dy + r * 0.1, x1, c.dy);
  }
  bell.close();
  canvas.drawPath(
    bell,
    Paint()
      ..shader = ui.Gradient.radial(c - Offset(bw * 0.2, bh * 0.6), bw * 1.3, [
        lighten(pink, 0.6).withValues(alpha: 0.75 * alpha),
        pink.withValues(alpha: 0.45 * alpha),
        pink.withValues(alpha: 0.25 * alpha),
      ], [0, 0.5, 1]),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c - Offset(0, bh * 0.4), width: bw * 0.9, height: bh * 0.5),
    Paint()..color = lighten(pink, 0.4).withValues(alpha: 0.35 * alpha),
  );
  canvas.drawCircle(c - Offset(bw * 0.35, bh * 0.75), r * 0.12, Paint()..color = Color.fromRGBO(255, 255, 255, 0.6 * alpha));
}

/// Cufărul cu comori (vedere din față). [open] 0…1: capacul se ridică, înăuntru strălucesc
/// monede.
void paintChest(Canvas canvas, Offset base, double width, double open, {double fog = 0}) {
  final w = width, bh = w * 0.5, lidH = w * 0.32;
  final top = base.dy - bh;
  final wood = fogged(const Color(0xFF9A5B2E), fog), woodDark = fogged(const Color(0xFF5E3417), fog);
  final gold = fogged(const Color(0xFFF2C14E), fog), goldDark = fogged(const Color(0xFFB8862B), fog);
  paintContactShadow(canvas, base + Offset(0, w * 0.02), w * 1.5, alpha: 0.4);

  // Înăuntru (se vede doar cu capacul ridicat): lumină aurie și monede.
  if (open > 0.02) {
    final inside = Rect.fromLTRB(base.dx - w * 0.46, top - lidH * 0.5 * open, base.dx + w * 0.46, top + bh * 0.2);
    canvas.drawRect(inside, Paint()..color = darken(wood, 0.6));
    canvas.drawCircle(
      Offset(base.dx, top),
      w * (0.5 + 0.4 * open),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(Offset(base.dx, top), w * (0.5 + 0.4 * open), [
          Color.fromRGBO(255, 215, 120, 0.55 * open),
          const Color(0x00FFD778),
        ]),
    );
    for (var i = 0; i < 7; i++) {
      final cx = base.dx + (i - 3) * w * 0.12, cy = top + (i.isEven ? 0 : -w * 0.04) - w * 0.02 * open;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.14, height: w * 0.07), Paint()..color = gold);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.02, cy - w * 0.01), width: w * 0.06, height: w * 0.02), Paint()..color = lighten(gold, 0.6));
    }
  }

  // Lada.
  final box = RRect.fromRectAndRadius(Rect.fromLTRB(base.dx - w / 2, top, base.dx + w / 2, base.dy), Radius.circular(w * 0.04));
  canvas.drawRRect(box, Paint()..shader = ui.Gradient.linear(box.outerRect.topCenter, box.outerRect.bottomCenter, [wood, darken(wood, 0.3)]));
  final plank = Paint()
    ..color = woodDark.withValues(alpha: 0.6)
    ..strokeWidth = w * 0.015;
  for (var i = 1; i < 3; i++) {
    canvas.drawLine(Offset(base.dx - w / 2, top + bh * i / 3), Offset(base.dx + w / 2, top + bh * i / 3), plank);
  }
  for (final x in [-0.36, 0.36]) {
    canvas.drawRect(Rect.fromLTRB(base.dx + w * (x - 0.05), top, base.dx + w * (x + 0.05), base.dy), Paint()..color = goldDark);
    canvas.drawRect(Rect.fromLTRB(base.dx + w * (x - 0.05), top, base.dx + w * (x - 0.02), base.dy), Paint()..color = gold);
  }

  // Capacul: se ridică și se vede tot mai scurt (se rotește spre spate).
  final lift = open * lidH * 0.9;
  final squash = 1 - 0.55 * open;
  final lidRect = Rect.fromLTRB(base.dx - w * 0.52, top - lidH * squash - lift, base.dx + w * 0.52, top - lift);
  final lid = Path()
    ..moveTo(lidRect.left, lidRect.bottom)
    ..lineTo(lidRect.left, lidRect.top + lidRect.height * 0.55)
    ..cubicTo(lidRect.left, lidRect.top - lidRect.height * 0.15, lidRect.right, lidRect.top - lidRect.height * 0.15, lidRect.right, lidRect.top + lidRect.height * 0.55)
    ..lineTo(lidRect.right, lidRect.bottom)
    ..close();
  canvas.drawPath(lid, Paint()..shader = ui.Gradient.linear(lidRect.topCenter, lidRect.bottomCenter, [lighten(wood, 0.15), wood]));
  canvas.drawRect(Rect.fromLTRB(lidRect.left, lidRect.bottom - w * 0.05, lidRect.right, lidRect.bottom), Paint()..color = goldDark);
  for (final x in [-0.36, 0.36]) {
    canvas.drawRect(Rect.fromLTRB(base.dx + w * (x - 0.05), lidRect.top + lidRect.height * 0.1, base.dx + w * (x + 0.05), lidRect.bottom), Paint()..color = gold);
  }
  // Încuietoarea.
  final lock = Offset(base.dx, top + bh * 0.22);
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: lock, width: w * 0.14, height: w * 0.16), Radius.circular(w * 0.03)), Paint()..color = gold);
  canvas.drawCircle(lock + Offset(0, -w * 0.01), w * 0.022, Paint()..color = woodDark);
  canvas.drawRect(Rect.fromCenter(center: lock + Offset(0, w * 0.03), width: w * 0.012, height: w * 0.04), Paint()..color = woodDark);
}

// ---------------------------------------------------------------------------------------
// Stratul din fața peștilor.
// ---------------------------------------------------------------------------------------

class ReefFrontPainter extends CustomPainter {
  ReefFrontPainter(this.time, {this.seed = 11}) : super(repaint: time);

  final ValueListenable<double> time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value, w = size.width, h = size.height;
    final r = math.Random(seed);
    final side = math.min(h * 0.5, w * 0.24);

    // Alge înalte la margini, peste stânci.
    for (final (x, ht, ph, col) in [
      (side * 0.42, 0.5, 0.0, const Color(0xFF2E7D4F)),
      (w - side * 0.5, 0.56, 2.0, const Color(0xFF3B8F55)),
      (w - side * 0.08, 0.42, 4.0, const Color(0xFF2E7D4F)),
    ]) {
      paintKelp(canvas, Offset(x, h * 1.02), h * ht, h * 0.034, t, ph, color: col);
    }

    paintAnemone(canvas, ReefForegroundPainter.anemoneAt(size), h * 0.11, t);
    _rays(canvas, size, t);

    // Particule mari, nefocalizate, foarte aproape de geam.
    for (var i = 0; i < 9; i++) {
      final sx = r.nextDouble(), sy = r.nextDouble(), rad = h * (0.008 + r.nextDouble() * 0.014);
      final x = (sx * w + t * h * 0.01 * (1 + i % 3)) % (w + rad * 2) - rad;
      final y = (sy * h * 0.85 + math.sin(t * 0.25 + i) * h * 0.03);
      final c = Offset(x, y);
      canvas.drawCircle(
        c,
        rad,
        Paint()..shader = ui.Gradient.radial(c, rad, [const Color(0x30FFFFFF), const Color(0x00FFFFFF)]),
      );
    }
  }

  /// Razele de lumină: fâșii moi (margini transparente), care se leagănă încet.
  void _rays(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    final pos = <double>[], cols = <int>[];
    for (var i = 0; i < 6; i++) {
      final x = w * (0.05 + i * 0.18 + 0.025 * math.sin(t * 0.11 + i * 1.3));
      final a = (0.07 + 0.06 * (0.5 + 0.5 * math.sin(t * 0.3 + i * 1.9))) * (i.isEven ? 1 : 0.7);
      final half = w * (0.025 + 0.018 * (i % 3));
      final slant = h * 0.28;
      final len = h * 0.92;
      // Trei margini (stânga – mijloc – dreapta) × sus/jos; mijlocul luminos, marginile 0.
      final top = [Offset(x - half, 0), Offset(x, 0), Offset(x + half, 0)];
      final bot = [Offset(x - half * 2.4 + slant, len), Offset(x + slant, len), Offset(x + half * 2.4 + slant, len)];
      final ta = [0.0, a, 0.0], ba = [0.0, a * 0.1, 0.0];
      for (var k = 0; k < 2; k++) {
        final quad = [(top[k], ta[k]), (top[k + 1], ta[k + 1]), (bot[k], ba[k]), (top[k + 1], ta[k + 1]), (bot[k + 1], ba[k + 1]), (bot[k], ba[k])];
        for (final (p, al) in quad) {
          pos
            ..add(p.dx)
            ..add(p.dy);
          cols.add(((al * 255).round() << 24) | 0xFFFFF4);
        }
      }
    }
    final v = ui.Vertices.raw(ui.VertexMode.triangles, Float32List.fromList(pos), colors: Int32List.fromList(cols));
    canvas.drawVertices(v, BlendMode.dst, Paint()..blendMode = BlendMode.plus);
    v.dispose();
  }

  @override
  bool shouldRepaint(ReefFrontPainter old) => false;
}

/// Anemona: un smoc de tentacule care se leagănă, cu vârfuri luminoase.
void paintAnemone(Canvas canvas, Offset base, double size, double t) {
  const n = 24;
  final col = const Color(0xFFB45CC8), tip = const Color(0xFFFFC2E8);
  // Piciorul.
  canvas.drawPath(
    Path()
      ..moveTo(base.dx - size * 0.32, base.dy + size * 0.1)
      ..quadraticBezierTo(base.dx - size * 0.36, base.dy - size * 0.2, base.dx - size * 0.24, base.dy - size * 0.28)
      ..lineTo(base.dx + size * 0.24, base.dy - size * 0.28)
      ..quadraticBezierTo(base.dx + size * 0.36, base.dy - size * 0.2, base.dx + size * 0.32, base.dy + size * 0.1)
      ..close(),
    Paint()
      ..shader = ui.Gradient.linear(Offset(base.dx - size * 0.3, 0), Offset(base.dx + size * 0.3, 0), [
        const Color(0xFFF08A5D),
        const Color(0xFFC75B3A),
      ]),
  );
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  // Întâi tentaculele din spate (mai închise), apoi cele din față.
  for (final back in [true, false]) {
    for (var i = 0; i < n; i++) {
      if ((i.isEven) != back) continue;
      final k = i / (n - 1);
      final ang = -math.pi * (0.08 + 0.84 * k);
      final root = base + Offset(math.cos(ang) * size * 0.22, -size * 0.28 + math.sin(ang) * size * 0.05);
      final len = size * (back ? 0.75 : 0.62) * (0.8 + 0.2 * math.sin(i * 1.7));
      final sway = math.sin(t * 1.1 + i * 0.45) * 0.28 + math.sin(t * 0.4) * 0.12;
      final dir = ang + sway * (0.4 + 0.6 * (1 - (k - 0.5).abs()));
      final mid = root + Offset(math.cos(ang) * len * 0.5, math.sin(ang) * len * 0.5);
      final end = root + Offset(math.cos(dir) * len, math.sin(dir) * len);
      final p = Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      final c = back ? darken(col, 0.25) : col;
      canvas.drawPath(p, stroke
        ..strokeWidth = size * 0.075
        ..color = c);
      canvas.drawPath(p.shift(Offset(-size * 0.012, -size * 0.008)), stroke
        ..strokeWidth = size * 0.025
        ..color = lighten(c, 0.35).withValues(alpha: 0.7));
      canvas.drawCircle(end, size * 0.05, Paint()..color = back ? darken(tip, 0.15) : tip);
    }
  }
}
