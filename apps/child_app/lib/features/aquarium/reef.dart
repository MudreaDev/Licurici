import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'reef_parts.dart';

/// Recif desenat din cod (rezerva până vin straturile pictate `scenes/aquarium_*`).
///
/// Scena are adâncime: fundul de nisip urcă spre peretele din spate (perspectivă), iar
/// ce e departe se pierde în albastrul apei. Straturile, din spate spre față:
/// - [ReefBackdropPainter] (static): apa, siluetele din depărtare, fundul, stâncile din
///   spate cu corali;
/// - `ReefAmbiencePainter` (animat, în spatele peștilor): suprafața, reflexele pe nisip,
///   algele, bancul de peștișori, meduza, cufărul, bulele;
/// - peștii copilului;
/// - [ReefForegroundPainter] (static, în fața peștilor): stâncile cu corali din colțuri;
/// - `ReefFrontPainter` (animat): anemona, algele din față, razele de lumină, plancton.
///
/// Toate pozițiile vin din seed, deci acvariul arată la fel la fiecare deschidere.

/// Marginea din spate a fundului (fracție din înălțime), la x.
double backFloor(double x, double w) => 0.775 + 0.014 * math.sin(x / w * 4.3 + 1) + 0.008 * math.sin(x / w * 11.7);

/// Fundul de nisip la adâncimea [z] (0 = lângă geam, 1 = în spate), ca fracție din înălțime.
double floorY(double x, double w, double z) {
  final front = 0.985 + 0.01 * math.sin(x / w * 3.1);
  return front + (backFloor(x, w) - front) * z.clamp(0.0, 1.0);
}

/// Păstrat pentru straturile vechi: linia nisipului la jumătatea adâncimii.
double sandLine(double x, double width) => floorY(x, width, 0.55);

/// Conturul fundului (pentru decupări).
Path floorPath(Size size) {
  final w = size.width, h = size.height;
  final p = Path()..moveTo(0, h);
  for (var x = 0.0; x <= w + 8; x += 8) {
    p.lineTo(x, h * backFloor(x, w));
  }
  return p
    ..lineTo(w, h)
    ..close();
}

/// Fundalul static (apa, depărtarea, fundul, stâncile din spate). Se desenează o dată pe
/// dimensiune.
class ReefBackdropPainter extends CustomPainter {
  const ReefBackdropPainter({this.seed = 7});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = math.Random(seed);

