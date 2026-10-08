/// Peștii acvariului (README §2, „Acvariul”): modelele de colorat și volumul lor.
///
/// Fiecare model e un contur desenat de mână (puncte de control ale unor curbe Catmull-Rom
/// închise, într-o casetă 1000×600, capul spre dreapta). Din același contur ies fișa de
/// colorat și peștele care înoată: corpul primește „volum” după distanța față de margine,
/// iar lumina calculată din volum se pictează peste desenul copilului (fără shadere,
/// ADR-028).
library;

import 'dart:math';
import 'dart:typed_data';

/// Un model de pește pentru colorat.
class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.name,
    required this.thickness,
    required this.swim,
    required this.body,
    required this.fins,
    required this.details,
    required this.eye,
  });

  final String id;

  /// Numele articulat, pentru fișă și voce.
  final String name;

  /// Cât de bombat e corpul (0.05 = turtit, 0.17 = rotund).
  final double thickness;

  /// Cât de tare dă din coadă (0.5 = calm, 1.5 = agitat).
  final double swim;
  final List<Point<double>> body;
  final List<List<Point<double>>> fins;

  /// Linii interioare deschise (înotătoarea pectorală, opercul, gura).
  final List<List<Point<double>>> details;

  /// Ochiul: centrul și raza (unități de desen).
  final (Point<double>, double) eye;

  static const double boxWidth = 1000, boxHeight = 600;

  /// Grosimea conturului exterior pe fișă și a liniilor interioare (unități de desen).
  /// Conturul exterior se desenează doar în afara siluetei.
  static const double outlineWidth = 5, detailWidth = 5;

  /// Corpul și înotătoarele: formele închise a căror reuniune e silueta.
  List<List<Point<double>>> get shapes => [body, ...fins];
}

List<Point<double>> _p(List<List<num>> xs) => [for (final x in xs) Point(x[0].toDouble(), x[1].toDouble())];

