/// Acvariul pe hârtie (ADR-030): geometria fișei A4 de colorat și găsirea ei într-o
/// fotografie. Totul e Dart pur, fără OpenCV: binarizare adaptivă → componente conexe →
/// marcajele din colțuri (pătrat negru, inel alb, miez negru — perechi concentrice) →
/// omografie → codul modelului → decuparea peștelui cu lumina egalizată după hârtia albă.
///
/// Fotografia nu se păstrează; rezultatul e doar desenul peștelui, 1000×600, ca la
/// colorarea pe ecran.
library;

import 'dart:math';
import 'dart:typed_data';

import 'aquarium_fish.dart';

/// Fișa A4 landscape, în milimetri (originea stânga-sus).
abstract final class PaperSheet {
  static const double width = 297, height = 210;

  /// Latura marcajului: inel negru 1, inel alb 1, miez negru 3, inel alb 1, inel negru 1.
  static const double marker = 24;
  static const double markerMargin = 12;

  /// Centrele marcajelor: stânga-sus, dreapta-sus, dreapta-jos, stânga-jos.
  static const corners = [
    Point<double>(markerMargin + marker / 2, markerMargin + marker / 2),
    Point<double>(width - markerMargin - marker / 2, markerMargin + marker / 2),
    Point<double>(width - markerMargin - marker / 2, height - markerMargin - marker / 2),
    Point<double>(markerMargin + marker / 2, height - markerMargin - marker / 2),
  ];

  /// Codul modelului: o celulă de start (mereu neagră) + 4 biți, sus, între marcaje.
  static const double cell = 8, cellGap = 2, codeTop = 14;
  static const int bits = 4;
  static double get _codeLeft => width / 2 - (5 * cell + 4 * cellGap) / 2;

  /// Celulele codului pentru modelul [species]: (x, y, latură, neagră?).
  static List<(double, double, double, bool)> codeCells(FishSpecies species) {
    final value = fishSpecies.indexOf(species) + 1;
    return [
      for (var i = 0; i <= bits; i++)
        (_codeLeft + i * (cell + cellGap), codeTop, cell, i == 0 || (value >> (bits - i)) & 1 == 1),
    ];
  }

  /// Caseta peștelui (1000×600 unități de desen) pe fișă: colțul și mm pe unitate.
  static const double boxScale = 0.23, boxTop = 50;
  static double get boxLeft => (width - FishSpecies.boxWidth * boxScale) / 2;

  /// Unde stă titlul (numele peștelui) — centrul.
  static const titleCenter = Point<double>(width / 2, 38);

  static Point<double> boxToSheet(double u, double v) => Point(boxLeft + u * boxScale, boxTop + v * boxScale);
}

/// De ce n-a mers scanarea (copilul primește un mesaj blând, nu o eroare).
enum ScanProblem {
  /// Nu se văd cele patru pătrate din colțuri.
  noSheet,

  /// Se văd colțurile, dar codul peștelui nu se poate citi.
  unknownFish,
}

class ScanResult {
  const ScanResult._({this.species, this.drawing, this.corners, this.problem});

  final FishSpecies? species;

  /// Desenul peștelui, RGBA 1000×600 (ca pânza de colorat).
  final Uint8List? drawing;

  /// Unde s-au găsit marcajele în fotografie (stânga-sus, dreapta-sus, dreapta-jos, stânga-jos).
  final List<Point<double>>? corners;
  final ScanProblem? problem;

  bool get ok => problem == null;
}

