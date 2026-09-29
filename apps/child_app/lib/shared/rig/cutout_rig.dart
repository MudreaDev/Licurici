import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../motion.dart';
import 'rig_data.dart';
import 'rig_pose.dart';

/// Personaj decupat pe straturi, animat procedural din cod (ADR-028): respirație, plutire,
/// bătaie din aripi, clipit, lanterna care strălucește, bagheta cu scântei la bucurie,
/// înclinare la încurajare, somn. Generic: orice personaj cu `rig.json` + straturi PNG.
///
/// Totul trece prin [motion]: idle doar la `full`, reacțiile cu mișcare doar dacă `movement`,
/// `gentle` păstrează doar lumina lanternei, `off` = poză statică (niciun ticker nu rulează).
/// Schimbă [reaction] (ex. un contor) ca să redeclanșezi aceeași stare.
class CutoutRig extends StatefulWidget {
  const CutoutRig({
    super.key,
    required this.rig,
    required this.motion,
    this.mood = MascotMood.idle,
    this.reaction = 0,
  });

  final LoadedRig rig;
  final MotionPolicy motion;
  final MascotMood mood;
  final int reaction;

  @override
  State<CutoutRig> createState() => _CutoutRigState();
}

class _CutoutRigState extends State<CutoutRig> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (RigPose.loop * 1000).round()),
  );
  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void initState() {
    super.initState();
    _syncIdle();
  }

  @override
  void didUpdateWidget(CutoutRig old) {
    super.didUpdateWidget(old);
    _syncIdle();
    final reacts =
        widget.mood == MascotMood.happy || widget.mood == MascotMood.encourage;
    if ((old.reaction != widget.reaction || old.mood != widget.mood) &&
        reacts &&
        widget.motion.feedback) {
      _react.forward(from: 0);
    } else if (!reacts && _react.isAnimating) {
      _react.value = 0;
    }
  }

  void _syncIdle() {
    if (widget.motion.ambient) {
      if (!_idle.isAnimating) _idle.repeat();
    } else if (_idle.isAnimating) {
      _idle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_idle, _react]),
    builder: (context, _) => CustomPaint(
      size: Size.infinite,
      painter: RigPainter(
        widget.rig,
        RigPose.of(
          mood: widget.mood,
          t: _idle.value * RigPose.loop,
          r: _react.isAnimating ? _react.value : 0,
          motion: widget.motion,
        ),
      ),
    ),
  );
}

/// Desenează straturile cu transformările din [pose], plus efectele din cod (lumina lanternei,
/// pleoapele, scânteile). Personajul e încadrat „contain” în dimensiunea primită.
class RigPainter extends CustomPainter {
  RigPainter(this.rig, this.pose);

  final LoadedRig rig;
  final RigPose pose;

  static const _warm = Color(0xFFFFE9A0);
  static const _sparkColors = [
    Color(0xFFFFE17A),
    Color(0xFFFFF4C4),
    Color(0xFFF2B84B),
    Color(0xFFC9B8F0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final data = rig.data;
    final body = data.layers['body'];
    final view = data.bounds.inflate(data.bounds.longestSide * 0.04);
    final scale = math.min(size.width / view.width, size.height / view.height);
    final feet = body == null
        ? view.bottomCenter
        : Offset(body.rect.center.dx, body.rect.bottom);
    final center = body?.rect.center ?? view.center;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-view.center.dx, -view.center.dy)
      // plutire / săritură
      ..translate(0, pose.hover);
    _around(canvas, center, () => canvas.rotate(pose.tilt));
    _around(
      canvas,
      feet,
      () => canvas.scale(1 + pose.squash * 0.6, 1 - pose.squash),
    );

    _halo(canvas);
    for (final layer in data.layers.values) {
      switch (layer.name) {
        case 'wing_left' || 'wing_right':
          final up = pose.wing + pose.wingRest;
          _layer(canvas, layer, angle: layer.name == 'wing_left' ? up : -up);
        case 'arm':
          _layer(canvas, layer, angle: pose.arm);
          _sparkles(canvas, layer);
        case 'body':
          canvas.save();
          _around(
            canvas,
            feet,
            () => canvas.scale(1 - pose.breath * 0.4, 1 + pose.breath),
          );
          _image(canvas, layer);
          _lantern(canvas);
          _eyelids(canvas);
          canvas.restore();
        default:
          _image(canvas, layer);
      }
    }
    canvas.restore();
  }

  /// Aplică [transform] în jurul punctului [p].
  void _around(Canvas canvas, Offset p, void Function() transform) {
    canvas.translate(p.dx, p.dy);
    transform();
    canvas.translate(-p.dx, -p.dy);
  }

  void _layer(Canvas canvas, RigLayer layer, {double angle = 0}) {
    canvas.save();
    _around(canvas, layer.origin, () => canvas.rotate(angle));
    _image(canvas, layer);
    canvas.restore();
  }