/// Modelele de pești. Contururi originale ale proiectului.
final fishSpecies = <FishSpecies>[
  FishSpecies(
    id: 'clovn',
    name: 'peștele-clovn',
    thickness: 0.085,
    swim: 1,
    body: _p([
      [930, 318], [885, 232], [790, 178], [650, 158], [505, 165], [365, 195], [262, 243], [192, 280], //
      [192, 342], [262, 380], [382, 428], [522, 452], [662, 446], [792, 416], [890, 372],
    ]),
    fins: [
      _p([[735, 195], [700, 118], [628, 82], [552, 92], [508, 132], [470, 108], [398, 108], [330, 150], //
        [302, 220], [500, 205], [700, 205]]),
      _p([[238, 252], [152, 196], [72, 176], [36, 228], [30, 310], [36, 392], [72, 444], [152, 424], [238, 368]]),
      _p([[440, 425], [388, 470], [366, 522], [414, 534], [472, 502], [505, 440]]),
      _p([[655, 438], [632, 500], [592, 545], [566, 528], [586, 470], [602, 436]]),
    ],
    details: [
      _p([[740, 180], [650, 158], [505, 165], [365, 195], [292, 232]]),
      _p([[232, 256], [220, 310], [232, 364]]),
      _p([[728, 318], [668, 282], [620, 318], [662, 372], [728, 340]]),
      _p([[792, 196], [760, 300], [792, 404]]),
      _p([[928, 334], [902, 340]]),
    ],
    eye: (const Point(846, 268), 26),
  ),
  FishSpecies(
    id: 'inger',
    name: 'peștele-înger',
    thickness: 0.05,
    swim: 0.7,
    body: _p([
      [884, 300], [826, 228], [722, 168], [600, 150], [482, 175], [382, 230], [302, 282], [302, 320], //
      [382, 372], [482, 425], [600, 450], [722, 432], [826, 372],
    ]),
    fins: [
      _p([[700, 180], [622, 102], [522, 42], [424, 26], [384, 62], [402, 122], [362, 214], [482, 196], [652, 192]]),
      _p([[700, 422], [602, 498], [502, 558], [412, 574], [382, 540], [412, 480], [372, 388], [502, 406], //
        [652, 412]]),
      _p([[324, 268], [242, 228], [172, 214], [152, 300], [172, 386], [242, 372], [324, 332]]),
      _p([[650, 440], [604, 518], [568, 574], [552, 568], [576, 500], [604, 438]]),
    ],
    details: [
      _p([[712, 190], [600, 152], [482, 176], [384, 230], [352, 256]]),
      _p([[712, 412], [600, 450], [482, 424], [384, 370], [352, 344]]),
      _p([[318, 274], [310, 300], [318, 326]]),
      _p([[700, 300], [652, 276], [622, 304], [652, 336], [700, 316]]),
      _p([[770, 200], [744, 300], [770, 400]]),
      _p([[882, 312], [860, 318]]),
    ],
    eye: (const Point(806, 266), 22),
  ),
  FishSpecies(
    id: 'balon',
    name: 'peștele-balon',
    thickness: 0.17,
    swim: 0.5,
    body: _p([
      [792, 300], [760, 215], [690, 140], [590, 98], [480, 96], [380, 130], [300, 195], [262, 260], //
      [258, 330], [290, 400], [370, 468], [480, 505], [600, 500], [700, 455], [765, 385],
    ]),
    fins: [
      _p([[300, 250], [220, 205], [150, 190], [128, 250], [132, 300], [128, 352], [150, 410], [220, 395], //
        [300, 350]]),
      _p([[462, 112], [424, 54], [368, 40], [340, 72], [362, 120], [404, 142]]),
      _p([[404, 466], [362, 528], [330, 548], [316, 520], [348, 470], [392, 452]]),
    ],
    details: [
      _p([[296, 252], [286, 300], [296, 348]]),
      _p([[466, 104], [420, 112], [372, 130]]),
      _p([[410, 478], [372, 466], [340, 446]]),
      _p([[640, 302], [598, 256], [562, 282], [572, 334], [640, 322]]),
      _p([[790, 318], [768, 324]]),
    ],
    eye: (const Point(690, 236), 32),
  ),
  FishSpecies(
    id: 'chirurg',
    name: 'peștele-chirurg',
    thickness: 0.07,
    swim: 0.9,
    body: _p([
      [900, 300], [860, 235], [780, 170], [660, 130], [530, 128], [410, 160], [310, 225], [250, 275], //
      [250, 325], [310, 375], [410, 440], [530, 472], [660, 470], [780, 430], [860, 365],
    ]),
    fins: [
      _p([[800, 176], [740, 120], [620, 88], [500, 90], [390, 118], [300, 176], [262, 240], [330, 230], //
        [450, 172], [600, 142], [760, 190]]),
      _p([[720, 426], [620, 472], [500, 502], [400, 486], [300, 426], [262, 360], [330, 372], [450, 436], //
        [600, 460], [760, 412]]),
      _p([[262, 262], [190, 200], [110, 140], [88, 172], [150, 300], [88, 428], [110, 460], [190, 400], //
        [262, 338]]),
      _p([[700, 440], [680, 502], [650, 522], [638, 500], [660, 446]]),
    ],
    details: [
      _p([[806, 180], [660, 132], [530, 130], [410, 162], [300, 228], [270, 254]]),
      _p([[806, 420], [660, 468], [530, 470], [410, 438], [300, 372], [270, 346]]),
      _p([[262, 264], [252, 300], [262, 336]]),
      _p([[742, 300], [682, 270], [642, 300], [682, 340], [742, 320]]),
      _p([[800, 190], [774, 300], [800, 410]]),
      _p([[898, 312], [876, 316]]),
    ],
    eye: (const Point(820, 252), 24),
  ),
];

FishSpecies? fishSpeciesById(String id) {
  for (final s in fishSpecies) {
    if (s.id == id) return s;
  }
  return null;
}

