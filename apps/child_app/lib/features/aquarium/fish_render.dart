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
  // Al doilea strat al plasei: luciul de pe spate și lumina rece de pe margini.
  final _gloss = Int32List(_n);
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

    // 1. Direcția fiecărei felii (coloane) — de la coadă (c = 0) la cap. Unda trece spre
    //    coadă cu o lungime de undă cam cât corpul (înot „carangiform”); capul se clatină
    //    puțin invers (reculul), iar înotătoarea caudală, mai moale, vine cu întârziere și
    //    biciuiește mai larg decât corpul.
    final caudal = frame.length * 0.2;
    for (var c = 0; c <= _cols; c++) {
      final bx = x0 + (x1 - x0) * c / _cols;
      final tt = ((frame.head - bx) / frame.length).clamp(0.0, 1.0); // 0 la cap, 1 la coadă
      final body = amp * (0.06 + 0.94 * tt * tt) * math.sin(f.phase - tt * 3.6);
      final recoil = -amp * 0.05 * (1 - tt) * (1 - tt) * math.sin(f.phase);
      final tail = ((frame.tail + caudal - bx) / caudal).clamp(0.0, 1.0);
      final whip = amp * 0.55 * tail * tail * math.sin(f.phase - tt * 3.6 - 0.9);
      _psi[c] = f.yaw + body + recoil + whip + bend * math.pow(tt, 1.3);
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
    // Înclinarea în viraj (ca un pește adevărat care se apleacă spre interiorul curbei):
    // partea de sus a corpului se luminează sau se umbrește.
    final roll = (f.turnRate * 0.11).clamp(-0.45, 0.45) * _softSign(math.cos(f.yaw));
    // Înotătoarele de sus și de jos ondulează mereu, mai tare când peștele stă pe loc
    // (atunci ele îl țin în echilibru), cu o undă care merge spre coadă.
    final ripple = 4 + 7 * (1 - (f.effort / 1.6).clamp(0.0, 1.0));
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
        final fin = edge * edge * edge * math.sin(f.phase * 1.7 - tt * 9) * ripple;
        _pos[i * 2] = (_sx[c] - ox) + side;
        _pos[i * 2 + 1] = by - midY + fin;
        _tex[i * 2] = bx * texScale;
        _tex[i * 2 + 1] = by * texScale;

        // Lumina: felia văzută din față e luminată, cea văzută pe muchie e mai întunecată;
        // peste ea, reflexele apei care se mișcă pe pește.
        final wx = (px + _pos[i * 2] * k) / h, wy = (py + _pos[i * 2 + 1] * k) / h;
        final caustic = 0.07 * math.sin(wx * 21 + t * 1.6) * math.sin(wy * 17 - t * 1.25 + wx * 5);
        final top = (by - midY) / halfH; // −1 sus … +1 jos
        // Volumul: lumina vine de sus, prin apă — spatele e mai luminos, burta și marginile
        // rotunjite intră în umbră (ca la un corp, nu ca la o foaie).
        final belly = math.max(0.0, top);
        final shade = (0.66 + 0.24 * math.pow(cs.abs(), 0.7) + 0.12 * round + caustic - roll * top * 0.16 - 0.08 * top - 0.14 * belly * belly)
            .clamp(0.42, 1.0);
        // Înotătoarele (marginile plasei și coada) sunt ușor translucide: apa se vede prin ele.
        final finness = math.max(_smooth(0.72, 0.97, edge), _smooth(0.9, 1.0, tt) * edge);
        _colors[i] = _argb(shade * absorbR, shade * absorbG, shade, 1 - 0.22 * finness);
        // Luciul: o dungă pe partea de sus a corpului, cea mai vie unde felia stă spre noi;
        // lumina rece pe margini: apa luminată din spatele peștelui.
        final band = math.exp(-math.pow((top + 0.45) / 0.24, 2));
        final spec = 0.42 * band * cs * cs * (0.25 + 0.75 * profile) * (1 - fog * 2.2) * (1 + caustic * 3);
        final rim = 0.24 * math.pow(edge, 6) * (top < 0 ? 1.0 : 0.55) * (1 - fog * 2);
        _gloss[i] = _glossColor(spec, rim);
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
    // În viraj corpul se apleacă: văzut puțin de sus sau de jos, pare mai scund.
    if (roll != 0) canvas.scale(1, 1 - 0.14 * roll.abs());
    final v = ui.Vertices.raw(ui.VertexMode.triangles, _pos, textureCoordinates: _tex, colors: _colors, indices: _idx);
    // Un strat cât peștele: luciul se pune doar peste pixelii corpului (srcATop).
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (var q = 0; q < _n; q++) {
      final x = _pos[q * 2], y = _pos[q * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final glossy = fog < 0.2;
    if (glossy) canvas.saveLayer(Rect.fromLTRB(minX, minY, maxX, maxY).inflate(4), Paint());
    canvas.drawVertices(
      v,
      BlendMode.modulate,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ui.ImageShader(img, TileMode.decal, TileMode.decal, _identity)
        ..colorFilter = fog > 0.01 ? _fogFilter(fog) : null,
    );
    v.dispose();
    if (glossy) {
      final g = ui.Vertices.raw(ui.VertexMode.triangles, _pos, colors: _gloss, indices: _idx);
      canvas.drawVertices(g, BlendMode.dst, Paint()..blendMode = BlendMode.srcATop);
      g.dispose();
      canvas.restore();
    }

    // Ochiul: o sclipire mică, ca pe un ochi umed (doar cu peștele din profil).
    final headSide = math.cos(_psi[_cols]);
    if (headSide.abs() > 0.35 && puff < 0.6) {
      final (eye, er) = species.eye;
      final ef = ((eye.x - x0) / (x1 - x0) * _cols).clamp(0.0, _cols - 1.0);
      final ei = ef.floor(), erem = ef - ei;
      final ex = _sx[ei] + (_sx[ei + 1] - _sx[ei]) * erem - ox;
      final forward = (_sx[_cols] - _sx[0]).sign;
      final c = Offset(ex + forward * er * 0.22, eye.y - midY - er * 0.3);
      final a = (0.85 * math.min(1.0, (headSide.abs() - 0.35) * 4) * (1 - fog * 2.5)).clamp(0.0, 1.0);
      canvas.drawCircle(c, er * 0.3, Paint()..color = Color.fromRGBO(255, 255, 255, a));
      canvas.drawCircle(c + Offset(-forward * er * 0.38, er * 0.42), er * 0.12, Paint()..color = Color.fromRGBO(255, 255, 255, a * 0.6));
    }

    // Înotătoarea pectorală (cea dinspre noi): vâslește repede când peștele stă pe loc sau
    // frânează, se lipește de corp când țâșnește.
    final side = math.cos(_psi[_cols]);
    if (side.abs() > 0.2 && puff < 0.5) {
      final (eye, er) = species.eye;
      final bx = eye.x - er * 4.2;
      final cc = ((bx - x0) / (x1 - x0) * _cols).clamp(0.0, _cols.toDouble()).round();
      final base = Offset(_sx[cc] - ox, halfH * 0.2);
      final effort = (f.effort / 2).clamp(0.0, 1.0);
      final flap = math.sin(f.phase * (1.4 - 0.6 * effort) + 1.3) * (0.55 - 0.4 * effort);
      final fold = 0.25 + 0.5 * effort; // lipită de corp la viteză mare
      final tone = Color.lerp(_toneOf(img), const Color(0xFFFFFFFF), 0.08)!;
      _pectoral(canvas, base, er * 3.8, side.sign, fold + flap, Color.lerp(tone, tankFog, fog)!, 0.8 * math.min(1.0, (side.abs() - 0.2) * 3));
    }

    // Cu capul spre noi (sau cu coada): vederea din față, ca peștele să nu devină o „felie”.
    final headCs = math.cos(_psi[_cols]), headSn = math.sin(_psi[_cols]);
    final front = ((0.36 - headCs.abs()) / 0.24).clamp(0.0, 1.0);
    if (front > 0.01) {
      final tone = _toneOf(img);
      final body = (frame.bottom - frame.top) * 0.6;
      // Pe corpul rotund se întinde chiar desenul copilului din spatele capului (dungi, pete).
      final (eye, er) = species.eye;
      final src = Rect.fromLTRB(
        (eye.x - frame.length * 0.42) * texScale,
        (frame.top + (frame.bottom - frame.top) * 0.16) * texScale,
        (eye.x - er * 1.6) * texScale,
        (frame.bottom - (frame.bottom - frame.top) * 0.16) * texScale,
      );
      _frontView(
        canvas,
        Offset(((headSn < 0 ? _sx[_cols] : _sx[0]) - ox) * 0.45, 0),
        body,
        body * (0.55 + species.thickness * 2.4),
        towardUs: headSn < 0,
        tone: Color.lerp(tone, tankFog, fog)!,
        alpha: front,
        phase: f.phase,
        skin: (img, src),
        fog: fog,
      );
    }
    if (puff > 0.02) {
      final turn = f.facing.abs() < 0.3 ? 0.3 * (f.facing >= 0 ? 1 : -1) : f.facing;
      canvas.scale(turn, 1);
      canvas.translate(-frame.center.dx, -frame.center.dy);
      _spikes(canvas, species, puff, fog);
    }
    canvas.restore();
  }

  /// Înotătoarea pectorală: un evantai translucid cu raze, prins în [base], întors spre coadă
  /// ([dir] = semnul direcției capului pe ecran), deschis sub unghiul [angle].
  void _pectoral(Canvas canvas, Offset base, double len, double dir, double angle, Color tone, double alpha) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(-dir, 1); // spre coadă
    canvas.rotate(angle);
    final fan = Path()
      ..moveTo(0, -len * 0.12)
      ..quadraticBezierTo(len * 0.7, -len * 0.42, len, -len * 0.18)
      ..quadraticBezierTo(len * 1.05, len * 0.12, len * 0.8, len * 0.32)
      ..quadraticBezierTo(len * 0.4, len * 0.3, 0, len * 0.12)
      ..close();
    canvas.drawPath(
      fan,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(len, 0), [
          tone.withValues(alpha: alpha),
          tone.withValues(alpha: alpha * 0.45),
        ]),
    );
    canvas.drawPath(
      fan,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = len * 0.03
        ..color = Color.lerp(tone, const Color(0xFF14202A), 0.45)!.withValues(alpha: alpha * 0.5),
    );
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.025
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(tone, const Color(0xFF14202A), 0.4)!.withValues(alpha: alpha * 0.55);
    for (var k = 0; k < 5; k++) {
      final a = -0.32 + k * 0.17;
      canvas.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * len * (0.82 + 0.1 * math.sin(k * 1.7)), ray);
    }
    canvas.restore();
  }

  /// Peștele văzut din față (ochii amândoi, gura care se deschide) sau din spate (coada care
  /// bate). [h] = înălțimea corpului, [w] = lățimea lui (unități de desen).
  void _frontView(
    Canvas canvas,
    Offset c,
    double h,
    double w, {
    required bool towardUs,
    required Color tone,
    required double alpha,
    required double phase,
    (ui.Image, Rect)? skin,
    double fog = 0,
  }) {
    Color a(Color x) => x.withValues(alpha: x.a * alpha);
    final dark = Color.lerp(tone, const Color(0xFF14202A), 0.35)!, light = Color.lerp(tone, const Color(0xFFFFFFFF), 0.35)!;
    final fin = Paint()..color = a(dark);
    // Înotătoarea de pe spate și cea de dedesubt (subțiri, văzute din față).
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w * 0.07, c.dy - h * 0.45)
        ..quadraticBezierTo(c.dx, c.dy - h * 0.95, c.dx + w * 0.07, c.dy - h * 0.45)
        ..close(),
      fin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w * 0.06, c.dy + h * 0.45)
        ..quadraticBezierTo(c.dx, c.dy + h * 0.8, c.dx + w * 0.06, c.dy + h * 0.45)
        ..close(),
      fin,
    );
    if (!towardUs) {
      // Din spate: coada bate stânga–dreapta, în fața corpului.
      final sway = math.sin(phase) * w * 0.35;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - h * 0.15)
          ..quadraticBezierTo(c.dx + sway, c.dy - h * 0.9, c.dx + sway * 1.2, c.dy - h * 0.75)
          ..lineTo(c.dx + sway * 1.2, c.dy + h * 0.75)
          ..quadraticBezierTo(c.dx + sway, c.dy + h * 0.9, c.dx, c.dy + h * 0.15)
          ..close(),
        Paint()..color = a(Color.lerp(dark, tone, 0.4)!),
      );
    }
    // Înotătoarele de pe lateral, care vâslesc.
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx + side * w * 0.5, c.dy + h * 0.12);
      canvas.rotate(side * (0.5 + 0.35 * math.sin(phase * 0.8)));
      canvas.drawOval(Rect.fromCenter(center: Offset(side * w * 0.12, 0), width: w * 0.32, height: h * 0.16), fin);
      canvas.restore();
    }
    // Corpul: rotund, cu desenul peștelui pe el, luminat de sus și umbrit pe margini.
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    if (skin case (final img, final src)) {
      final sx = rect.width / src.width, sy = rect.height / src.height;
      final m = Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, rect.left - src.left * sx, rect.top - src.top * sy, 0, 1]);
      canvas.drawOval(
        rect,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, alpha)
          ..filterQuality = FilterQuality.medium
          ..shader = ui.ImageShader(img, TileMode.clamp, TileMode.clamp, m)
          ..colorFilter = fog > 0.01 ? _fogFilter(fog) : null,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(c - Offset(w * 0.1, h * 0.25), h * 0.75, [
            Color.fromRGBO(255, 255, 255, 0.35 * alpha),
            const Color(0x00FFFFFF),
            Color.fromRGBO(10, 25, 40, 0.45 * alpha),
          ], const [0, 0.5, 1]),
      );
    } else {
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(c - Offset(0, h * 0.2), h * 0.7, [a(light), a(tone), a(dark)], const [0, 0.55, 1]),
      );
    }
    if (!towardUs) return;
    // Ochii, unul de fiecare parte, și gura care se deschide și se închide.
    for (final side in [-1.0, 1.0]) {
      final e = c + Offset(side * w * 0.36, -h * 0.12);
      final r = h * 0.13;
      canvas.drawCircle(e, r * 1.12, Paint()..color = a(const Color(0x55000000)));
      canvas.drawCircle(e, r, Paint()..color = a(const Color(0xFFF7FAFC)));
      canvas.drawCircle(e + Offset(-side * r * 0.15, r * 0.05), r * 0.55, Paint()..color = a(const Color(0xFF151820)));
      canvas.drawCircle(e + Offset(-side * r * 0.3, -r * 0.2), r * 0.18, Paint()..color = a(const Color(0xFFFFFFFF)));
    }
    final open = 0.5 + 0.5 * math.sin(phase * 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, h * 0.22), width: w * 0.16, height: h * (0.04 + 0.06 * open)),
      Paint()..color = a(const Color(0xFF3A1E24)),
    );
  }

  /// Culoarea medie a peștelui (pentru vederea din față); se calculează o dată, în fundal.
  static final _tones = Expando<Color>();
  static final _pending = Expando<bool>();

  static Color _toneOf(ui.Image img) {
    final t = _tones[img];
    if (t != null) return t;
    if (_pending[img] == null) {
      _pending[img] = true;
      img.toByteData().then((bytes) {
        if (bytes == null) return;
        var r = 0, g = 0, b = 0, n = 0;
        final px = bytes.buffer.asUint8List();
        for (var i = 0; i < px.length; i += 16) {
          if (px[i + 3] < 230) continue;
          r += px[i];
          g += px[i + 1];
          b += px[i + 2];
          n++;
        }
        _tones[img] = n == 0 ? const Color(0xFF7FA6C2) : Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
      });
    }
    return const Color(0xFF7FA6C2);
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

/// Culoarea luciului: alb pentru dunga de pe spate, albastru-deschis pentru lumina de pe margini.
int _glossColor(double spec, double rim) {
  final a = (spec + rim).clamp(0.0, 0.6);
  if (a <= 0.002) return 0;
  final k = rim / (spec + rim);
  final r = (255 - 64 * k).round(), g = (255 - 11 * k).round();
  return ((a * 255).round() << 24) | (r << 16) | (g << 8) | 255;
}

double _softSign(double x) {
  final e = math.exp(-2 * x * 5);
  return (1 - e) / (1 + e);
}

int _argb(double r, double g, double b, [double a = 1]) =>
    ((a.clamp(0.0, 1.0) * 255).round() << 24) |
    ((r.clamp(0.0, 1.0) * 255).round() << 16) |
    ((g.clamp(0.0, 1.0) * 255).round() << 8) |
    (b.clamp(0.0, 1.0) * 255).round();

/// 0 sub [a], 1 peste [b], lin între ele.
double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

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