/// Caută fișa în fotografia [rgba] ([width]×[height]) și decupează peștele.
ScanResult scanPaper(Uint8List rgba, int width, int height) {
  // Detectarea pe o copie mică (≈ 900 px pe latura lungă): rapidă și destul de precisă.
  final k = min(1.0, 900 / max(width, height));
  final dw = max(1, (width * k).round()), dh = max(1, (height * k).round());
  final lum = _luminance(rgba, width, height, dw, dh);
  final markers = _findMarkers(lum, dw, dh);
  if (markers.length < 4) return const ScanResult._(problem: ScanProblem.noSheet);
  final quad = _bestQuad(markers);
  if (quad == null) return const ScanResult._(problem: ScanProblem.noSheet);

  // Încercăm cele patru rotiri; cea bună are celula de start neagră și un cod valid.
  for (var r = 0; r < 4; r++) {
    final ordered = [for (var i = 0; i < 4; i++) quad[(i + r) % 4]];
    final hDet = _homography(PaperSheet.corners, ordered);
    if (hDet == null) continue;
    final species = _readCode(lum, dw, dh, hDet);
    if (species == null) continue;
    final full = [for (final p in ordered) Point(p.x / k, p.y / k)];
    final h = _homography(PaperSheet.corners, full)!;
    return ScanResult._(species: species, drawing: _extract(rgba, width, height, h, species), corners: full);
  }
  return ScanResult._(problem: ScanProblem.unknownFish, corners: [for (final p in quad) Point(p.x / k, p.y / k)]);
}

// ---------------------------------------------------------------------------------------
// Luminanța, micșorată prin medierea blocurilor.

Float32List _luminance(Uint8List rgba, int w, int h, int dw, int dh) {
  final out = Float32List(dw * dh);
  final cnt = Int32List(dw * dh);
  for (var y = 0; y < h; y++) {
    final ty = min<int>(dh - 1, y * dh ~/ h);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final t = ty * dw + min<int>(dw - 1, x * dw ~/ w);
      out[t] += 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
      cnt[t]++;
    }
  }
  for (var i = 0; i < out.length; i++) {
    if (cnt[i] > 0) out[i] /= cnt[i];
  }
  return out;
}

// ---------------------------------------------------------------------------------------
// Marcajele: componente negre (după un prag adaptiv) care au în mijloc altă componentă
// neagră, de ~3/7 din mărimea lor.

class _Blob {
  int minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1, area = 0;
  double sx = 0, sy = 0;
  int get w => maxX - minX + 1;
  int get h => maxY - minY + 1;
  double get cx => sx / area;
  double get cy => sy / area;
  double get size => (w + h) / 2;
}

List<(Point<double>, double)> _findMarkers(Float32List lum, int w, int h) {
  // Prag adaptiv cu imaginea integrală: negru = mai închis decât media vecinătății.
  final integral = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      row += lum[y * w + x];
      integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
    }
  }
  final r = max(8, max(w, h) ~/ 40);
  final dark = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = max(0, y - r), y1 = min(h, y + r + 1);
    for (var x = 0; x < w; x++) {
      final x0 = max(0, x - r), x1 = min(w, x + r + 1);
      final sum = integral[y1 * (w + 1) + x1] - integral[y0 * (w + 1) + x1] - integral[y1 * (w + 1) + x0] + integral[y0 * (w + 1) + x0];
      final mean = sum / ((x1 - x0) * (y1 - y0));
      final v = lum[y * w + x];
      if (v < mean * 0.8 && v < 150) dark[y * w + x] = 1;
    }
  }

  // Componente conexe (8 vecini).
  final label = Int32List(w * h)..fillRange(0, w * h, -1);
  final blobs = <_Blob>[];
  final stack = <int>[];
  for (var i = 0; i < w * h; i++) {
    if (dark[i] == 0 || label[i] >= 0) continue;
    final b = _Blob();
    final id = blobs.length;
    blobs.add(b);
    label[i] = id;
    stack.add(i);
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final px = p % w, py = p ~/ w;
      b
        ..area += 1
        ..sx += px
        ..sy += py
        ..minX = min(b.minX, px)
        ..maxX = max(b.maxX, px)
        ..minY = min(b.minY, py)
        ..maxY = max(b.maxY, py);
      for (var dy = -1; dy <= 1; dy++) {
        final ny = py + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = px + dx;
          if (nx < 0 || nx >= w) continue;
          final q = ny * w + nx;
          if (dark[q] == 1 && label[q] < 0) {
            label[q] = id;
            stack.add(q);
          }
        }
      }
    }
  }

  final rings = [
    for (final b in blobs)
      if (b.w >= 9 && b.h >= 9 && b.w / b.h > 0.4 && b.w / b.h < 2.5 && b.area / (b.w * b.h) > 0.2 && b.area / (b.w * b.h) < 0.8) b,
  ];
  final cores = [
    for (final b in blobs)
      if (b.w >= 3 && b.h >= 3 && b.area / (b.w * b.h) > 0.5) b,
  ];
  final found = <(Point<double>, double)>[];
  for (final ring in rings) {
    final rcx = (ring.minX + ring.maxX) / 2, rcy = (ring.minY + ring.maxY) / 2;
    for (final c in cores) {
      if (identical(c, ring)) continue;
      final ratio = c.size / ring.size;
      if (ratio < 0.25 || ratio > 0.65) continue;
      if (c.minX <= ring.minX || c.maxX >= ring.maxX || c.minY <= ring.minY || c.maxY >= ring.maxY) continue;
      if ((c.cx - rcx).abs() > ring.w * 0.15 || (c.cy - rcy).abs() > ring.h * 0.15) continue;
      found.add((Point(c.cx, c.cy), ring.size));
      break;
    }
  }
  return found;
}

