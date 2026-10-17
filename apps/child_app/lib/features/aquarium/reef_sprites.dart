import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:game_content/game_content.dart';

import '../../shared/stimulus_art.dart';
import 'reef_parts.dart';

/// Vietățile și plantele pictate ale recifului (Codex, `art/illustrations/parts/`, `sprites/`,
/// `objects/`), animate din cod (ADR-028): algele și anemona se leagănă prin deformarea
/// imaginii, țestoasa vâslește, meduza pulsează, crabul pășește, cufărul se deschide.
/// Cât timp o imagine nu e încărcată (sau lipsește), recif o desenează din cod, ca înainte.
abstract final class ReefSprites {
  static final images = <String, ui.Image>{};
  static Future<void>? _loading;

  static const _paths = {
    'kelp': 'parts/kelp',
    'anemone': 'parts/anemone',
    'school': 'parts/school_fish',
    'turtle': 'parts/turtle_side',
    'chest_closed': 'parts/chest_closed',
    'chest_open': 'parts/chest_open',
    'crab': 'sprites/crab',
    'jelly': 'objects/jellyfish',
  };

  static ui.Image? get(String name) => images[name];

  /// Încarcă o dată imaginile care există în pachet (fără să aștepte după cele lipsă).
  static Future<void> load() => _loading ??= Future.wait([
    for (final MapEntry(key: name, value: path) in _paths.entries)
      if (IllustrationIndex.has(path)) _decode(name, path),
  ]);

  static Future<void> _decode(String name, String path) async {
    try {
      final data = await rootBundle.load('packages/$contentPackage/art/illustrations/$path.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      images[name] = (await codec.getNextFrame()).image;
    } catch (_) {
      // Rămâne desenul din cod.
    }
  }
}

final _identity = Float64List.fromList(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
final _fogCache = <int, ColorFilter>{};

/// Ceața apei peste o imagine (ca la peștii din spate): culorile se amestecă cu [reefFog].
ColorFilter? reefFogFilter(double fog) {
  if (fog < 0.02) return null;
  return _fogCache.putIfAbsent((fog * 40).round(), () {
    final f = ((fog * 40).round() / 40).clamp(0.0, 1.0), k = 1 - f;
    return ColorFilter.matrix([
      k, 0, 0, 0, f * (reefFog.r * 255), //
      0, k, 0, 0, f * (reefFog.g * 255),
      0, 0, k, 0, f * (reefFog.b * 255),
      0, 0, 0, 1, 0,
    ]);
  });
}

/// Imaginea [img] întinsă în [dst], oglindită pe orizontală dacă [flip].
void drawSprite(Canvas canvas, ui.Image img, Rect dst, {bool flip = false, double fog = 0, double opacity = 1}) {
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = reefFogFilter(fog);
  if (opacity < 1) paint.color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0));
  canvas.save();
  if (flip) {
    canvas.translate(dst.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-dst.center.dx, 0);
  }
  canvas.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst, paint);
  canvas.restore();
}

/// Imaginea [img] pusă pe o plasă și deformată de [warp] (coordonate 0..1 în imagine), în [dst].
void drawWarped(Canvas canvas, ui.Image img, Rect dst, Offset Function(Offset p) warp, {int cols = 6, int rows = 12, double fog = 0}) {
  final n = (cols + 1) * (rows + 1);
  final pos = Float32List(n * 2), tex = Float32List(n * 2);
  var k = 0;
  for (var y = 0; y <= rows; y++) {
    for (var x = 0; x <= cols; x++) {
      final p = Offset(x / cols, y / rows), q = warp(p);
      pos[k] = dst.left + q.dx * dst.width;
      pos[k + 1] = dst.top + q.dy * dst.height;
      tex[k] = p.dx * img.width;
      tex[k + 1] = p.dy * img.height;
      k += 2;
    }
  }
  final idx = Uint16List(cols * rows * 6);
  k = 0;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final i = y * (cols + 1) + x;
      idx
        ..[k++] = i
        ..[k++] = i + 1
        ..[k++] = i + cols + 1
        ..[k++] = i + 1
        ..[k++] = i + cols + 2
        ..[k++] = i + cols + 1;
    }
  }
  final v = ui.Vertices.raw(ui.VertexMode.triangles, pos, textureCoordinates: tex, indices: idx);
  canvas.drawVertices(
    v,
    BlendMode.srcOver,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = reefFogFilter(fog)
      ..shader = ui.ImageShader(img, TileMode.decal, TileMode.decal, _identity),
  );
  v.dispose();
}

/// Lățimea / înălțimea imaginii.
double aspectOf(ui.Image img) => img.width / img.height;

/// Alga pictată: baza fixă pe nisip, vârful se leagănă (unda urcă pe tulpină).
bool paintKelpSprite(Canvas canvas, Offset base, double height, double t, double phase, {double fog = 0}) {
  final img = ReefSprites.get('kelp');
  if (img == null) return false;
  final w = height * aspectOf(img);
  final dst = Rect.fromLTWH(base.dx - w / 2, base.dy - height, w, height);
  final a = 0.09 * math.sin(t * 0.8 + phase), b = 0.035 * math.sin(t * 1.7 + phase * 1.3);
  drawWarped(canvas, img, dst, (p) {
    final up = 1 - p.dy; // 0 jos … 1 sus
    return Offset(p.dx + a * math.pow(up, 1.6) + b * math.sin(up * 4 + t * 1.2) * up, p.dy);
  }, fog: fog);
  return true;
}

