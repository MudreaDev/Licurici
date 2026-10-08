import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:licurici_core/licurici_core.dart';

import '../aquarium/fish_art.dart';

/// O pagină de colorat: un desen din linii într-o casetă 1000 × 600 (aceeași ca fișa
/// peștilor). Liniile sunt „pereți” pentru găleată, deci formele trebuie să fie închise.
abstract class ColoringPage {
  const ColoringPage();

  String get id;

  /// Numele articulat: „Colorez casa”.
  String get name;

  void paintLines(Canvas canvas, {Color color = const Color(0xFF2B2B2B)});
}

/// Un pește de colorat (pentru acvariu).
class FishPage extends ColoringPage {
  const FishPage(this.species);

  final FishSpecies species;

  @override
  String get id => species.id;

  @override
  String get name => species.name;

  @override
  void paintLines(Canvas canvas, {Color color = const Color(0xFF2B2B2B)}) => paintLineArt(canvas, species, color: color);
}

List<ColoringPage> get fishPages => [for (final s in fishSpecies) FishPage(s)];

/// Un desen al proiectului, desenat din cod (linii groase, rotunjite).
class PicturePage extends ColoringPage {
  const PicturePage(this.id, this.name, this._draw);

  @override
  final String id;

  @override
  final String name;

  final void Function(Canvas c, Paint ink) _draw;

  @override
  void paintLines(Canvas canvas, {Color color = const Color(0xFF2B2B2B)}) => _draw(
    canvas,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );
}

Path _poly(List<List<double>> pts, {bool close = true}) {
  final p = Path()..moveTo(pts.first[0], pts.first[1]);
  for (final q in pts.skip(1)) {
    p.lineTo(q[0], q[1]);
  }
  if (close) p.close();
  return p;
}

Path _circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _oval(double x, double y, double w, double h, [double rot = 0]) {
  final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
  final m = Matrix4Lite.rotateTranslate(rot, x, y);
  return p.transform(m);
}

/// Matricea 4 × 4 (ordinea coloanelor) pentru o rotire urmată de o mutare.
abstract final class Matrix4Lite {
  static Float64List rotateTranslate(double a, double x, double y) {
    final c = math.cos(a), s = math.sin(a);
    return Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, x, y, 0, 1]);
  }
}

/// Desenează doar în afara formei [hole] (liniile din spate nu trec prin ea).
void _outside(Canvas c, Path hole, void Function() draw) {
  c.save();
  c.clipPath(Path.combine(PathOperation.difference, Path()..addRect(const Rect.fromLTWH(-50, -50, 1100, 700)), hole));
  draw();
  c.restore();
}

Path _union(List<Path> ps) => ps.skip(1).fold(ps.first, (a, b) => Path.combine(PathOperation.union, a, b));