/// Patru marcaje care formează cel mai mare patrulater convex, ordonate în sensul acelor
/// de ceasornic începând cu cel mai apropiat de colțul stânga-sus al fotografiei.
List<Point<double>>? _bestQuad(List<(Point<double>, double)> markers) {
  final cand = List.of(markers)..sort((a, b) => b.$2.compareTo(a.$2));
  final top = cand.take(10).toList();
  List<Point<double>>? best;
  var bestArea = 0.0;
  for (var a = 0; a < top.length; a++) {
    for (var b = a + 1; b < top.length; b++) {
      for (var c = b + 1; c < top.length; c++) {
        for (var d = c + 1; d < top.length; d++) {
          final group = [top[a], top[b], top[c], top[d]];
          final sizes = group.map((g) => g.$2);
          if (sizes.reduce(max) / sizes.reduce(min) > 2.5) continue;
          final pts = _clockwise([for (final g in group) g.$1]);
          final area = _convexArea(pts);
          if (area > bestArea) {
            bestArea = area;
            best = pts;
          }
        }
      }
    }
  }
  return best;
}

List<Point<double>> _clockwise(List<Point<double>> pts) {
  final cx = pts.map((p) => p.x).reduce((a, b) => a + b) / pts.length;
  final cy = pts.map((p) => p.y).reduce((a, b) => a + b) / pts.length;
  final s = List.of(pts)..sort((a, b) => atan2(a.y - cy, a.x - cx).compareTo(atan2(b.y - cy, b.x - cx)));
  // În imagine (y în jos), unghiul crescător merge în sensul acelor de ceasornic.
  var first = 0;
  for (var i = 1; i < 4; i++) {
    if (s[i].x + s[i].y < s[first].x + s[first].y) first = i;
  }
  return [for (var i = 0; i < 4; i++) s[(first + i) % 4]];
}

/// Aria patrulaterului; 0 dacă nu e convex.
double _convexArea(List<Point<double>> p) {
  var sign = 0;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    final s = cross.sign.toInt();
    if (sign == 0) sign = s;
    if (s != sign) return 0;
    area += a.x * b.y - b.x * a.y;
  }
  return area.abs() / 2;
}

// ---------------------------------------------------------------------------------------
// Omografia: din punctele fișei (mm) în punctele fotografiei.

typedef _H = List<double>;

/// Omografia care duce cele 4 puncte [from] în [to] (coeficienții h0…h8, h8 = 1).
List<double>? homography(List<Point<double>> from, List<Point<double>> to) => _homography(from, to);

/// Aplică omografia [h] punctului (x, y).
Point<double> applyHomography(List<double> h, double x, double y) => _apply(h, x, y);

