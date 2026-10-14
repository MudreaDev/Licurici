import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:licurici_core/licurici_core.dart';

/// Caseta desenului (unități de desen) — fișa, pânza de colorat și imaginea peștelui.
const fishBox = Size(FishSpecies.boxWidth, FishSpecies.boxHeight);
const _ink = Color(0xFF2B2B2B);

/// Curba unui model ca `Path` (unități de desen).
Path curvePath(List<math.Point<double>> pts, {bool closed = true}) {
  final segs = catmullRomBeziers(pts, closed: closed);
  final p = Path()..moveTo(segs.first.$1.x, segs.first.$1.y);
  for (final (_, c1, c2, b) in segs) {
    p.cubicTo(c1.x, c1.y, c2.x, c2.y, b.x, b.y);
  }
  if (closed) p.close();
  return p;
}

/// Desenul de pe fișă: conturul exterior al siluetei (doar în afara ei, ca să nu acopere
/// culoarea) și liniile interioare, în caseta 1000×600.
void paintLineArt(Canvas canvas, FishSpecies s, {Color color = _ink, bool eye = true}) {
  final shapes = [for (final c in s.shapes) curvePath(c)];
  canvas.saveLayer(Offset.zero & fishBox, Paint());
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = FishSpecies.outlineWidth * 2
    ..strokeJoin = StrokeJoin.round
    ..color = color;
  for (final p in shapes) {
    canvas.drawPath(p, stroke);
  }
  final cut = Paint()..blendMode = BlendMode.dstOut;
  for (final p in shapes) {
    canvas.drawPath(p, cut);
  }
  canvas.restore();
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = FishSpecies.detailWidth
    ..strokeCap = StrokeCap.round
    ..color = color;
  for (final d in s.details) {
    canvas.drawPath(curvePath(d, closed: false), line);
  }
  if (eye) {
    final (c, r) = s.eye;
    canvas.drawCircle(Offset(c.x, c.y), r, line);
  }
}

/// Unde stă peștele în casetă (unități de desen): de la coadă la cap, de sus până jos.
class FishFrame {
  FishFrame._(this.tail, this.head, this.top, this.bottom);

  final double tail, head, top, bottom;
  double get length => head - tail;
  Offset get center => Offset((tail + head) / 2, (top + bottom) / 2);

  static final _cache = <String, FishFrame>{};
  static FishFrame of(FishSpecies s) => _cache.putIfAbsent(s.id, () {
    var x0 = double.infinity, x1 = -double.infinity, y0 = double.infinity, y1 = -double.infinity;
    for (final c in s.shapes) {
      for (final p in sampleCurve(c, steps: 6)) {
        x0 = math.min(x0, p.x);
        x1 = math.max(x1, p.x);
        y0 = math.min(y0, p.y);
        y1 = math.max(y1, p.y);
      }
    }
    return FishFrame._(x0, x1, y0, y1);
  });
}

