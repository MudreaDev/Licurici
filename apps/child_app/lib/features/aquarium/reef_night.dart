import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'reef_life.dart';

/// Unde e meduza [i] (0 sau 1) la timpul [t]: centrul, raza și cât se vede (aceleași formule
/// ca stratul din spate, ca lumina ei de noapte să cadă exact pe ea).
(Offset, double, double) jellyAt(int i, Size size, double t) {
  final w = size.width, h = size.height;
  final life = (t * 0.011 + i * 0.5) % 1;
  final y = h * (0.78 - life * 0.75);
  final x = w * (i == 0 ? 0.24 : 0.73) + math.sin(t * 0.12 + i * 3) * w * 0.04;
  final fade = math.min(1.0, math.min(life * 8, (1 - life) * 8));
  return (Offset(x, y), h * (i == 0 ? 0.04 : 0.032), fade);
}

/// Noaptea în acvariu: apa se întunecă, dar rămân lumini — luna de sus, meduzele și
/// planctonul care strălucesc, cufărul deschis și **degetul copilului, ca o lanternă** (peștii
/// vin la lumină). [night] 0…1 face trecerea lină între zi și noapte.
class ReefNightPainter extends CustomPainter {
  ReefNightPainter({
    required this.time,
    required this.night,
    required this.finger,
    required this.chest,
  }) : super(repaint: Listenable.merge([time, night, finger]));

  /// Timpul fundalului (același cu al straturilor din spate).
  final ValueListenable<double> time;
  final ValueListenable<double> night;
  final ValueListenable<Offset?> finger;
  final ReefChest chest;

  @override
  void paint(Canvas canvas, Size size) {
    final k = night.value;
    if (k <= 0.001) return;
    final t = time.value, w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Color.fromRGBO(8, 22, 52, 0.62 * k),
          Color.fromRGBO(4, 12, 34, 0.78 * k),
        ]),
    );
    // Luminile „găuresc” întunericul.
    void hole(Offset c, double r, double strength) => canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(c, r, [Color.fromRGBO(0, 0, 0, strength), const Color(0x00000000)]),
    );
    if (finger.value case final f?) hole(f, h * 0.32, 0.92);
    for (var i = 0; i < 2; i++) {
      final (c, r, a) = jellyAt(i, size, t);
      hole(c, r * 3.2, 0.6 * a);
    }
    final lid = chest.lid(t);
    if (lid > 0.05) hole(ReefChest.baseAt(size) - Offset(0, ReefChest.widthFor(size) * 0.5), h * 0.22 * lid, 0.8 * lid);
    // Lumina lunii, de sus, slabă.
    hole(Offset(w * 0.38, -h * 0.05), h * 0.6, 0.35);
    canvas.restore();

    // Lanterna degetului: o lumină caldă, nu doar o gaură în întuneric.
    if (finger.value case final f?) {
      canvas.drawCircle(
        f,
        h * 0.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(f, h * 0.2, [Color.fromRGBO(255, 226, 160, 0.22 * k), const Color(0x00FFE2A0)]),
      );
    }
    // Strălucirile: meduzele, planctonul (sclipiri reci), luna pe suprafață.
    for (var i = 0; i < 2; i++) {
      final (c, r, a) = jellyAt(i, size, t);
      canvas.drawCircle(
        c,
        r * 2.2,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(c, r * 2.2, [Color.fromRGBO(255, 140, 210, 0.35 * a * k), const Color(0x00FF8CD2)]),
      );
    }
    final rnd = math.Random(21);
    final glow = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 45; i++) {
      final x0 = rnd.nextDouble() * w, y0 = rnd.nextDouble() * h * 0.85, ph = rnd.nextDouble() * 6;
      final c = Offset(x0 + math.sin(t * 0.2 + ph) * h * 0.02, y0 + math.cos(t * 0.15 + ph) * h * 0.015);
      final a = (0.5 + 0.5 * math.sin(t * (0.8 + rnd.nextDouble()) + ph)) * k;
      final r = h * (0.003 + 0.003 * rnd.nextDouble());
      glow.shader = ui.Gradient.radial(c, r * 2.2, [Color.fromRGBO(150, 255, 230, 0.55 * a), const Color(0x0040FFE6)]);
      canvas.drawCircle(c, r * 2.2, glow);
    }
    final moon = Offset(w * 0.38, h * 0.02);
    canvas.drawOval(
      Rect.fromCenter(center: moon, width: h * 0.5, height: h * 0.06),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(moon, h * 0.25, [Color.fromRGBO(220, 235, 255, 0.35 * k), const Color(0x00DCEBFF)]),
    );
  }

  @override
  bool shouldRepaint(ReefNightPainter old) => old.chest != chest;
}
