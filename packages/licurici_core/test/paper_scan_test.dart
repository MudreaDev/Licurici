import 'dart:math';
import 'dart:typed_data';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

/// Fișa „printată”, colorată: corp roșu, înotătoare albastre, la 4 px/mm.
(Uint8List, int, int) _sheet(FishSpecies s) {
  const ppm = 4;
  final w = (PaperSheet.width * ppm).round(), h = (PaperSheet.height * ppm).round();
  final px = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 255);
  void rect(double x, double y, double sw, double sh, int v) {
    for (var j = (y * ppm).round(); j < ((y + sh) * ppm).round(); j++) {
      for (var i = (x * ppm).round(); i < ((x + sw) * ppm).round(); i++) {
        px.fillRange((j * w + i) * 3, (j * w + i) * 3 + 3, v);
      }
    }
  }

  for (final c in PaperSheet.corners) {
    const m = PaperSheet.marker, u = m / 7;
    rect(c.x - m / 2, c.y - m / 2, m, m, 0);
    rect(c.x - m / 2 + u, c.y - m / 2 + u, m - 2 * u, m - 2 * u, 255);
    rect(c.x - 1.5 * u, c.y - 1.5 * u, 3 * u, 3 * u, 0);
  }
  for (final (x, y, size, black) in PaperSheet.codeCells(s)) {
    if (black) rect(x, y, size, size, 0);
  }
  bool inside(List<Point<double>> poly, Point<double> p) {
    var c = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) c = !c;
    }
    return c;
  }

  final body = sampleCurve(s.body), fins = [for (final f in s.fins) sampleCurve(f)];
  final x0 = PaperSheet.boxLeft, y0 = PaperSheet.boxTop, k = PaperSheet.boxScale;
  for (var j = (y0 * ppm).floor(); j < ((y0 + 600 * k) * ppm).ceil(); j++) {
    for (var i = (x0 * ppm).floor(); i < ((x0 + 1000 * k) * ppm).ceil(); i++) {
      final p = Point((i / ppm - x0) / k, (j / ppm - y0) / k);
      final o = (j * w + i) * 3;
      if (inside(body, p)) {
        px.setAll(o, [220, 40, 40]);
      } else if (fins.any((f) => inside(f, p))) {
        px.setAll(o, [40, 80, 220]);
      }
    }
  }
  return (px, w, h);
}

/// O „fotografie” a fișei: pe o masă maro, în perspectivă, cu lumină inegală și zgomot.
Uint8List _photo((Uint8List, int, int) sheet, List<Point<double>> quad, int w, int h, {int seed = 1}) {
  final (src, sw, sh) = sheet;
  final toSheet = homography(quad, [
    const Point(0, 0),
    const Point(PaperSheet.width, 0),
    const Point(PaperSheet.width, PaperSheet.height),
    const Point(0, PaperSheet.height),
  ])!;
  final rnd = Random(seed);
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = applyHomography(toSheet, x + 0.5, y + 0.5);
      final i = (p.x * sw / PaperSheet.width).floor(), j = (p.y * sh / PaperSheet.height).floor();
      var rgb = [120, 90, 60];
      if (i >= 0 && j >= 0 && i < sw && j < sh) rgb = src.sublist((j * sw + i) * 3, (j * sw + i) * 3 + 3);
      final light = 0.62 + 0.38 * x / w;
      final tint = [1.0, 0.96, 0.86];
      final o = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        out[o + c] = (rgb[c] * light * tint[c] + rnd.nextInt(13) - 6).round().clamp(0, 255);
      }
      out[o + 3] = 255;
    }
  }
  return out;
}

List<int> _at(Uint8List d, int u, int v) => d.sublist((v * 1000 + u) * 4, (v * 1000 + u) * 4 + 3);

void main() {
  const w = 1200, h = 900;
  const quad = [Point(150.0, 120.0), Point(1080.0, 175.0), Point(1030.0, 820.0), Point(110.0, 760.0)];

  for (final s in fishSpecies) {
    test('${s.id}: fișa fotografiată strâmb, cu lumină inegală, e găsită și decupată', () {
      final r = scanPaper(_photo(_sheet(s), quad, w, h), w, h);
      expect(r.ok, isTrue, reason: '${r.problem}');
      expect(r.species, s);
      // Marcajele găsite = centrele marcajelor de pe fișă, duse în fotografie.
      final toPhoto = homography(const [
        Point(0, 0),
        Point(PaperSheet.width, 0),
        Point(PaperSheet.width, PaperSheet.height),
        Point(0, PaperSheet.height),
      ], quad)!;
      for (final (c, m) in zip(r.corners!, PaperSheet.corners)) {
        expect(c.distanceTo(applyHomography(toPhoto, m.x, m.y)), lessThan(3));
      }
      // Corpul iese roșu, înotătoarea albastră, hârtia albă — și în partea întunecată.
      final (eye, _) = s.eye;
      final body = _at(r.drawing!, (eye.x - 180).round(), eye.y.round());
      expect(body[0], greaterThan(170));
      expect(body[1], lessThan(110));
      // Aproape de vârful înotătoarei de sus (mijlocul ei poate cădea peste corp).
      final tip = s.fins.first.reduce((a, b) => a.y < b.y ? a : b);
      final f = Point(tip.x, tip.y + 18);
      final fc = _at(r.drawing!, f.x.round(), f.y.round());
      expect(fc[2], greaterThan(150));
      expect(fc[0], lessThan(120));
      for (final paper in [_at(r.drawing!, 20, 20), _at(r.drawing!, 980, 580)]) {
        expect(paper.every((c) => c > 215), isTrue, reason: '$paper');
      }
    });
  }

  test('fișa ținută invers (rotită 180°) e recunoscută', () {
    final s = fishSpeciesById('balon')!;
    final upside = [quad[2], quad[3], quad[0], quad[1]];
    final r = scanPaper(_photo(_sheet(s), upside, w, h, seed: 4), w, h);
    expect(r.ok, isTrue);
    expect(r.species, s);
  });

  test('fără fișă în poză: o problemă blândă, nu o eroare', () {
    final rnd = Random(3);
    final px = Uint8List(400 * 300 * 4);
    for (var i = 0; i < px.length; i++) {
      px[i] = i % 4 == 3 ? 255 : 100 + rnd.nextInt(60);
    }
    expect(scanPaper(px, 400, 300).problem, ScanProblem.noSheet);
  });
}

Iterable<(A, B)> zip<A, B>(List<A> a, List<B> b) sync* {
  for (var i = 0; i < min(a.length, b.length); i++) {
    yield (a[i], b[i]);
  }
}