  void _image(Canvas canvas, RigLayer layer) {
    final img = rig.images[layer.name];
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      layer.rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Lumina din jurul licuriciului (în spatele aripilor).
  void _halo(Canvas canvas) {
    final a = rig.data.anchors;
    if (a.lantern == null) return;
    final r = a.lanternRadius * (2.2 + 0.6 * pose.glow);
    final alpha = (0.28 * pose.glow).clamp(0.0, 0.5);
    canvas.drawCircle(
      a.lantern!,
      r,
      Paint()
        ..shader = ui.Gradient.radial(a.lantern!, r, [
          _warm.withValues(alpha: alpha),
          _warm.withValues(alpha: 0),
        ]),
    );
  }

  /// Burta: se luminează peste desen (screen) sau se stinge (multiply, la somn).
  void _lantern(Canvas canvas) {
    final a = rig.data.anchors;
    if (a.lantern == null) return;
    final r = a.lanternRadius * 1.15;
    final c = a.lantern!;
    final bright = ((pose.glow - 0.6) * 0.8).clamp(0.0, 0.75);
    if (bright > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              const Color(0xFFFFF6D0).withValues(alpha: bright),
              const Color(0xFFFFE08A).withValues(alpha: bright * 0.5),
              const Color(0x00FFE08A),
            ],
            [0, 0.55, 1],
          ),
      );
    }
    final dim = ((0.6 - pose.glow) * 2.6).clamp(0.0, 0.75);
    if (dim > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              const Color(0xFF5E5040).withValues(alpha: dim),
              const Color(0xFF5E5040).withValues(alpha: dim * 0.8),
              const Color(0x005E5040),
            ],
            [0, 0.75, 1],
          ),
      );
    }
  }

  /// Pleoapa coboară peste ochi (clipit, somn), cu o linie de gene la margine.
  void _eyelids(Canvas canvas) {
    final blink = pose.blink.clamp(0.0, 1.0);
    if (blink <= 0.01) return;
    final a = rig.data.anchors;
    for (final eye in a.eyes) {
      final rect = eye.rect.inflate(eye.radius.height * 0.12);
      final edge = rect.top + rect.height * blink;
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect));
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, rect.right, edge),
        Paint()..color = a.skin,
      );
      canvas
        ..drawArc(
          Rect.fromLTRB(
            rect.left,
            edge - rect.height * 0.12,
            rect.right,
            edge + rect.height * 0.12,
          ),
          0.15,
          math.pi - 0.3,
          false,
          Paint()
            ..color = const Color(0xFF2E3A48)
            ..style = PaintingStyle.stroke
            ..strokeWidth = eye.radius.height * 0.14
            ..strokeCap = StrokeCap.round,
        )
        ..restore();
    }
  }

  /// Scântei din vârful baghetei (urmează brațul rotit).
  void _sparkles(Canvas canvas, RigLayer arm) {
    final p = pose.sparkle;
    final tip = rig.data.anchors.wandTip;
    if (p == null || tip == null) return;
    final o = arm.origin;
    final v = tip - o;
    final cs = math.cos(pose.arm), sn = math.sin(pose.arm);
    final at = o + Offset(v.dx * cs - v.dy * sn, v.dx * sn + v.dy * cs);
    final e = Curves.easeOutCubic.transform(p);
    final fade = (1 - p).clamp(0.0, 1.0);

    // sclipirea din vârf
    final flash = math.sin(math.pi * p.clamp(0.0, 0.5) * 2);
    canvas.drawCircle(
      at,
      70 * flash,
      Paint()
        ..shader = ui.Gradient.radial(at, 70 * flash + 0.01, [
          const Color(0xFFFFFBE6).withValues(alpha: 0.9 * flash),
          const Color(0x00FFE17A),
        ]),
    );
    const n = 9;
    for (var i = 0; i < n; i++) {
      // evantai în sus, cu unghiuri fixe (deterministe)
      final angle =
          -math.pi / 2 + (i - (n - 1) / 2) * 0.42 + math.sin(i * 7.1) * 0.12;
      final dist = (90 + 40 * (i % 3)) * e * 2;
      final pos =
          at +
          Offset(math.cos(angle), math.sin(angle)) * dist +
          Offset(0, 80 * p * p);
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(p * math.pi * (i.isEven ? 1 : -1));
      canvas
        ..drawPath(
          _star((16 + 6 * (i % 3)) * (0.5 + 0.5 * fade)),
          Paint()
            ..color = _sparkColors[i % _sparkColors.length].withValues(
              alpha: fade,
            ),
        )
        ..restore();
    }
  }

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(math.cos(a) * radius, math.sin(a) * radius);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(RigPainter old) => old.rig != rig || old.pose != pose;
}