/// Segmentele Bézier cubice ale curbei Catmull-Rom prin [pts]: pentru fiecare segment
/// (p1, c1, c2, p2). Aceeași curbă desenează fișa și calculează silueta.
List<(Point<double>, Point<double>, Point<double>, Point<double>)> catmullRomBeziers(
  List<Point<double>> pts, {
  bool closed = true,
}) {
  final n = pts.length;
  Point<double> at(int i) => closed ? pts[(i % n + n) % n] : pts[i.clamp(0, n - 1)];
  return [
    for (var i = 0; i < (closed ? n : n - 1); i++)
      (
        at(i),
        at(i) + (at(i + 1) - at(i - 1)) * (1 / 6),
        at(i + 1) - (at(i + 2) - at(i)) * (1 / 6),
        at(i + 1),
      ),
  ];
}

/// Curba eșantionată ca poligon (pentru rasterizare).
List<Point<double>> sampleCurve(List<Point<double>> pts, {bool closed = true, int steps = 10}) {
  final out = <Point<double>>[];
  for (final (a, b, c, d) in catmullRomBeziers(pts, closed: closed)) {
    for (var s = 0; s < steps; s++) {
      final t = s / steps, u = 1 - t;
      out.add(a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t));
    }
  }
  if (!closed) out.add(pts.last);
  return out;
}

/// Volumul unui pește, calculat o dată pe model, pe o grilă [width]×[height] care acoperă
/// caseta desenului: unde e silueta, cât e de gros și ce lumină primește.
class FishBody {
  FishBody._(this.width, this.height, this.coverage, this.thickness, this.light, this.fin);

  final int width, height;

  /// Cât din pixel e în siluetă (0…1, margine netedă).
  final Float32List coverage;

  /// Grosimea relativă (0 pe margine și pe înotătoare, 1 în mijlocul corpului).
  final Float32List thickness;

  /// Lumina: −1 (umbră) … 0 (neschimbat) … +1 (luciu).
  final Float32List light;

  /// 1 pe înotătoare (în afara corpului): acolo peștele e subțire și lasă lumina să treacă.
  final Float32List fin;

  static final _cache = <String, FishBody>{};

  /// Volumul modelului [s] la lățimea [width] (rezultatul se păstrează).
  static FishBody of(FishSpecies s, {int width = 500}) =>
      _cache.putIfAbsent('${s.id}@$width', () => compute(s, width: width));

