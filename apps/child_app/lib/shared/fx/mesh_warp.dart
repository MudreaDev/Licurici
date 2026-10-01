import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Deformarea unui punct al imaginii. [p] e poziția nedeformată în coordonate normalizate
/// (0..1 pe lățime și înălțime); rezultatul e poziția deformată, tot normalizată.
typedef Warp = Offset Function(Offset p);

/// Deformări de bază, compozabile (ADR-028: animația vine din cod, nu din fișiere).
abstract final class Warps {
  static Offset identity(Offset p) => p;

  /// Aplică pe rând deformările.
  static Warp chain(List<Warp> warps) => (p) {
    for (final w in warps) {
      p = w(p);
    }
    return p;
  };

  /// O aripă (sau orice „foaie” prinsă într-un punct) care bate: rotația crește cu distanța
  /// față de [pivot], deci vârful rămâne în urmă și aripa se arcuiește, nu doar se rotește.
  /// [aspect] = lățime / înălțime a imaginii (ca rotația să nu fie turtită).
  static Warp flap({
    required Offset pivot,
    required double angle,
    double aspect = 1,
    double bend = 1.4,
  }) => (p) {
    final d = Offset((p.dx - pivot.dx) * aspect, p.dy - pivot.dy);
    final reach = math.min(1.0, d.distance / 0.6);
    final a = angle * math.pow(reach, bend);
    final c = math.cos(a), s = math.sin(a);
    final r = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    return Offset(pivot.dx + r.dx / aspect, pivot.dy + r.dy);
  };

  /// Respirație / strângere-întindere ancorată jos (picioarele rămân pe loc).
  /// [amount] > 0 = se lungește și se subțiază; < 0 = se turtește (aterizare).
  static Warp squash(double amount, {double anchorY = 1}) =>
      (p) => Offset(
        0.5 + (p.dx - 0.5) * (1 - amount * 0.5),
        anchorY + (p.dy - anchorY) * (1 + amount),
      );

  /// Legănare (iarbă, pelerină, steag): partea de sus se mișcă, baza rămâne fixă.
  static Warp sway(double amount, {double stiffness = 2}) =>
      (p) => Offset(p.dx + amount * math.pow(1 - p.dy, stiffness), p.dy);

  /// Undă care trece prin imagine (apă, steag în vânt).
  static Warp wave(double amplitude, double phase, {double frequency = 2}) =>
      (p) => Offset(
        p.dx,
        p.dy +
            amplitude *
                math.sin((p.dx * frequency + phase) * math.pi * 2) *
                (1 - p.dy),
      );
}

/// Desenează [image] pe o plasă de [cols]×[rows] celule deformată de [warp].
/// Imaginea ocupă dreptunghiul [rect] din pânză (implicit toată pânza).
class MeshWarpPainter extends CustomPainter {
  MeshWarpPainter({
    required this.image,
    required this.warp,
    this.cols = 14,
    this.rows = 14,
    this.opacity = 1,
    super.repaint,
  });

  final ui.Image image;
  final Warp Function() warp;
  final int cols, rows;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = warp();
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final n = (cols + 1) * (rows + 1);
    final positions = Float32List(n * 2);
    final tex = Float32List(n * 2);
    var k = 0;
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        final p = Offset(x / cols, y / rows);
        final q = w(p);
        positions[k] = q.dx * size.width;
        positions[k + 1] = q.dy * size.height;
        tex[k] = p.dx * iw;
        tex[k + 1] = p.dy * ih;
        k += 2;
      }
    }
    final indices = Uint16List(cols * rows * 6);
    k = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final i = y * (cols + 1) + x;
        indices
          ..[k++] = i
          ..[k++] = i + 1
          ..[k++] = i + cols + 1
          ..[k++] = i + 1
          ..[k++] = i + cols + 2
          ..[k++] = i + cols + 1;
      }
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: tex,
      indices: indices,
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList(const [
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
      );
    if (opacity < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    if (opacity < 1) canvas.restore();
    vertices.dispose();
  }

  @override
  bool shouldRepaint(MeshWarpPainter old) =>
      old.image != image ||
      old.cols != cols ||
      old.rows != rows ||
      old.opacity != opacity;
}

/// Un asset de imagine desenat deformat. Cât timp imaginea se încarcă (sau dacă lipsește)
/// nu desenează nimic — cine îl folosește își alege rezerva prin [placeholder].
class WarpedImage extends StatefulWidget {
  const WarpedImage({
    super.key,
    required this.image,
    required this.warp,
    this.repaint,
    this.cols = 14,
    this.rows = 14,
    this.placeholder,
  });

  final ImageProvider image;

  /// Citită la fiecare cadru (de obicei închide peste un AnimationController).
  final Warp Function() warp;
  final Listenable? repaint;
  final int cols, rows;
  final Widget? placeholder;

  @override
  State<WarpedImage> createState() => _WarpedImageState();
}

class _WarpedImageState extends State<WarpedImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }, onError: (e, _) => debugPrint('imagine indisponibilă: $e'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(WarpedImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return widget.placeholder ?? const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: MeshWarpPainter(
        image: info.image,
        warp: widget.warp,
        cols: widget.cols,
        rows: widget.rows,
        repaint: widget.repaint,
      ),
    );
  }
}
