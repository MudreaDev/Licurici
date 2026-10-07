import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:licurici_core/licurici_core.dart';

import 'aquarium_store.dart';
import 'fish_art.dart';
import 'reef.dart';

/// O mică bucurie desenată (bule după ce un pește a mâncat, cercul unei atingeri).
class TankFx {
  TankFx(this.at, this.kind, this.born);

  final math.Point<double> at;
  final TankFxKind kind;
  final double born;
}

enum TankFxKind { ate, tap }

/// Peștii, umbrele lor pe nisip, mâncarea și efectele. Peștele e imaginea lui pe o plasă
/// deformată din cod (ADR-028): coada „se strânge” și se desface ca și cum ar bate spre noi
/// și înapoi, corpul unduiește, înotătoarele flutură.
class TankPainter extends CustomPainter {
  TankPainter({
    required this.aquarium,
    required this.fish,
    required this.time,
    required this.fx,
    required this.gather,
  }) : super(repaint: time);

  final Aquarium aquarium;
  final Map<String, OwnedFish> fish;
  final ValueListenable<double> time;
  final List<TankFx> fx;

  /// Unde ține copilul degetul (pentru halou), dacă îl ține.
  final ValueListenable<math.Point<double>?> gather;

  static const _cols = 20, _rows = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width, t = time.value;

    // Haloul degetului ținut apăsat: peștii vin spre lumină.
    final g = gather.value;
    if (g != null) {
      final c = Offset(g.x * h, g.y * h);
      final pulse = 0.85 + 0.15 * math.sin(t * 3);
      canvas.drawCircle(
        c,
        h * 0.16 * pulse,
        Paint()
          ..shader = ui.Gradient.radial(c, h * 0.16 * pulse, [const Color(0x66FFF6C8), const Color(0x00FFF6C8)]),
      );
    }