    // Apa: luminoasă sus, adâncă la orizont.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.8), const [
          Color(0xFFA6EAEE),
          Color(0xFF5CC7DA),
          Color(0xFF2E9BC4),
          Color(0xFF1F79A6),
        ], const [0, 0.14, 0.5, 1]),
    );
    // Lumina soarelui prin apă, sus.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.38, -h * 0.15), h * 1.05, const [
          Color(0x77FFFFFF),
          Color(0x22FFFFFF),
          Color(0x00FFFFFF),
        ], const [0, 0.4, 1]),
    );

    // Depărtarea: trei rânduri de recif, tot mai clare spre noi.
    _ridge(canvas, size, r, base: 0.70, rise: 0.11, fog: 0.82, freq: 3.1, seedShift: 0.4);
    _ridge(canvas, size, r, base: 0.745, rise: 0.09, fog: 0.68, freq: 4.7, seedShift: 2.2);
    // O arcadă de stâncă în depărtare (formă de recunoscut, dă scară scenei).
    _arch(canvas, Offset(w * 0.67, h * backFloor(w * 0.67, w) + h * 0.005), h * 0.36, h * 0.24, fog: 0.62);

    _floor(canvas, size, r);

    // Stâncile din spate, pe fund, cu corali (pe jumătate în ceață).
    final backRocks = [(0.12, 0.30, 0.2, 0.5), (0.36, 0.14, 0.08, 0.55), (0.88, 0.32, 0.17, 0.48)];
    for (final (fx, fw, fh, fog) in backRocks) {
      final base = Offset(w * fx, h * backFloor(w * fx, w) + h * 0.02);
      paintContactShadow(canvas, base + Offset(0, h * 0.005), h * fw * 1.2, alpha: 0.25);
      paintRock(canvas, rockShape(base, h * fw, h * fh, r), r, fog: fog);
    }
    paintBranchCoral(canvas, Offset(w * 0.06, h * 0.64), h * 0.17, const Color(0xFFF07C8C), r, fog: 0.45);
    paintSoftCoral(canvas, Offset(w * 0.17, h * 0.62), h * 0.08, r, fog: 0.45, color: const Color(0xFFE6A23C));
    paintFan(canvas, Offset(w * 0.36, h * 0.73), h * 0.2, r, fog: 0.5, color: const Color(0xFFD0729E), lean: -0.15);
    paintTubes(canvas, Offset(w * 0.92, h * 0.645), h * 0.75, r, fog: 0.45, color: const Color(0xFFE07A5F), count: 4);
    paintBranchCoral(canvas, Offset(w * 0.83, h * 0.66), h * 0.15, const Color(0xFFB98AE0), r, fog: 0.45);

    // Pe fund, la mijlocul adâncimii: iarbă de mare, scoici, o stea.
    for (final (fx, z) in [(0.27, 0.55), (0.46, 0.7), (0.53, 0.35), (0.76, 0.6), (0.4, 0.2)]) {
      final base = Offset(w * fx, h * floorY(w * fx, w, z));
      paintGrassTuft(canvas, base, h * 0.07 * (1.2 - 0.6 * z), r, fog: z * 0.35);
    }
    paintStarfish(canvas, Offset(w * 0.45, h * floorY(w * 0.45, w, 0.12)), h * 0.032, 0.3);
    paintShell(canvas, Offset(w * 0.33, h * floorY(w * 0.33, w, 0.25)), h * 0.02);
    paintShell(canvas, Offset(w * 0.7, h * floorY(w * 0.7, w, 0.45)), h * 0.016, color: const Color(0xFFF6C9B5), fog: 0.12);
    paintStarfish(canvas, Offset(w * 0.79, h * floorY(w * 0.79, w, 0.75)), h * 0.02, 1.1, color: const Color(0xFFF2B33D), fog: 0.3);

    // Mijlocul fundului nu rămâne gol: o stâncă joasă cu un coral-creier, la jumătatea adâncimii,
    // și câteva grupuri de pietricele (dau scară nisipului; fundul rămâne liber pentru pești).
    final midBase = Offset(w * 0.47, h * floorY(w * 0.47, w, 0.62));
    paintContactShadow(canvas, midBase + Offset(0, h * 0.004), h * 0.13, alpha: 0.22);
    paintRock(canvas, rockShape(midBase, h * 0.11, h * 0.045, r, bumps: 7), r, fog: 0.3, tone: const Color(0xFF8A9AA3));
    paintBrainCoral(canvas, midBase + Offset(h * 0.025, -h * 0.04), h * 0.022, fog: 0.3, color: const Color(0xFFE9A1C0));
    paintGrassTuft(canvas, midBase + Offset(-h * 0.05, 0), h * 0.045, r, fog: 0.3, color: const Color(0xFF4F9C63));
    for (final (fx, z, n) in [(0.22, 0.18, 5), (0.58, 0.3, 4), (0.86, 0.22, 3), (0.39, 0.82, 4)]) {
      _pebbles(canvas, Offset(w * fx, h * floorY(w * fx, w, z)), h * 0.009 * (1.25 - 0.6 * z), n, r, fog: z * 0.4);
    }
  }

  /// Câteva pietricele rotunjite, cu lumină de sus și umbră moale.
  void _pebbles(Canvas canvas, Offset c, double size, int n, math.Random r, {double fog = 0}) {
    const tones = [Color(0xFFB9AE9A), Color(0xFF9FA7A8), Color(0xFFD3C2A2), Color(0xFF8E9A9C)];
    for (var i = 0; i < n; i++) {
      final s = size * (0.6 + r.nextDouble() * 0.7);
      final p = c + Offset((r.nextDouble() - 0.5) * size * 6, (r.nextDouble() - 0.5) * size * 1.2);
      final rect = Rect.fromCenter(center: p, width: s * 2.2, height: s * 1.3);
      canvas.drawOval(rect.shift(Offset(s * 0.2, s * 0.35)), Paint()..color = Color.fromRGBO(60, 50, 30, 0.18 * (1 - fog)));
      final tone = fogged(tones[r.nextInt(tones.length)], fog);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(rect.center - Offset(s * 0.3, s * 0.35), s * 1.6, [
            Color.lerp(tone, const Color(0xFFFFFFFF), 0.35)!,
            tone,
            Color.lerp(tone, const Color(0xFF2B3A40), 0.3)!,
          ], const [0, 0.55, 1]),
      );
    }
  }

  /// Un șir de stânci în depărtare, ca o siluetă estompată, cu corali deasupra.
  void _ridge(
    Canvas canvas,
    Size size,
    math.Random r, {
    required double base,
    required double rise,
    required double fog,
    required double freq,
    required double seedShift,
  }) {
    final w = size.width, h = size.height;
    final p = Path()..moveTo(0, h);
    final tops = <Offset>[];
    for (var x = 0.0; x <= w + 20; x += 20) {
      final k = x / w;
      final y = h *
          (base -
              rise *
                  (0.45 +
                      0.35 * math.sin(k * freq * math.pi + seedShift) +
                      0.2 * math.sin(k * freq * 3.3 + seedShift * 2)).clamp(0.05, 1.0));
      p.lineTo(x, y);
      tops.add(Offset(x, y));
    }
    p
      ..lineTo(w, h)
      ..close();
    final col = fogged(const Color(0xFF557E8E), fog);
    canvas.drawPath(
      p,
      Paint()..shader = ui.Gradient.linear(Offset(0, h * (base - rise)), Offset(0, h * base), [lighten(col, 0.08), col]),
    );
    // Siluete de corali pe creastă.
    for (var i = 0; i < 6; i++) {
      final t = tops[(r.nextDouble() * (tops.length - 1)).floor()];
      if (r.nextBool()) {
        paintBranchCoral(canvas, t + Offset(0, h * 0.01), h * (0.06 + r.nextDouble() * 0.05), const Color(0xFF6A8FA0), r, fog: fog, depth: 2);
      } else {
        paintSoftCoral(canvas, t + Offset(0, h * 0.01), h * 0.04, r, fog: fog, color: const Color(0xFF7A97A6));
      }
    }
  }

  void _arch(Canvas canvas, Offset base, double width, double height, {required double fog}) {
    final outer = Path()
      ..moveTo(base.dx - width / 2, base.dy)
      ..cubicTo(base.dx - width * 0.55, base.dy - height * 0.9, base.dx - width * 0.2, base.dy - height * 1.08, base.dx + width * 0.05, base.dy - height)
      ..cubicTo(base.dx + width * 0.35, base.dy - height * 0.95, base.dx + width * 0.58, base.dy - height * 0.6, base.dx + width / 2, base.dy)
      ..close();
    final hole = Path()
      ..moveTo(base.dx - width * 0.22, base.dy + 2)
      ..cubicTo(base.dx - width * 0.2, base.dy - height * 0.62, base.dx + width * 0.2, base.dy - height * 0.66, base.dx + width * 0.24, base.dy + 2)
      ..close();
    final arch = Path.combine(PathOperation.difference, outer, hole);
    final col = fogged(const Color(0xFF6F8C98), fog);
    canvas.drawPath(arch, Paint()..shader = ui.Gradient.linear(Offset(0, base.dy - height), base, [lighten(col, 0.12), darken(col, 0.08)]));
  }

  /// Fundul de nisip în perspectivă: mai albastru în spate, cald în față, cu valuri care
  /// se rar spre noi și pietricele tot mai mari.
  void _floor(Canvas canvas, Size size, math.Random r) {
    final w = size.width, h = size.height;
    final floor = floorPath(size);
    final top = h * 0.75;
    canvas.drawPath(
      floor,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, h), [
          fogged(const Color(0xFFD9C79C), 0.55),
          fogged(const Color(0xFFE9D3A0), 0.2),
          const Color(0xFFF1DCA8),
          const Color(0xFFE2C287),
        ], [0, 0.3, 0.7, 1]),
    );
    canvas.save();
    canvas.clipPath(floor);
    // Valurile nisipului: perechi umbră + lumină, tot mai rare și mai groase în față.
    for (var i = 0; i < 26; i++) {
      final z = 1 - math.pow(i / 26, 0.8).toDouble();
      final y = h * floorY(w * 0.5, w, z);
      final thick = h * (0.002 + 0.006 * (1 - z));
      final shade = Path(), light = Path();
      final phase = r.nextDouble() * 6, amp = h * 0.006 * (1.3 - z);
      for (var x = -10.0; x <= w + 10; x += 12) {
        final yy = y + math.sin(x / w * (9 + i % 4) + phase) * amp + (floorY(x, w, z) - floorY(w * 0.5, w, z)) * h;
        x == -10 ? shade.moveTo(x, yy) : shade.lineTo(x, yy);
        x == -10 ? light.moveTo(x, yy - thick * 1.2) : light.lineTo(x, yy - thick * 1.2);
      }
      final a = 0.18 * (1 - z * 0.6);
      canvas.drawPath(
        shade,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick
          ..color = Color.fromRGBO(170, 130, 80, a),
      );
      canvas.drawPath(
        light,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick * 0.8
          ..color = Color.fromRGBO(255, 248, 225, a * 1.6),
      );
    }
    // Pietricele (mai mari în față).
    const shades = [Color(0xFFC9A877), Color(0xFFE9D3A3), Color(0xFFB79A72), Color(0xFFF4E6C4), Color(0xFFA9B4B0)];
    for (var i = 0; i < 90; i++) {
      final z = r.nextDouble();
      final x = r.nextDouble() * w;
      final c = Offset(x, h * floorY(x, w, z));
      final s = h * (0.0025 + r.nextDouble() * 0.006) * (1.25 - z);
      final col = fogged(shades[i % shades.length], z * 0.5);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(s * 0.2, s * 0.35), width: s * 2.4, height: s * 1.2), Paint()..color = const Color(0x22000000));
      canvas.drawOval(Rect.fromCenter(center: c, width: s * 2.4, height: s * 1.5), Paint()..color = col);
      canvas.drawOval(Rect.fromCenter(center: c - Offset(s * 0.35, s * 0.3), width: s, height: s * 0.5), Paint()..color = lighten(col, 0.45));
    }
    canvas.restore();
    // Spre orizont, fundul se pierde în apă.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.74, w, h * 0.1),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, h * 0.74), Offset(0, h * 0.84), [
          reefFog.withValues(alpha: 0.55),
          reefFog.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(ReefBackdropPainter old) => old.seed != seed;
}