/// Peștele gata de înot: desenul copilului decupat după siluetă, cu volumul pictat peste
/// (lumină pe spate, umbră spre burtă și pe margini, luciu) și ochi vii. Conturul negru de
/// pe fișă devine o nuanță închisă a culorii de lângă el (peștele pare rotund, nu
/// decupat), iar înotătoarele lasă puțin lumina să treacă. Imaginea are jumătate din
/// rezoluția casetei (500×300).
Future<ui.Image> buildFishImage(FishSpecies s, ui.Image drawing) async {
  final body = FishBody.of(s);
  final w = body.width, h = body.height;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    drawing,
    Rect.fromLTWH(0, 0, drawing.width.toDouble(), drawing.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final small = await rec.endRecording().toImage(w, h);
  final src = (await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  small.dispose();
  final ink = await _lineMask(s, w, h);
  final edge = _edgeColors(src, ink, body, w, h);

  final out = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    var a = body.coverage[i];
    if (a == 0) continue;
    final l = body.light[i];
    var r = src[i * 4].toDouble(), g = src[i * 4 + 1].toDouble(), b = src[i * 4 + 2].toDouble();
    // Linia fișei → culoarea vecină, mai închisă.
    final m = ink[i] * 0.85;
    if (m > 0 && edge[i * 3] >= 0) {
      r += (edge[i * 3] * 0.5 - r) * m;
      g += (edge[i * 3 + 1] * 0.5 - g) * m;
      b += (edge[i * 3 + 2] * 0.56 - b) * m;
    }
    // Solzii: umbra de sub marginea fiecăruia și o sclipire pe muchie (doar o nuanță, culorile
    // copilului rămân).
    final sc = body.scales[i];
    if (sc != 0) {
      final f = 1 + sc * (sc < 0 ? 0.12 : 0.08);
      r *= f;
      g *= f;
      b *= f * (sc > 0 ? 1.02 : 1);
    }
    if (l < 0) {
      // Umbra: mai închis și puțin spre albastrul apei.
      final f = 1 + l * 0.55;
      r *= f * (1 + l * 0.1);
      g *= f;
      b *= f * (1 - l * 0.08);
    } else {
      final f = l * 0.6;
      r += (255 - r) * f;
      g += (255 - g) * f;
      b += (255 - b) * f;
      // Luciul umed are o irizare rece, ca solzii adevărați.
      if (l > 0.35) {
        final k = (l - 0.35) * 0.25;
        g += (255 - g) * k * 0.4;
        b += (255 - b) * k;
      }
    }
    if (body.fin[i] == 2) {
      // Conturul înotătoarei: o margine subțire, de culoarea ei, aproape transparentă.
      if (edge[i * 3] >= 0) {
        r = edge[i * 3] * 0.72;
        g = edge[i * 3 + 1] * 0.72;
        b = edge[i * 3 + 2] * 0.76;
        a *= 0.4;
      } else {
        a *= 0.08;
      }
    } else if (body.fin[i] > 0) {
      // Înotătoarea: membrană subțire între raze; spre vârf lasă tot mai multă lumină să treacă.
      final ray = body.rays[i], depth = body.finDepth[i];
      final dark = 1 - 0.24 * ray;
      r = r * dark + (235 - r * dark) * (0.1 + 0.18 * depth);
      g = g * dark + (250 - g * dark) * (0.1 + 0.18 * depth);
      b = b * dark + (255 - b * dark) * (0.1 + 0.18 * depth);
      a *= (0.92 - 0.3 * depth * (1 - ray * 0.6)).clamp(0.5, 1.0);
    }
    // Alfa premultiplicat: marginea moale rămâne închisă, fără halou deschis.
    out[i * 4] = (r.clamp(0, 255) * a).round();
    out[i * 4 + 1] = (g.clamp(0, 255) * a).round();
    out[i * 4 + 2] = (b.clamp(0, 255) * a).round();
    out[i * 4 + 3] = (a * 255).round();
  }
  final shaded = await _decode(out, w, h);

  // Detaliile pictate: operculul, linia laterală, gura, apoi ochiul.
  final rec2 = ui.PictureRecorder();
  final c = Canvas(rec2);
  c.drawImage(shaded, Offset.zero, Paint());
  c.scale(w / fishBox.width);
  paintFishDetails(c, s);
  shaded.dispose();
  return rec2.endRecording().toImage(w, h);
}

/// Detaliile care fac peștele „adevărat”, peste desenul copilului (unități de desen):
/// marginea operculului (de unde respiră), linia laterală (punctată, de-a lungul corpului),
/// buzele și ochiul (alb, iris cald, pupilă, două sclipiri, umbra pleoapei).
void paintFishDetails(Canvas c, FishSpecies s) {
  final frame = FishFrame.of(s);
  final (e, er) = s.eye;
  final eye = Offset(e.x, e.y);
  final bodyH = frame.bottom - frame.top;
  c.save();
  c.clipPath(curvePath(s.body));
  // Operculul: un arc în spatele ochiului, cu o umbră și o muchie luminată.
  final gill = Rect.fromCircle(center: eye + Offset(er * 0.9, er * 0.7), radius: er * 3.1);
  c.drawArc(
    gill,
    math.pi * 0.62,
    math.pi * 0.72,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = er * 0.42
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x2A0A1420),
  );
  c.drawArc(
    gill.deflate(er * 0.32),
    math.pi * 0.66,
    math.pi * 0.62,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = er * 0.16
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x30FFFFFF),
  );
  // Linia laterală: puncte mici, ușor curbate, de la opercul spre coadă.
  final fromX = gill.left + er * 0.6, toX = frame.tail + frame.length * 0.2;
  final lineY = frame.top + bodyH * 0.42;
  final dot = Paint()..color = const Color(0x38FFFFFF);
  for (var x = fromX; x > toX; x -= er * 0.75) {
    final t = (fromX - x) / (fromX - toX);
    c.drawCircle(Offset(x, lineY - math.sin(t * math.pi) * bodyH * 0.05 + t * bodyH * 0.06), er * 0.12, dot);
  }
  // Gura: buzele la vârful capului.
  final mouth = Offset(frame.head - er * 0.5, e.y + er * 1.45);
  c.drawPath(
    Path()
      ..moveTo(mouth.dx, mouth.dy - er * 0.15)
      ..quadraticBezierTo(mouth.dx - er * 0.7, mouth.dy + er * 0.25, mouth.dx - er * 1.3, mouth.dy + er * 0.05),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = er * 0.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x553A1E24),
  );
  c.restore();

  // Ochiul: adâncitura, albul, irisul cald, pupila spre cap, sclipirile.
  c.drawCircle(
    eye,
    er * 1.3,
    Paint()..shader = ui.Gradient.radial(eye, er * 1.3, const [Color(0x55000000), Color(0x22000000), Color(0x00000000)], const [0.6, 0.8, 1]),
  );
  c.drawCircle(eye, er * 0.98, Paint()..color = const Color(0xFFF7FAFC));
  final iris = eye + Offset(er * 0.2, er * 0.04);
  c.drawCircle(
    iris,
    er * 0.7,
    Paint()..shader = ui.Gradient.radial(iris, er * 0.7, const [Color(0xFF6B4A1E), Color(0xFFC9963E), Color(0xFF5A3A16)], const [0.45, 0.8, 1]),
  );
  c.drawCircle(
    iris + Offset(er * 0.05, 0),
    er * 0.44,
    Paint()..shader = ui.Gradient.radial(iris - Offset(er * 0.1, er * 0.1), er * 0.44, const [Color(0xFF242A36), Color(0xFF07080C)]),
  );
  // Umbra pleoapei de sus (ochiul pare rotund, nu lipit).
  c.save();
  c.clipPath(Path()..addOval(Rect.fromCircle(center: eye, radius: er * 0.98)));
  c.drawRect(
    Rect.fromLTWH(eye.dx - er, eye.dy - er, er * 2, er * 0.9),
    Paint()..shader = ui.Gradient.linear(eye - Offset(0, er), eye - Offset(0, er * 0.1), const [Color(0x40203040), Color(0x00203040)]),
  );
  c.restore();
  c.drawCircle(iris + Offset(er * 0.2, -er * 0.24), er * 0.2, Paint()..color = const Color(0xFFFFFFFF));
  c.drawCircle(iris + Offset(-er * 0.22, er * 0.24), er * 0.08, Paint()..color = const Color(0xCCFFFFFF));
}