Path _star(double x, double y, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5, rr = i.isEven ? r : r * 0.45;
    final q = Offset(x + rr * math.cos(a), y + rr * math.sin(a));
    i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

final picturePages = <ColoringPage>[
  PicturePage('casa', 'casa', (c, ink) {
    c.drawLine(const Offset(0, 520), const Offset(1000, 520), ink);
    final roof = _poly([[270, 290], [460, 130], [650, 290]]);
    _outside(c, roof, () => c.drawPath(_poly([[540, 240], [540, 150], [592, 150], [592, 240]], close: false), ink));
    c.drawPath(roof, ink);
    c.drawRect(const Rect.fromLTRB(300, 290, 620, 520), ink);
    c.drawPath(
      Path()
        ..moveTo(420, 520)
        ..lineTo(420, 430)
        ..arcToPoint(const Offset(500, 430), radius: const Radius.circular(40))
        ..lineTo(500, 520),
      ink,
    );
    c.drawCircle(const Offset(488, 478), 6, ink);
    for (final x in [330.0, 520.0]) {
      c.drawRect(Rect.fromLTWH(x, 330, 72, 64), ink);
      c.drawLine(Offset(x + 36, 330), Offset(x + 36, 394), ink);
      c.drawLine(Offset(x, 362), Offset(x + 72, 362), ink);
    }
    c.drawPath(_circle(860, 110, 55), ink);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(Offset(860 + 75 * math.cos(a), 110 + 75 * math.sin(a)), Offset(860 + 105 * math.cos(a), 110 + 105 * math.sin(a)), ink);
    }
    c.drawPath(_poly([[722, 520], [722, 405], [758, 405], [758, 520]], close: false), ink);
    c.drawPath(_union([_circle(740, 340, 72), _circle(690, 370, 46), _circle(792, 372, 46)]), ink);
    c.drawPath(_union([_circle(150, 110, 45), _circle(205, 95, 55), _circle(260, 115, 42)]), ink);
  }),
  PicturePage('floare', 'floarea', (c, ink) {
    c.drawPath(_poly([[392, 412], [608, 412], [608, 448], [392, 448]]), ink);
    c.drawPath(_poly([[405, 448], [595, 448], [568, 585], [432, 585]]), ink);
    c.drawPath(_poly([[492, 412], [492, 250], [508, 250], [508, 412]], close: false), ink);
    c.drawPath(
      Path()
        ..moveTo(492, 360)
        ..quadraticBezierTo(400, 300, 380, 340)
        ..quadraticBezierTo(420, 390, 492, 372),
      ink,
    );
    c.drawPath(
      Path()
        ..moveTo(508, 330)
        ..quadraticBezierTo(600, 270, 622, 310)
        ..quadraticBezierTo(580, 360, 508, 344),
      ink,
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawPath(_oval(500 + 92 * math.cos(a), 190 + 92 * math.sin(a), 92, 60, a), ink);
    }
    c.drawPath(_circle(500, 190, 52), ink);
    c.drawLine(const Offset(0, 585), const Offset(1000, 585), ink);
    for (final x in [120.0, 220.0, 780.0, 880.0]) {
      c.drawPath(_poly([[x - 30, 585], [x - 12, 520], [x, 585], [x + 14, 505], [x + 30, 585]], close: false), ink);
    }
    c.drawPath(_union([_oval(830, 120, 150, 70), _oval(870, 95, 110, 70)]), ink);
  }),
  PicturePage('masina', 'mașina', (c, ink) {
    c.drawLine(const Offset(0, 510), const Offset(1000, 510), ink);
    c.drawPath(
      _poly([[150, 440], [150, 365], [262, 350], [345, 262], [622, 262], [722, 350], [852, 372], [862, 440]]),
      ink,
    );
    c.drawPath(_poly([[362, 282], [470, 282], [470, 350], [292, 350]]), ink);
    c.drawPath(_poly([[492, 282], [600, 282], [680, 350], [492, 350]]), ink);
    c.drawLine(const Offset(481, 350), const Offset(481, 438), ink);
    c.drawLine(const Offset(430, 380), const Offset(460, 380), ink);
    for (final x in [300.0, 700.0]) {
      c.drawPath(_circle(x, 445, 62), ink);
      c.drawPath(_circle(x, 445, 24), ink);
    }
    c.drawPath(_circle(832, 398, 18), ink);
    c.drawPath(_star(880, 110, 50), ink);
    c.drawPath(_union([_circle(150, 110, 45), _circle(205, 95, 55), _circle(260, 115, 42)]), ink);
  }),
  PicturePage('fluture', 'fluturele', (c, ink) {
    for (final m in [1.0, -1.0]) {
      double x(double v) => 500 + m * v;
      c.drawPath(
        Path()
          ..moveTo(x(25), 250)
          ..cubicTo(x(120), 60, x(360), 30, x(400), 150)
          ..cubicTo(x(430), 260, x(250), 330, x(25), 320)
          ..close(),
        ink,
      );
      c.drawPath(
        Path()
          ..moveTo(x(25), 340)
          ..cubicTo(x(260), 330, x(340), 450, x(270), 530)
          ..cubicTo(x(200), 590, x(80), 500, x(25), 420)
          ..close(),
        ink,
      );
      c.drawPath(_circle(x(250), 180, 42), ink);
      c.drawPath(_circle(x(200), 440, 34), ink);
      c.drawPath(
        Path()
          ..moveTo(x(12), 145)
          ..quadraticBezierTo(x(40), 80, x(90), 55),
        ink,
      );
      c.drawPath(_circle(x(100), 48, 14), ink);
    }
    c.drawPath(_oval(500, 340, 52, 290), ink);
    c.drawPath(_circle(500, 170, 38), ink);
  }),
  PicturePage('curcubeu', 'curcubeul', (c, ink) {
    const cx = 500.0, base = 540.0;
    final clouds = Path.combine(
      PathOperation.union,
      _union([_circle(150, 520, 60), _circle(220, 500, 72), _circle(290, 525, 55), _oval(220, 555, 260, 60)]),
      _union([_circle(850, 520, 60), _circle(780, 500, 72), _circle(710, 525, 55), _oval(780, 555, 260, 60)]),
    );
    _outside(c, clouds, () {
      for (final r in [400.0, 340.0, 280.0, 220.0, 160.0]) {
        c.drawArc(Rect.fromCircle(center: const Offset(cx, base), radius: r), math.pi, math.pi, false, ink);
      }
      c.drawLine(const Offset(100, base), const Offset(340, base), ink);
      c.drawLine(const Offset(660, base), const Offset(900, base), ink);
    });
    c.drawPath(clouds, ink);
    for (final (x, y) in [(80.0, 90.0), (920.0, 80.0), (500.0, 60.0)]) {
      c.drawPath(_star(x, y, 34), ink);
    }
  }),
  PicturePage('racheta', 'racheta', (c, ink) {
    c.drawPath(
      Path()
        ..moveTo(500, 50)
        ..cubicTo(570, 110, 585, 170, 585, 230)
        ..lineTo(585, 430)
        ..lineTo(415, 430)
        ..lineTo(415, 230)
        ..cubicTo(415, 170, 430, 110, 500, 50)
        ..close(),
      ink,
    );
    c.drawLine(const Offset(445, 140), const Offset(555, 140), ink);
    c.drawPath(_circle(500, 250, 44), ink);
    c.drawPath(_circle(500, 250, 26), ink);
    c.drawPath(_poly([[415, 330], [335, 470], [415, 430]]), ink);
    c.drawPath(_poly([[585, 330], [665, 470], [585, 430]]), ink);
    c.drawPath(
      Path()
        ..moveTo(440, 430)
        ..quadraticBezierTo(450, 520, 500, 580)
        ..quadraticBezierTo(550, 520, 560, 430),
      ink,
    );
    c.drawPath(_poly([[470, 430], [500, 520], [530, 430]], close: false), ink);
    c.drawPath(_circle(190, 170, 70), ink);
    c.drawPath(_oval(190, 175, 230, 50, -0.25), ink);
    for (final (x, y, r) in [(820.0, 120.0, 40.0), (740.0, 330.0, 28.0), (240.0, 420.0, 30.0), (880.0, 470.0, 34.0)]) {
      c.drawPath(_star(x, y, r), ink);
    }
  }),
  PicturePage('pisica', 'pisica', (c, ink) {
    final head = _oval(500, 255, 330, 270);
    final body = _oval(540, 470, 330, 200);
    final paws = [_oval(440, 560, 90, 40), _oval(600, 560, 90, 40)];
    _outside(c, _union([head, body]), () {
      c.drawPath(
        Path()
          ..moveTo(690, 520)
          ..cubicTo(830, 500, 860, 380, 800, 300)
          ..cubicTo(780, 280, 760, 300, 780, 320)
          ..cubicTo(820, 380, 800, 470, 690, 490),
        ink,
      );
    });
    _outside(c, Path.combine(PathOperation.union, head, _union(paws)), () => c.drawPath(body, ink));
    for (final p in paws) {
      c.drawPath(p, ink);
    }
    _outside(c, head, () {
      c.drawPath(_poly([[380, 175], [372, 40], [470, 120]]), ink);
      c.drawPath(_poly([[620, 175], [628, 40], [530, 120]]), ink);
      c.drawPath(_poly([[396, 150], [392, 80], [446, 124]]), ink);
      c.drawPath(_poly([[604, 150], [608, 80], [554, 124]]), ink);
    });
    c.drawPath(head, ink);
    for (final x in [440.0, 560.0]) {
      c.drawPath(_oval(x, 235, 64, 80), ink);
      c.drawPath(_oval(x, 242, 26, 50), ink);
    }
    c.drawPath(_poly([[478, 300], [522, 300], [500, 324]]), ink);
    c.drawPath(
      Path()
        ..moveTo(500, 324)
        ..quadraticBezierTo(490, 352, 462, 346)
        ..moveTo(500, 324)
        ..quadraticBezierTo(510, 352, 538, 346),
      ink,
    );
    for (final (y, d) in [(300.0, -14.0), (320.0, 0.0), (340.0, 14.0)]) {
      c.drawLine(Offset(420, y), Offset(300, y + d * 2), ink);
      c.drawLine(Offset(580, y), Offset(700, y + d * 2), ink);
    }
  }),
];
