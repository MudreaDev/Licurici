import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:licurici_core/licurici_core.dart';

import 'aquarium_store.dart';
import 'fish_art.dart';

/// Culoarea apei în depărtare: peștii din spate se pierd în ea.
const tankFog = Color(0xFF2B7FA8);

/// Desenează peștele ca pe un corp în spațiu (ADR-028, fără shadere): desenul copilului
/// e o plasă întinsă pe o **coloană vertebrală 3D**. Fiecare felie a corpului are direcția
/// ei în planul orizontal — direcția peștelui + unda care trece spre coadă + îndoirea din
/// viraj — și se proiectează pe ecran. De aici:
/// - coada care bate spre noi și înapoi se scurtează și se lungește (perspectivă);
/// - la întoarcere capul trece primul, coada vine după (corpul în „C”), iar burta se vede
///   rotunjită, nu ca o foaie;
/// - fiecare felie e luminată după cum stă față de noi, plus reflexele mișcătoare ale apei;
/// - peștii din spate sunt mai mici, mai albaștri și mai estompați (ceața apei).
class FishRenderer {
  FishRenderer();

  static const _cols = 26, _rows = 10;
  static const _n = (_cols + 1) * (_rows + 1);

  final _pos = Float32List(_n * 2);
  final _tex = Float32List(_n * 2);
  final _colors = Int32List(_n);
  final _idx = Uint16List(_cols * _rows * 6);
  final _psi = Float64List(_cols + 1);
  final _sx = Float64List(_cols + 1);
  final _sz = Float64List(_cols + 1);
  final _order = List<int>.generate(_cols, (i) => i);

  void paint(Canvas canvas, double h, SwimmingFish f, OwnedFish owned, double t) {
    final species = owned.species;
    final frame = FishFrame.of(species);
    final img = owned.art;
    final k = f.apparentLength * h / frame.length; // pixeli pe unitate de desen
    final texScale = img.width / fishBox.width;

    final x0 = math.max(0.0, frame.tail - 14), x1 = math.min(fishBox.width, frame.head + 14);
    final y0 = math.max(0.0, frame.top - 14), y1 = math.min(fishBox.height, frame.bottom + 14);
    final midY = (frame.top + frame.bottom) / 2, halfH = (frame.bottom - frame.top) / 2;

    // Unda corpului: aproape nimic la cap, tot mai mare spre coadă. Cât de mare depinde
    // de cât împinge peștele; umflat, abia mai dă din coadă.
    final puff = f.puff * f.puff * (3 - 2 * f.puff);
    final amp = (0.16 + 0.5 * f.thrust + 0.22 * f.joy) * (0.55 + 0.45 * species.swim) * (1 - 0.7 * puff);
    // Îndoirea din viraj: coada rămâne în urma capului.
    final bend = (-f.turnRate * 0.16).clamp(-0.9, 0.9);

    // 1. Direcția fiecărei felii (coloane) — de la coadă (c = 0) la cap.
    for (var c = 0; c <= _cols; c++) {
      final bx = x0 + (x1 - x0) * c / _cols;
      final tt = ((frame.head - bx) / frame.length).clamp(0.0, 1.0); // 0 la cap, 1 la coadă
      final wave = amp * (0.05 + 0.95 * tt * tt) * math.sin(f.phase - tt * 2.5);
      _psi[c] = f.yaw + wave + bend * math.pow(tt, 1.3);
    }

    // 2. Coloana vertebrală proiectată: fiecare segment merge spre cap pe direcția lui.
    _sx[0] = 0;
    _sz[0] = 0;
    for (var c = 0; c < _cols; c++) {
      final len = (x1 - x0) / _cols;
      final a = (_psi[c] + _psi[c + 1]) / 2;
      _sx[c + 1] = _sx[c] + len * math.cos(a);
      _sz[c + 1] = _sz[c] + len * math.sin(a);
    }
    // Centrul peștelui (unde e `pos`) rămâne pe loc.
    final cf = ((frame.center.dx - x0) / (x1 - x0) * _cols).clamp(0.0, _cols.toDouble());
    final ci = cf.floor().clamp(0, _cols - 1), cr = cf - ci;
    final ox = _sx[ci] + (_sx[ci + 1] - _sx[ci]) * cr;

    // Grosimea peștelui (cât iese burta în lateral când e văzut din unghi).
    final thick = halfH * (0.35 + species.thickness * 2.6);
    // Desenul copilului trebuie să-și păstreze culorile: ceața și absorbția sunt doar o
    // nuanță, nu o spălare.
    final fog = (f.z * 0.26).clamp(0.0, 0.26);
    final absorbR = 1 - 0.1 * f.z, absorbG = 1 - 0.04 * f.z;
    final px = f.pos.x * h, py = f.pos.y * h;

    var i = 0;
    for (var r = 0; r <= _rows; r++) {
      final by = y0 + (y1 - y0) * r / _rows;
      final edge = ((by - midY).abs() / halfH).clamp(0.0, 1.0);
      final round = math.sqrt(math.max(0.0, 1 - edge * edge));
      for (var c = 0; c <= _cols; c++) {
        final bx = x0 + (x1 - x0) * c / _cols;
        final tt = ((frame.head - bx) / frame.length).clamp(0.0, 1.0);
        final psi = _psi[c];
        final cs = math.cos(psi), sn = math.sin(psi);
        // Burta rotunjită: cea mai groasă spre cap, subțire la coadă.
        final profile = (1 - math.pow((tt - 0.32) / 0.44, 2)).clamp(0.0, 1.0);
        final side = thick * profile * round * sn * _softSign(cs);
        final fin = edge * edge * edge * math.sin(f.phase * 1.3 + bx * 0.02) * 6;
        _pos[i * 2] = (_sx[c] - ox) + side;
        _pos[i * 2 + 1] = by - midY + fin;
        _tex[i * 2] = bx * texScale;
        _tex[i * 2 + 1] = by * texScale;

        // Lumina: felia văzută din față e luminată, cea văzută pe muchie e mai întunecată;
        // peste ea, reflexele apei care se mișcă pe pește.
        final wx = (px + _pos[i * 2] * k) / h, wy = (py + _pos[i * 2 + 1] * k) / h;
        final caustic = 0.07 * math.sin(wx * 21 + t * 1.6) * math.sin(wy * 17 - t * 1.25 + wx * 5);
        final shade = (0.72 + 0.28 * math.pow(cs.abs(), 0.7) + caustic).clamp(0.0, 1.0);
        _colors[i] = _argb(shade * absorbR, shade * absorbG, shade);
        i++;
      }
    }

    // 3. Fâșiile se desenează de la cea mai depărtată la cea mai apropiată (la întoarcere
    //    capul trece prin fața cozii, sau prin spatele ei).
    for (var c = 0; c < _cols; c++) {
      _order[c] = c;
    }
    _order.sort((a, b) => (_sz[b] + _sz[b + 1]).compareTo(_sz[a] + _sz[a + 1]));
    var j = 0;
    for (final c in _order) {
      for (var r = 0; r < _rows; r++) {
        final a = r * (_cols + 1) + c;
        _idx
          ..[j++] = a
          ..[j++] = a + 1
          ..[j++] = a + _cols + 1
          ..[j++] = a + 1
          ..[j++] = a + _cols + 2
          ..[j++] = a + _cols + 1;
      }
    }

    final bob = math.sin(f.phase * 0.3) * h * 0.003 * (1 - f.thrust * 0.5);
    canvas.save();
    canvas.translate(px, py + bob);
    canvas.scale(k, k * (1 + 0.04 * (1 - f.facing.abs())));
    canvas.rotate(f.tilt * f.facing);
    if (puff > 0) canvas.scale(1 + 0.16 * puff, 1 + 0.42 * puff);
    final v = ui.Vertices.raw(ui.VertexMode.triangles, _pos, textureCoordinates: _tex, colors: _colors, indices: _idx);
    canvas.drawVertices(
      v,
      BlendMode.modulate,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ui.ImageShader(img, TileMode.decal, TileMode.decal, _identity)
        ..colorFilter = fog > 0.01 ? _fogFilter(fog) : null,
    );
    v.dispose();
    if (puff > 0.02) {
      final turn = f.facing.abs() < 0.3 ? 0.3 * (f.facing >= 0 ? 1 : -1) : f.facing;
      canvas.scale(turn, 1);
      canvas.translate(-frame.center.dx, -frame.center.dy);
      _spikes(canvas, species, puff, fog);
    }
    canvas.restore();
  }

