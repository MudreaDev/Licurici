import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../shared/stimulus_art.dart';

/// O vietate care înoată (Pescarul): poza din [swimPose] aplicată desenului. La pești, desenul
/// pictat e întins pe o plasă de felii verticale care urmează unda din corp ([bodyWave]) — capul
/// stă, coada bate, mai repede când împinge; caracatița se strânge și se întinde; crabul se
/// leagănă. Fără ilustrație pictată (doar OpenMoji) rămân înclinarea și legănarea.
/// Desenele pictate privesc spre dreapta; [flip] le întoarce spre stânga.
class SwimmingArt extends StatefulWidget {
  const SwimmingArt({super.key, required this.emoji, required this.size, required this.pose, required this.flip});

  final String emoji;
  final double size;
  final SwimPose pose;
  final bool flip;

  @override
  State<SwimmingArt> createState() => _SwimmingArtState();
}

class _SwimmingArtState extends State<SwimmingArt> {
  ui.Image? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _image = info.image);
  }, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SwimmingArt old) {
    super.didUpdateWidget(old);
    if (old.emoji != widget.emoji) {
      _image = null;
      _resolve();
    }
  }

  void _resolve() {
    final sprite = swimStyleFor(widget.emoji) == SwimStyle.fish ? spriteFor(widget.emoji) : null;
    final stream = sprite?.resolve(createLocalImageConfiguration(context));
    if (stream?.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream?..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pose = widget.pose;
    final style = swimStyleFor(widget.emoji);
    final image = _image;
    Widget body = image != null && style == SwimStyle.fish
        ? CustomPaint(size: Size.square(widget.size), painter: _FishMeshPainter(image, pose))
        : StimulusArt(widget.emoji, size: widget.size);
    if (style == SwimStyle.jet) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(pose.squash, 1 / pose.squash, 1),
        child: body,
      );
    }
    body = Transform.translate(
      offset: Offset(0, pose.sway * widget.size),
      child: Transform.rotate(angle: pose.tilt, child: body),
    );
    return widget.flip
        ? Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: body)
        : body;
  }
}

/// Desenul pe o plasă de [_columns] felii verticale (două rânduri de vârfuri: sus și jos);
/// fiecare felie e deplasată pe verticală cu unda corpului în acel loc.
class _FishMeshPainter extends CustomPainter {
  _FishMeshPainter(this.image, this.pose);

  final ui.Image image;
  final SwimPose pose;

  static const _columns = 16;

  @override
  void paint(Canvas canvas, Size size) {
    // Desenul încape în pătrat păstrându-și proporțiile.
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = math.min(size.width / iw, size.height / ih);
    final w = iw * scale, h = ih * scale;
    final left = (size.width - w) / 2, top = (size.height - h) / 2;

    final positions = Float32List((_columns + 1) * 2 * 2);
    final texture = Float32List((_columns + 1) * 2 * 2);
    for (var c = 0; c <= _columns; c++) {
      final u = c / _columns; // 0 = marginea stângă (coada), 1 = dreapta (botul)
      final dy = bodyWave(1 - u, pose) * h;
      final x = left + u * w;
      for (var r = 0; r < 2; r++) {
        final i = (c * 2 + r) * 2;
        positions[i] = x;
        positions[i + 1] = top + r * h + dy;
        texture[i] = u * iw;
        texture[i + 1] = r * ih;
      }
    }
    final indices = Uint16List(_columns * 6);
    for (var c = 0; c < _columns; c++) {
      final a = c * 2, b = c * 2 + 1, d = c * 2 + 2, e = c * 2 + 3;
      indices.setAll(c * 6, [a, b, d, b, e, d]);
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, positions, textureCoordinates: texture, indices: indices);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ui.ImageShader(image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }

  @override
  bool shouldRepaint(_FishMeshPainter old) =>
      old.image != image || old.pose.tailPhase != pose.tailPhase || old.pose.thrust != pose.thrust;
}