/// Unde sunt liniile fișei (0…1), la rezoluția [w]×[h].
Future<Float32List> _lineMask(FishSpecies s, int w, int h) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(w / fishBox.width);
  paintLineArt(c, s, color: const Color(0xFFFFFFFF), eye: false);
  final img = await rec.endRecording().toImage(w, h);
  final px = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  img.dispose();
  return Float32List.fromList([for (var i = 0; i < w * h; i++) px[i * 4 + 3] / 255]);
}

/// Pentru fiecare pixel de pe linie: culoarea din interiorul peștelui de lângă el
/// (umplere din vecini, câțiva pași). −1 unde nu s-a găsit.
Float32List _edgeColors(Uint8List src, Float32List ink, FishBody body, int w, int h) {
  final col = Float32List(w * h * 3)..fillRange(0, w * h * 3, -1);
  var known = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    if (ink[i] < 0.25 && body.coverage[i] == 1 && body.thickness[i] > 0) {
      known[i] = 1;
      col[i * 3] = src[i * 4].toDouble();
      col[i * 3 + 1] = src[i * 4 + 1].toDouble();
      col[i * 3 + 2] = src[i * 4 + 2].toDouble();
    }
  }
  for (var pass = 0; pass < 12; pass++) {
    final next = Uint8List.fromList(known);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (known[i] == 1 || ink[i] == 0) continue;
        var r = 0.0, g = 0.0, b = 0.0, n = 0;
        for (final j in [i - 1, i + 1, i - w, i + w, i - w - 1, i - w + 1, i + w - 1, i + w + 1]) {
          if (known[j] == 0) continue;
          r += col[j * 3];
          g += col[j * 3 + 1];
          b += col[j * 3 + 2];
          n++;
        }
        if (n == 0) continue;
        col[i * 3] = r / n;
        col[i * 3 + 1] = g / n;
        col[i * 3 + 2] = b / n;
        next[i] = 1;
      }
    }
    known = next;
  }
  return col;
}