  /// Țepii peștelui-balon: triunghiuri mici pe conturul corpului (unități de desen).
  void _spikes(Canvas canvas, FishSpecies s, double p, double fog) {
    final body = sampleCurve(s.body, steps: 3);
    final c = body.fold(Offset.zero, (a, q) => a + Offset(q.x, q.y)) / body.length.toDouble();
    final col = Color.lerp(const Color(0xFF463C28), tankFog, fog)!;
    final paint = Paint()..color = col.withValues(alpha: 0.85 * p);
    for (var i = 0; i < body.length; i += 2) {
      final q = Offset(body[i].x, body[i].y);
      final out = q - c;
      final n = out / out.distance;
      final side = Offset(-n.dy, n.dx) * 7;
      final tip = q + n * (16 * p);
      canvas.drawPath(
        Path()
          ..moveTo(q.dx + side.dx, q.dy + side.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(q.dx - side.dx, q.dy - side.dy)
          ..close(),
        paint,
      );
    }
  }
}

double _softSign(double x) {
  final e = math.exp(-2 * x * 5);
  return (1 - e) / (1 + e);
}

int _argb(double r, double g, double b) =>
    0xFF000000 | ((r.clamp(0.0, 1.0) * 255).round() << 16) | ((g.clamp(0.0, 1.0) * 255).round() << 8) | (b.clamp(0.0, 1.0) * 255).round();

final _identity = Float64List.fromList(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

final _fogCache = <int, ColorFilter>{};

/// Amestecă culoarea cu apa din depărtare (alfa rămâne).
ColorFilter _fogFilter(double f) => _fogCache.putIfAbsent((f * 40).round(), () {
  final q = (f * 40).round() / 40;
  final k = 1 - q;
  return ColorFilter.matrix([
    k, 0, 0, 0, tankFog.r * 255 * q, //
    0, k, 0, 0, tankFog.g * 255 * q,
    0, 0, k, 0, tankFog.b * 255 * q,
    0, 0, 0, 1, 0,
  ]);
});