/// Anemona pictată: tentaculele se leagănă, baza rămâne.
bool paintAnemoneSprite(Canvas canvas, Offset base, double size, double t) {
  final img = ReefSprites.get('anemone');
  if (img == null) return false;
  final hgt = size * 1.6, w = hgt * aspectOf(img);
  final dst = Rect.fromLTWH(base.dx - w / 2, base.dy - hgt, w, hgt);
  drawWarped(canvas, img, dst, (p) {
    final up = 1 - p.dy;
    final sway = 0.05 * math.sin(t * 1.1 + p.dx * 5) * math.pow(up, 1.4);
    final breathe = 1 + 0.04 * math.sin(t * 0.9) * up;
    return Offset(0.5 + (p.dx - 0.5) * breathe + sway, p.dy);
  }, cols: 10, rows: 10);
  return true;
}

/// Țestoasa pictată, din profil: plutește în valuri lente, ușor înclinată.
bool paintTurtleSprite(Canvas canvas, Offset c, double len, double t, {int dir = 1, double fog = 0}) {
  final img = ReefSprites.get('turtle');
  if (img == null) return false;
  final w = len * 1.5, hgt = w / aspectOf(img);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(0.05 * math.sin(t * 0.6) * dir);
  final dst = Rect.fromCenter(center: Offset.zero, width: w, height: hgt);
  // Labele vâslesc: imaginea se strânge și se lungește puțin pe verticală, în ritmul vâslitului.
  final stroke = math.sin(t * 1.4);
  drawWarped(canvas, img, dst, (p) {
    final x = dir > 0 ? p.dx : 1 - p.dx;
    return Offset(x, 0.5 + (p.dy - 0.5) * (1 + 0.05 * stroke * (1 - (p.dx - 0.5).abs() * 2)));
  }, cols: 8, rows: 6, fog: fog);
  canvas.restore();
  return true;
}

/// Crabul pictat: pășește într-o parte (mic salt la fiecare pas), stă din când în când.
bool paintCrabSprite(Canvas canvas, Offset base, double size, double t, {bool walking = true}) {
  final img = ReefSprites.get('crab');
  if (img == null) return false;
  final w = size * 2.6, hgt = w / aspectOf(img);
  final hop = walking ? (math.sin(t * 12).abs() * size * 0.08) : 0.0;
  final tilt = walking ? 0.06 * math.sin(t * 12) : 0.0;
  paintContactShadow(canvas, base, w * 0.8, alpha: 0.22);
  canvas.save();
  canvas.translate(base.dx, base.dy - hop);
  canvas.rotate(tilt);
  drawSprite(canvas, img, Rect.fromLTWH(-w / 2, -hgt, w, hgt));
  canvas.restore();
  return true;
}

/// Meduza pictată: clopotul pulsează (se strânge și se lungește), cu transparență.
bool paintJellySprite(Canvas canvas, Offset c, double r, double phase, {double fog = 0, double alpha = 1}) {
  final img = ReefSprites.get('jelly');
  if (img == null) return false;
  if (alpha <= 0) return true;
  final pulse = 0.5 + 0.5 * math.sin(phase);
  final w = r * 3 * (1 - 0.1 * pulse), hgt = r * 3.4 * (1 + 0.08 * pulse);
  canvas.saveLayer(Rect.fromCenter(center: c, width: w * 1.2, height: hgt * 1.2), Paint()..color = Color.fromRGBO(0, 0, 0, 0.8 * alpha));
  drawSprite(canvas, img, Rect.fromCenter(center: c, width: w, height: hgt), fog: fog);
  canvas.restore();
  return true;
}

/// Cufărul pictat: închis, apoi deschis (cu o clipă de „săritură” a capacului).
bool paintChestSprite(Canvas canvas, Offset base, double width, double open, {double fog = 0}) {
  final closed = ReefSprites.get('chest_closed'), opened = ReefSprites.get('chest_open');
  if (closed == null || opened == null) return false;
  final hgt = width / aspectOf(closed) * 1.0;
  paintContactShadow(canvas, base, width * 1.1, alpha: 0.28);
  final dst = Rect.fromLTWH(base.dx - width / 2, base.dy - hgt, width, hgt);
  if (open < 0.5) {
    drawSprite(canvas, closed, dst, fog: fog);
  } else {
    final pop = math.sin(((open - 0.5) * 2).clamp(0.0, 1.0) * math.pi) * 0.04;
    final hgt2 = width / aspectOf(opened) * (1 + pop);
    drawSprite(canvas, opened, Rect.fromLTWH(base.dx - width / 2, base.dy - hgt2, width, hgt2), fog: fog);
  }
  return true;
}

/// Un peștișor din banc (pictat), cu coada care bate (deformare spre spate).
bool paintSchoolFishSprite(Canvas canvas, Offset c, double len, double t, double phase, {int dir = 1, double fog = 0.5}) {
  final img = ReefSprites.get('school');
  if (img == null) return false;
  final hgt = len / aspectOf(img);
  final dst = Rect.fromCenter(center: c, width: len, height: hgt);
  final beat = 0.12 * math.sin(t * 9 + phase);
  drawWarped(canvas, img, dst, (p) {
    // Imaginea privește spre dreapta: coada e la stânga (p.dx mic) și bate în sus și în jos.
    final tail = (1 - p.dx) * (1 - p.dx);
    return Offset(dir > 0 ? p.dx : 1 - p.dx, p.dy + beat * tail);
  }, cols: 6, rows: 3, fog: fog);
  return true;
}