/// Stâncile cu corali din colțurile de jos, în fața peștilor (ramă pentru scenă). Statice.
class ReefForegroundPainter extends CustomPainter {
  const ReefForegroundPainter({this.seed = 3});

  final int seed;

  /// Unde stă anemona (o desenează stratul animat, pe stânca din stânga).
  static Offset anemoneAt(Size s) => Offset(s.height * 0.2, s.height * 0.865);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = math.Random(seed);
    // Cât loc au colțurile: pe ecrane înguste, mai puțin.
    final side = math.min(h * 0.5, w * 0.24);

    // Stânga: evantai în spate, stâncă mare, coral ramificat roz, coral moale.
    paintFan(canvas, Offset(side * 0.15, h * 0.86), h * 0.36, r, color: const Color(0xFFB76FCF), lean: 0.22);
    paintBranchCoral(canvas, Offset(side * 0.68, h * 0.9), h * 0.24, const Color(0xFFF07C8C), r, depth: 3);
    final left = rockShape(Offset(side * 0.32, h * 1.02), side * 1.25, h * 0.2, r, rough: 0.28);
    paintRock(canvas, left, r, tone: const Color(0xFF7A8E9C));
    paintSoftCoral(canvas, Offset(side * 0.82, h * 0.985), h * 0.1, r, color: const Color(0xFFF2B33D));
    paintTubes(canvas, Offset(side * 0.05, h * 0.9), h * 0.9, r, color: const Color(0xFF6FC3B2), count: 3);

