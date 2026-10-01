import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../motion.dart';
import 'fireflies.dart';

/// Ce shader desenează scena.
enum SceneKind { meadow, water }

/// Programele de shader se compilează o singură dată pe aplicație.
abstract final class SceneShaders {
  static final _programs = <SceneKind, Future<ui.FragmentProgram?>>{};

  static Future<ui.FragmentProgram?> load(SceneKind kind) => _programs[kind] ??=
      ui.FragmentProgram.fromAsset(switch (kind) {
        SceneKind.meadow => 'shaders/meadow.frag',
        SceneKind.water => 'shaders/water.frag',
      }).then<ui.FragmentProgram?>(
        (p) => p,
        onError: (Object e) {
          debugPrint('shader indisponibil ($kind): $e');
          return null;
        },
      );

  /// Pornește compilarea din timp (ecranul de pornire), ca prima scenă să nu apară cu întârziere.
  static Future<void> warmUp() => Future.wait(SceneKind.values.map(load));
}

/// Fundalul generat din [spec] (shader + licurici). Timpul curge doar la motion `full`;
/// în modul calm scena e statică și fără particule. Până se încarcă shaderul (sau dacă
/// platforma nu îl suportă) rămâne un degradeu cu aceeași paletă.
class SceneBackground extends ConsumerStatefulWidget {
  const SceneBackground({
    super.key,
    required this.spec,
    this.kind = SceneKind.meadow,
    this.parallax,
    this.child,
  });

  final SceneSpec spec;
  final SceneKind kind;

  /// Decalajul de paralaxă (-1..1), de obicei din poziția unei liste derulate.
  final ValueListenable<double>? parallax;
  final Widget? child;

  @override
  ConsumerState<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends ConsumerState<SceneBackground>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  @override
  void didUpdateWidget(SceneBackground old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _loadProgram();
  }

  Future<void> _loadProgram() async {
    final p = await SceneShaders.load(widget.kind);
    if (mounted) setState(() => _program = p);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    if (motion.ambient && !_ticker.isActive) _ticker.start();
    if (!motion.ambient && _ticker.isActive) _ticker.stop();

    final repaint = Listenable.merge([_time, ?widget.parallax]);
    final palette = widget.spec.palette;
    final glowColor = Color(palette.glow);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _ScenePainter(
              program: _program,
              spec: widget.spec,
              kind: widget.kind,
              time: _time,
              parallax: widget.parallax,
              repaint: repaint,
            ),
          ),
        ),
        // Pe ecranele de joc fără licurici în fundal: ar concura cu stimulul
        // (ex. „Prinde licuriciul”).
        if (motion.particles &&
            widget.kind == SceneKind.meadow &&
            widget.spec.use == SceneUse.home)
          IgnorePointer(
            child: FireflyField(
              count: widget.spec.fireflies,
              seed: widget.spec.seed,
              color: glowColor,
              time: _time,
            ),
          ),
        ?widget.child,
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.program,
    required this.spec,
    required this.kind,
    required this.time,
    required this.parallax,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.FragmentProgram? program;
  final SceneSpec spec;
  final SceneKind kind;
  final ValueListenable<double> time;
  final ValueListenable<double>? parallax;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = spec.palette;
    final quiet = spec.use == SceneUse.game ? 1.0 : 0.0;
    final program = this.program;
    if (program == null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            kind == SceneKind.water
                ? const [Color(0xFFBFE6EE), Color(0xFF7FB8C8)]
                : [Color(p.skyTop), Color(p.skyBottom), Color(p.hillNear)],
            kind == SceneKind.water ? null : const [0, 0.65, 1],
          ),
      );
      return;
    }

    final shader = program.fragmentShader();
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    void rgb(int argb) {
      final c = Color(argb);
      f(c.r);
      f(c.g);
      f(c.b);
    }

    f(size.width);
    f(size.height);
    f(time.value);
    f(spec.hillShape);
    switch (kind) {
      case SceneKind.meadow:
        f(spec.cloudCover);
        f(spec.wind);
        f(parallax?.value ?? 0);
        for (final c in [
          p.skyTop,
          p.skyBottom,
          p.hillFar,
          p.hillNear,
          p.cloud,
          p.glow,
        ]) {
          rgb(c);
        }
        f(quiet);
      case SceneKind.water:
        rgb(0xFFBFE6EE);
        rgb(0xFF6FA9BE);
        rgb(p.glow);
        f(quiet);
    }
    canvas.drawRect(rect, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.program != program || old.spec != spec || old.kind != kind;
}