Future<ui.Image> _decode(Uint8List px, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// Peștele colorat de Licurici (cadoul de la început): culorile naturale ale modelului,
/// hașurate ca de mână, cu desenul fișei peste.
Future<ui.Image> paintGiftDrawing(FishSpecies s, {int seed = 1}) {
  final rnd = math.Random(seed);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & fishBox);
  c.drawRect(Offset.zero & fishBox, Paint()..color = const Color(0xFFFFFFFF));
  final body = curvePath(s.body);
  final fins = [for (final f in s.fins) curvePath(f)];

  void fill(Path p, Color col) {
    c.save();
    c.clipPath(p);
    c.drawPath(p, Paint()..color = col);
    // Urme de carioca: linii oblice puțin mai închise.
    final hatch = Paint()
      ..color = Color.lerp(col, const Color(0xFF000000), 0.08)!.withValues(alpha: 0.5)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final b = p.getBounds();
    for (var x = b.left - b.height; x < b.right; x += 16) {
      c.drawLine(Offset(x + rnd.nextDouble() * 4, b.bottom), Offset(x + b.height * 0.6, b.top), hatch);
    }
    c.restore();
  }

  void edge(Path p, Color col, double width) {
    c.save();
    c.clipPath(p);
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = col,
    );
    c.restore();
  }

  void bands(List<(double, double)> xs, Color col, {Color? rim}) {
    c.save();
    c.clipPath(body);
    for (final (x, half) in xs) {
      final band = Path()..addOval(Rect.fromCenter(center: Offset(x, 300), width: half * 2, height: 560));
      if (rim != null) {
        c.drawPath(
          band,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..color = rim,
        );
      }
      fill(band, col);
    }
    c.restore();
  }

  switch (s.id) {
    case 'inger':
      for (final f in fins) {
        fill(f, const Color(0xFFF6D35B));
        edge(f, const Color(0xFFB08A2A), 10);
      }
      fill(body, const Color(0xFFF3E7B0));
      bands([(700, 34), (520, 40), (360, 30)], const Color(0xFF2E2E36));
    case 'balon':
      for (final f in fins) {
        fill(f, const Color(0xFFF7E3A1));
      }
      fill(body, const Color(0xFFF2C14E));
      c.save();
      c.clipPath(body);
      fill(Path()..addOval(const Rect.fromLTRB(240, 330, 820, 640)), const Color(0xFFFFF4D6));
      for (var i = 0; i < 26; i++) {
        final p = Offset(300 + rnd.nextDouble() * 440, 110 + rnd.nextDouble() * 220);
        c.drawCircle(p, 9 + rnd.nextDouble() * 9, Paint()..color = const Color(0xFF9A6A3A));
      }
      c.restore();
    case 'chirurg':
      for (final f in fins) {
        fill(f, const Color(0xFF2F6FD6));
        edge(f, const Color(0xFF1F2340), 10);
      }
      fill(curvePath(s.fins[2]), const Color(0xFFF5C842));
      fill(body, const Color(0xFF3B82E6));
      c.save();
      c.clipPath(body);
      c.drawPath(
        Path()
          ..moveTo(820, 210)
          ..cubicTo(650, 150, 420, 200, 300, 300)
          ..cubicTo(430, 260, 600, 260, 700, 330)
          ..cubicTo(620, 250, 760, 230, 820, 210),
        Paint()..color = const Color(0xFF1F2340),
      );
      c.restore();
    case 'fluture':
      for (final f in fins) {
        fill(f, const Color(0xFFF7D23E));
        edge(f, const Color(0xFFF08A24), 14);
      }
      fill(curvePath(s.fins[2]), const Color(0xFFFFF3C4));
      fill(body, const Color(0xFFFBE27A));
      c.save();
      c.clipPath(body);
      // Dunga neagră prin ochi și „ochiul” fals de lângă coadă (sperie prădătorii).
      fill(Path()..addOval(Rect.fromCenter(center: const Offset(812, 300), width: 56, height: 420)), const Color(0xFF2E2E36));
      for (final (x, w) in [(520.0, 22.0), (600.0, 22.0), (680.0, 20.0)]) {
        c.drawLine(Offset(x, 140), Offset(x - 90, 470), Paint()
          ..color = const Color(0x55F08A24)
          ..strokeWidth = w);
      }
      c.drawCircle(const Offset(392, 236), 38, Paint()..color = const Color(0xFFFFFFFF));
      c.drawCircle(const Offset(392, 236), 28, Paint()..color = const Color(0xFF2E2E36));
      c.restore();
    case 'papagal':
      for (final f in fins) {
        fill(f, const Color(0xFFE86FA0));
        edge(f, const Color(0xFF7A5BD0), 12);
      }
      fill(body, const Color(0xFF3CC3A8));
      c.save();
      c.clipPath(body);
      fill(Path()..addOval(const Rect.fromLTRB(760, 120, 1000, 480)), const Color(0xFF7FDCC4));
      fill(Path()..addOval(const Rect.fromLTRB(880, 250, 990, 360)), const Color(0xFFF6E7C8));
      for (final (x, y) in [(470.0, 235.0), (630.0, 235.0), (550.0, 300.0), (390.0, 300.0), (480.0, 365.0)]) {
        c.drawCircle(Offset(x, y), 22, Paint()..color = const Color(0xAAF7B2D2));
      }
      c.restore();
    case 'rechin':
      for (final f in fins) {
        fill(f, const Color(0xFF5F86A6));
      }
      fill(body, const Color(0xFF7FA6C2));
      c.save();
      c.clipPath(body);
      fill(
        Path()
          ..moveTo(960, 340)
          ..cubicTo(800, 360, 500, 360, 220, 318)
          ..lineTo(220, 420)
          ..lineTo(960, 420)
          ..close(),
        const Color(0xFFF2F5F7),
      );
      c.restore();
    default: // clovn
      for (final f in fins) {
        fill(f, const Color(0xFFF58A1F));
        edge(f, const Color(0xFF2B2B2B), 14);
      }
      fill(body, const Color(0xFFF58A1F));
      bands([(770, 62), (535, 74), (262, 46)], const Color(0xFFFFFFFF), rim: const Color(0xFF2B2B2B));
  }
  paintLineArt(c, s);
  return rec.endRecording().toImage(fishBox.width.toInt(), fishBox.height.toInt());
}

/// Același desen cu culorile rotite pe cercul culorilor ([degrees]); negrul, albul și
/// griurile rămân (pentru pești „la fel, dar de altă culoare”).
Future<ui.Image> hueShifted(ui.Image src, double degrees) {
  final a = degrees * math.pi / 180, c = math.cos(a), s = math.sin(a);
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImage(
    src,
    Offset.zero,
    Paint()
      ..colorFilter = ColorFilter.matrix([
        0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
        0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
        0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
        0, 0, 0, 1, 0,
      ]),
  );
  return rec.endRecording().toImage(src.width, src.height);
}