    // Umbrele, apoi peștii (cei din spate primii: cei mai mici par mai departe).
    final order = List.of(aquarium.fish)..sort((a, b) => a.length.compareTo(b.length));
    for (final f in order) {
      final x = f.pos.x * h, sand = h * sandLine(x, w);
      final lift = ((sand - f.pos.y * h) / h).clamp(0.0, 1.0);
      final a = 0.22 * (1 - lift * 1.1).clamp(0.15, 1.0);
      final sw = f.length * h * (0.75 - lift * 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, sand + h * 0.012), width: sw, height: sw * 0.16),
        Paint()
          ..shader = ui.Gradient.radial(Offset(x, sand + h * 0.012), sw / 2, [
            Color.fromRGBO(20, 50, 60, a),
            const Color(0x00143C3C),
          ]),
      );
    }

    // Mâncarea.
    for (final (i, p) in aquarium.food.indexed) {
      final c = Offset(p.pos.x * h, p.pos.y * h);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(p.age * 1.4 + p.drift);
      final fade = p.grounded > 6 ? (8 - p.grounded) / 2 : 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: h * 0.016, height: h * 0.011), Radius.circular(h * 0.004)),
        Paint()..color = (i.isEven ? const Color(0xFFF2A33A) : const Color(0xFFE5703A)).withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }

    for (final f in order) {
      final owned = fish[f.id];
      if (owned != null) _drawFish(canvas, h, f, owned);
    }

    // Efectele.
    for (final e in fx) {
      final age = t - e.born;
      final c = Offset(e.at.x * h, e.at.y * h);
      switch (e.kind) {
        case TankFxKind.tap:
          final k = (age / 0.6).clamp(0.0, 1.0);
          canvas.drawCircle(
            c,
            h * (0.03 + 0.12 * k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.006 * (1 - k)
              ..color = Color.fromRGBO(255, 255, 255, 0.7 * (1 - k)),
          );
        case TankFxKind.ate:
          final r = math.Random(e.born.hashCode);
          for (var i = 0; i < 5; i++) {
            final k = (age / 1.4).clamp(0.0, 1.0);
            final o = Offset((r.nextDouble() - 0.5) * h * 0.06 + math.sin(age * 6 + i) * h * 0.006, -k * h * (0.08 + r.nextDouble() * 0.06));
            paintBubble(canvas, c + o, h * (0.005 + r.nextDouble() * 0.006), 1 - k);
          }
      }
    }
  }

  void _drawFish(Canvas canvas, double h, SwimmingFish f, OwnedFish owned) {
    final frame = FishFrame.of(owned.species);
    final img = owned.art;
    final k = f.length * h / frame.length; // pixeli pe unitate de desen
    final texScale = img.width / fishBox.width;

    // Întoarcerea: peștele se „subțiază” trecând prin profil, apoi se oglindește.
    final turn = f.facing.abs() < 0.12 ? 0.12 * (f.facing >= 0 ? 1 : -1) : f.facing;
    final tilt = math.atan2(f.vel.y, math.max(f.vel.x.abs(), 0.02)).clamp(-0.4, 0.4);
    final bob = math.sin(f.phase * 0.35) * h * 0.004;

    canvas.save();
    canvas.translate(f.pos.x * h, f.pos.y * h + bob);
    canvas.scale(turn * k, k * (1 + (1 - f.facing.abs()) * 0.06));
    canvas.rotate(tilt);
    canvas.translate(-frame.center.dx, -frame.center.dy);

    final sweep = math.sin(f.phase) * (0.42 * (0.55 + 0.35 * f.effort + 0.5 * f.joy)).clamp(0.0, 0.75);
    final waveAmp = frame.length * 0.03 * (0.6 + 0.4 * f.effort + 0.6 * f.joy);
    final x0 = math.max(0.0, frame.tail - 12), x1 = math.min(fishBox.width, frame.head + 12);
    final y0 = math.max(0.0, frame.top - 12), y1 = math.min(fishBox.height, frame.bottom + 12);
    final midY = (frame.top + frame.bottom) / 2, halfH = (frame.bottom - frame.top) / 2;

    const n = (_cols + 1) * (_rows + 1);
    final pos = Float32List(n * 2), tex = Float32List(n * 2);
    var i = 0;
    for (var r = 0; r <= _rows; r++) {
      for (var c = 0; c <= _cols; c++) {
        final bx = x0 + (x1 - x0) * c / _cols, by = y0 + (y1 - y0) * r / _rows;
        final tt = ((frame.head - bx) / frame.length).clamp(0.0, 1.0); // 0 la cap, 1 la coadă
        // Coada care bate spre privitor apare mai scurtă (perspectivă).
        final dx = math.pow(tt, 2.2) * (1 - math.cos(sweep)) * frame.length * 0.32;
        final edge = ((by - midY).abs() / halfH).clamp(0.0, 1.0);
        final dy = tt * tt * math.sin(f.phase - tt * 2.6) * waveAmp + edge * edge * edge * math.sin(f.phase * 1.3 + bx * 0.02) * 5;
        pos[i] = bx + dx;
        pos[i + 1] = by + dy;
        tex[i] = bx * texScale;
        tex[i + 1] = by * texScale;
        i += 2;
      }
    }
    final idx = Uint16List(_cols * _rows * 6);
    var j = 0;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final a = r * (_cols + 1) + c;
        idx
          ..[j++] = a
          ..[j++] = a + 1
          ..[j++] = a + _cols + 1
          ..[j++] = a + 1
          ..[j++] = a + _cols + 2
          ..[j++] = a + _cols + 1;
      }
    }
    final v = ui.Vertices.raw(ui.VertexMode.triangles, pos, textureCoordinates: tex, indices: idx);
    canvas.drawVertices(
      v,
      BlendMode.srcOver,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ui.ImageShader(img, TileMode.decal, TileMode.decal, Matrix4Identity.storage),
    );
    v.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(TankPainter old) => old.fish != fish || old.aquarium != aquarium;
}

abstract final class Matrix4Identity {
  static final storage = Float64List.fromList(const [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
}
