import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:licurici_core/licurici_core.dart';

import 'aquarium_store.dart';
import 'fish_render.dart';
import 'reef.dart';

/// O mică bucurie desenată (bule după ce un pește a mâncat, cercul unei atingeri).
class TankFx {
  TankFx(this.at, this.kind, this.born);

  final math.Point<double> at;
  final TankFxKind kind;
  final double born;
}

enum TankFxKind { ate, tap }

/// Peștii, umbrele lor pe nisip, mâncarea și efectele. Fiecare pește e desenat ca un corp
/// în spațiu de [FishRenderer] (plasă pe o coloană vertebrală 3D, ADR-028).
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

  final _renderer = FishRenderer();

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

    // Umbrele pe fund, apoi peștii — cei din spate primii.
    final order = List.of(aquarium.fish)..sort((a, b) => b.z.compareTo(a.z));
    for (final f in order) {
      final x = f.pos.x * h, floor = h * floorY(x, w, f.z);
      final lift = ((floor - f.pos.y * h) / h).clamp(0.0, 1.0);
      final a = 0.26 * (1 - lift * 1.3).clamp(0.12, 1.0) * f.scale;
      final sw = f.apparentLength * h * (0.8 - lift * 0.3) * (0.35 + 0.65 * f.facing.abs());
      final c = Offset(x, floor);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: sw, height: sw * 0.18 * f.scale),
        Paint()..shader = ui.Gradient.radial(c, sw / 2, [Color.fromRGBO(12, 40, 52, a), const Color(0x000C2834)]),
      );
    }

    // Mâncarea.
    for (final (i, p) in aquarium.food.indexed) {
      final c = Offset(p.pos.x * h, p.pos.y * h);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(depthScale(p.z));
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
      if (owned != null) _renderer.paint(canvas, h, f, owned, t);
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

  @override
  bool shouldRepaint(TankPainter old) => old.fish != fish || old.aquarium != aquarium;
}