    // Dreapta: coral-masă, coral-creier, bureți, coral ramificat portocaliu.
    final right = rockShape(Offset(w - side * 0.35, h * 1.03), side * 1.35, h * 0.24, r, rough: 0.3);
    paintBranchCoral(canvas, Offset(w - side * 0.28, h * 0.86), h * 0.26, const Color(0xFFF59A45), r, depth: 3);
    paintTableCoral(canvas, Offset(w - side * 0.85, h * 0.9), h * 0.19, color: const Color(0xFF5FC4A8));
    paintRock(canvas, right, r, tone: const Color(0xFF80909E));
    paintTubes(canvas, Offset(w - side * 0.62, h * 0.885), h, r);
    paintBrainCoral(canvas, Offset(w - side * 0.12, h * 0.9), h * 0.06);
    paintSoftCoral(canvas, Offset(w - side * 0.95, h * 0.975), h * 0.075, r, color: const Color(0xFFE86FA0));
  }

  @override
  bool shouldRepaint(ReefForegroundPainter old) => old.seed != seed;
}

void _bubble(Canvas canvas, Offset c, double r, double alpha) {
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(c + Offset(r * 0.2, r * 0.25), r, [
        Color.fromRGBO(220, 250, 255, 0.05 * alpha),
        Color.fromRGBO(220, 250, 255, 0.28 * alpha),
      ]),
  );
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..color = Color.fromRGBO(255, 255, 255, 0.65 * alpha),
  );
  canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.38), r * 0.24, Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * alpha));
}

/// O bulă de aer (cu luciu), pentru toate straturile.
void paintBubble(Canvas canvas, Offset c, double r, double alpha) => _bubble(canvas, c, r, alpha);
