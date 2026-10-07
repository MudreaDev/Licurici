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
/// (lumină pe spate, umbră spre burtă, luciu) și ochi vii. Imaginea are jumătate din
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

  final out = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final a = body.coverage[i];
    if (a == 0) continue;
    final l = body.light[i];
    var r = src[i * 4].toDouble(), g = src[i * 4 + 1].toDouble(), b = src[i * 4 + 2].toDouble();
    if (l < 0) {
      // Umbra: mai închis și puțin spre albastrul apei.
      final f = 1 + l * 0.5;
      r *= f * (1 + l * 0.08);
      g *= f;
      b *= f * (1 - l * 0.06);
    } else {
      final f = l * 0.55;
      r += (255 - r) * f;
      g += (255 - g) * f;
      b += (255 - b) * f;
    }
    // Alfa premultiplicat: marginea moale rămâne închisă, fără halou deschis.
    out[i * 4] = (r.clamp(0, 255) * a).round();
    out[i * 4 + 1] = (g.clamp(0, 255) * a).round();
    out[i * 4 + 2] = (b.clamp(0, 255) * a).round();
    out[i * 4 + 3] = (a * 255).round();
  }
  final shaded = await _decode(out, w, h);

  // Ochii: albul, pupila spre cap, sclipirea.
  final rec2 = ui.PictureRecorder();
  final c = Canvas(rec2);
  c.drawImage(shaded, Offset.zero, Paint());
  c.scale(w / fishBox.width);
  final (e, er) = s.eye;
  final eye = Offset(e.x, e.y);
  c.drawCircle(eye, er * 1.05, Paint()..color = _ink);
  c.drawCircle(eye, er * 0.88, Paint()..color = const Color(0xFFFFFFFF));
  final pupil = eye + Offset(er * 0.22, er * 0.04);
  c.drawCircle(pupil, er * 0.55, Paint()..color = const Color(0xFF1B1B22));
  c.drawCircle(pupil + Offset(er * 0.18, -er * 0.2), er * 0.19, Paint()..color = const Color(0xFFFFFFFF));
  c.drawCircle(pupil + Offset(-er * 0.2, er * 0.22), er * 0.08, Paint()..color = const Color(0xCCFFFFFF));
  shaded.dispose();
  return rec2.endRecording().toImage(w, h);
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
        edge(f, const Color(0xFF2B2B2B), 22);
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
        edge(f, const Color(0xFF1F2340), 20);
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
    default: // clovn
      for (final f in fins) {
        fill(f, const Color(0xFFF58A1F));
        edge(f, const Color(0xFF2B2B2B), 30);
      }
      fill(body, const Color(0xFFF58A1F));
      bands([(770, 62), (535, 74), (262, 46)], const Color(0xFFFFFFFF), rim: const Color(0xFF2B2B2B));
  }
  paintLineArt(c, s);
  return rec.endRecording().toImage(fishBox.width.toInt(), fishBox.height.toInt());
}