  static FishBody compute(FishSpecies s, {int width = 500}) {
    final scale = width / FishSpecies.boxWidth;
    final height = (FishSpecies.boxHeight * scale).round();
    final n = width * height;
    List<Point<double>> scaled(List<Point<double>> c) => [for (final p in sampleCurve(c)) p * scale];
    final sil = _rasterize(width, height, [for (final c in s.shapes) scaled(c)]);
    final body = _rasterize(width, height, [scaled(s.body)]);

    final outD = _distanceTo(sil, width, height, 1), inD = _distanceTo(sil, width, height, 0);
    final bodyIn = _distanceTo(body, width, height, 0);
    var dmax = 0.0, x0 = width, x1 = 0;
    for (var i = 0; i < n; i++) {
      dmax = max(dmax, bodyIn[i]);
      if (sil[i] == 1) {
        x0 = min(x0, i % width);
        x1 = max(x1, i % width);
      }
    }
    const outline = FishSpecies.outlineWidth;
    final coverage = Float32List(n), thick = Float32List(n), fin = Float32List(n), rim = Float32List(n);
    for (var i = 0; i < n; i++) {
      // Silueta plus conturul negru de pe fișă (desenat în afara ei), cu margine moale.
      coverage[i] = sil[i] == 1 ? 1 : (outline * scale + 0.8 - outD[i]).clamp(0.0, 1.0).toDouble();
      final x = (i % width - x0) / max(1, x1 - x0); // 0 = coada, 1 = capul
      final head = _smooth(0.12, 0.68, x);
      final r = min(bodyIn[i] / (dmax * 0.85), 1.0);
      final zb = (0.62 + 0.38 * head) * sqrt(max(0, 1 - (1 - r) * (1 - r)));
      final zf = 0.06 * _smooth(0, 5 * scale * 2, inD[i]);
      thick[i] = max(zb, zf);
      if (sil[i] == 1 && body[i] == 0) fin[i] = 1;
      // Marginea corpului se întoarce de la lumină: puțin mai întunecată (dă rotunjime).
      if (body[i] == 1) rim[i] = pow(1 - r, 2.5).toDouble();
    }

    // Lumina vine de sus, din față, puțin din stânga: difuz + luciu + umbră spre burtă.
    final relief = s.thickness * 30 * scale;
    const lx = -0.32, ly = -0.62, lz = 0.72;
    final light = Float32List(n);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        if (coverage[i] == 0) continue;
        double h(int xx, int yy) => thick[yy.clamp(0, height - 1) * width + xx.clamp(0, width - 1)];
        final dx = (h(x + 1, y) - h(x - 1, y)) * relief, dy = (h(x, y + 1) - h(x, y - 1)) * relief;
        final len = sqrt(dx * dx + dy * dy + 1);
        final nx = -dx / len, ny = -dy / len, nz = 1 / len;
        final diff = nx * lx + ny * ly + nz * lz; // 0.72 pe plat
        // Reflexia spre privitor (0,0,1): luciu mic, strâns.
        final rz = 2 * diff * nz - lz;
        final spec = pow(max(0.0, rz), 24).toDouble();
        final belly = (y / height - 0.55).clamp(0.0, 0.45) * thick[i];
        light[i] = ((diff - 0.72) * 1.8 + spec * 1.1 - belly * 1.1 - rim[i] * 0.75).clamp(-1.0, 1.0).toDouble();
      }
    }
    return FishBody._(width, height, coverage, thick, light, fin);
  }
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Reuniunea poligoanelor, rasterizată cu regula par-impar pe fiecare poligon.
Uint8List _rasterize(int w, int h, List<List<Point<double>>> polys) {
  final m = Uint8List(w * h);
  final xs = <double>[];
  for (final poly in polys) {
    for (var y = 0; y < h; y++) {
      final cy = y + 0.5;
      xs.clear();
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i], b = poly[(i + 1) % poly.length];
        if ((a.y <= cy) != (b.y <= cy)) xs.add(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x));
      }
      xs.sort();
      for (var k = 0; k + 1 < xs.length; k += 2) {
        final from = max(0, (xs[k] - 0.5).ceil()), to = min(w - 1, (xs[k + 1] - 0.5).floor());
        for (var x = from; x <= to; x++) {
          m[y * w + x] = 1;
        }
      }
    }
  }
  return m;
}

const _inf = 1e20;

/// Transformata distanței euclidiene (Felzenszwalb & Huttenlocher): pentru fiecare pixel,
/// distanța până la cel mai apropiat pixel cu valoarea [target].
Float64List _distanceTo(Uint8List mask, int w, int h, int target) {
  final g = Float64List(w * h);
  for (var i = 0; i < g.length; i++) {
    g[i] = mask[i] == target ? 0 : _inf;
  }
  final n = max(w, h);
  final f = Float64List(n), d = Float64List(n), z = Float64List(n + 1);
  final v = Int32List(n);
  void pass(int count) {
    var k = 0;
    v[0] = 0;
    z[0] = -_inf;
    z[1] = _inf;
    for (var q = 1; q < count; q++) {
      var s = (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
      while (s <= z[k]) {
        k--;
        s = (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
      }
      k++;
      v[k] = q;
      z[k] = s;
      z[k + 1] = _inf;
    }
    k = 0;
    for (var q = 0; q < count; q++) {
      while (z[k + 1] < q) {
        k++;
      }
      d[q] = (q - v[k]) * (q - v[k]) + f[v[k]];
    }
  }

  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      f[y] = g[y * w + x];
    }
    pass(h);
    for (var y = 0; y < h; y++) {
      g[y * w + x] = d[y];
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      f[x] = g[y * w + x];
    }
    pass(w);
    for (var x = 0; x < w; x++) {
      g[y * w + x] = sqrt(d[x]);
    }
  }
  return g;
}