_H? _homography(List<Point<double>> from, List<Point<double>> to) {
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = from[i].x, y = from[i].y, u = to[i].x, v = to[i].y;
    a[2 * i]
      ..setAll(0, [x, y, 1, 0, 0, 0, -u * x, -u * y])
      ..[8] = u;
    a[2 * i + 1]
      ..setAll(0, [0, 0, 0, x, y, 1, -v * x, -v * y])
      ..[8] = v;
  }
  for (var c = 0; c < 8; c++) {
    var p = c;
    for (var r = c + 1; r < 8; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    if (a[p][c].abs() < 1e-12) return null;
    final t = a[c];
    a[c] = a[p];
    a[p] = t;
    for (var r = 0; r < 8; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      for (var k = c; k < 9; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [for (var r = 0; r < 8; r++) a[r][8] / a[r][r], 1];
}

Point<double> _apply(_H h, double x, double y) {
  final d = h[6] * x + h[7] * y + h[8];
  return Point((h[0] * x + h[1] * y + h[2]) / d, (h[3] * x + h[4] * y + h[5]) / d);
}

double _sampleLum(Float32List lum, int w, int h, Point<double> p) {
  final x = p.x.clamp(0, w - 1.001).toDouble(), y = p.y.clamp(0, h - 1.001).toDouble();
  final i = x.floor(), j = y.floor(), fx = x - i, fy = y - j, k = j * w + i;
  final i1 = min(i + 1, w - 1) - i, j1 = (min(j + 1, h - 1) - j) * w;
  return (lum[k] * (1 - fx) + lum[k + i1] * fx) * (1 - fy) + (lum[k + j1] * (1 - fx) + lum[k + j1 + i1] * fx) * fy;
}

/// Citește codul modelului; null dacă celula de start nu e neagră sau codul nu există.
FishSpecies? _readCode(Float32List lum, int w, int h, _H hm) {
  double cellLum(double x, double y, double s) {
    var sum = 0.0;
    for (var a = 1; a <= 3; a++) {
      for (var b = 1; b <= 3; b++) {
        sum += _sampleLum(lum, w, h, _apply(hm, x + s * a / 4, y + s * b / 4));
      }
    }
    return sum / 9;
  }

  // Referințele: miezul unui marcaj (negru) și hârtia de lângă cod (alb).
  final black = (cellLum(PaperSheet.corners[0].x - 3, PaperSheet.corners[0].y - 3, 6) +
          cellLum(PaperSheet.corners[1].x - 3, PaperSheet.corners[1].y - 3, 6)) /
      2;
  final white = (cellLum(70, 14, 8) + cellLum(PaperSheet.width - 78, 14, 8)) / 2;
  if (white - black < 25) return null;
  final mid = (white + black) / 2;
  final cells = PaperSheet.codeCells(fishSpecies.first);
  var value = 0;
  for (final (i, (x, y, s, _)) in cells.indexed) {
    final isBlack = cellLum(x, y, s) < mid;
    if (i == 0) {
      if (!isBlack) return null;
    } else {
      value = value << 1 | (isBlack ? 1 : 0);
    }
  }
  if (value < 1 || value > fishSpecies.length) return null;
  return fishSpecies[value - 1];
}

// ---------------------------------------------------------------------------------------
// Decuparea: caseta peștelui îndreptată (1000×600) și lumina egalizată după hârtie.

Uint8List _extract(Uint8List rgba, int w, int h, _H hm, FishSpecies species) {
  const ow = 1000, oh = 600;
  final out = Uint8List(ow * oh * 4);
  for (var v = 0; v < oh; v++) {
    for (var u = 0; u < ow; u++) {
      final s = PaperSheet.boxToSheet(u + 0.5, v + 0.5);
      final p = _apply(hm, s.x, s.y);
      final x = p.x.clamp(0, w - 1.001).toDouble(), y = p.y.clamp(0, h - 1.001).toDouble();
      final i = x.floor(), j = y.floor(), fx = x - i, fy = y - j;
      final i1 = min(i + 1, w - 1), j1 = min(j + 1, h - 1);
      final o = (v * ow + u) * 4;
      for (var c = 0; c < 3; c++) {
        final a = rgba[(j * w + i) * 4 + c], b = rgba[(j * w + i1) * 4 + c];
        final d = rgba[(j1 * w + i) * 4 + c], e = rgba[(j1 * w + i1) * 4 + c];
        out[o + c] = ((a * (1 - fx) + b * fx) * (1 - fy) + (d * (1 - fx) + e * fx) * fy).round();
      }
      out[o + 3] = 255;
    }
  }
  _evenLight(out, ow, oh, species);
  return out;
}

/// Hârtia din jurul peștelui ar trebui să fie albă: măsurăm cât de albă e pe zone (lumina
/// din cameră nu e uniformă) și împărțim, ca culorile copilului să iasă ca pe hârtie.
void _evenLight(Uint8List px, int w, int h, FishSpecies species) {
  final body = FishBody.of(species);
  final bw = body.width, bh = body.height;
  bool paper(int u, int v) {
    final bu = u * bw ~/ w, bv = v * bh ~/ h;
    for (var dy = -3; dy <= 3; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        final x = bu + dx, y = bv + dy;
        if (x < 0 || y < 0 || x >= bw || y >= bh) continue;
        if (body.coverage[y * bw + x] > 0) return false;
      }
    }
    return true;
  }

  const gx = 10, gy = 6;
  final cells = List<List<double>?>.filled(gx * gy, null);
  // Pentru fiecare zonă: culoarea celor mai luminoși pixeli de hârtie (hârtia, nu creionul).
  final samples = List.generate(gx * gy, (_) => <(double, int)>[]);
  for (var v = 0; v < h; v += 3) {
    for (var u = 0; u < w; u += 3) {
      if (!paper(u, v)) continue;
      final o = (v * w + u) * 4;
      final l = 0.299 * px[o] + 0.587 * px[o + 1] + 0.114 * px[o + 2];
      samples[(v * gy ~/ h) * gx + u * gx ~/ w].add((l, o));
    }
  }
  for (var c = 0; c < gx * gy; c++) {
    final s = samples[c];
    if (s.length < 12) continue;
    s.sort((a, b) => b.$1.compareTo(a.$1));
    final top = s.take(max(6, s.length ~/ 3));
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (final (_, o) in top) {
      r += px[o];
      g += px[o + 1];
      b += px[o + 2];
      n++;
    }
    cells[c] = [r / n, g / n, b / n];
  }
  // Zonele fără hârtie (sub pește) iau media vecinilor, din aproape în aproape.
  for (var pass = 0; pass < gx + gy && cells.contains(null); pass++) {
    for (var c = 0; c < gx * gy; c++) {
      if (cells[c] != null) continue;
      final cx = c % gx, cy = c ~/ gx;
      final near = <List<double>>[
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
          if (cx + dx >= 0 && cx + dx < gx && cy + dy >= 0 && cy + dy < gy && cells[(cy + dy) * gx + cx + dx] != null)
            cells[(cy + dy) * gx + cx + dx]!,
      ];
      if (near.isEmpty) continue;
      cells[c] = [for (var k = 0; k < 3; k++) near.map((n) => n[k]).reduce((a, b) => a + b) / near.length];
    }
  }
  if (cells.contains(null)) return;
  for (var v = 0; v < h; v++) {
    final fy = ((v + 0.5) / h * gy - 0.5).clamp(0.0, gy - 1.0);
    final y0 = fy.floor(), y1 = min(y0 + 1, gy - 1), ty = fy - y0;
    for (var u = 0; u < w; u++) {
      final fx = ((u + 0.5) / w * gx - 0.5).clamp(0.0, gx - 1.0);
      final x0 = fx.floor(), x1 = min(x0 + 1, gx - 1), tx = fx - x0;
      final o = (v * w + u) * 4;
      for (var k = 0; k < 3; k++) {
        final white = (cells[y0 * gx + x0]![k] * (1 - tx) + cells[y0 * gx + x1]![k] * tx) * (1 - ty) +
            (cells[y1 * gx + x0]![k] * (1 - tx) + cells[y1 * gx + x1]![k] * tx) * ty;
        // Puțin contrast în plus: fotografiile spală culorile de carioca.
        final c = (px[o + k] / max(white, 40.0)).clamp(0.0, 1.0);
        px[o + k] = (pow(c, 1.15) * 255).round();
      }
    }
  }
}
