import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../illustration.dart';
import '../motion.dart';
import 'fireflies.dart';

/// Ce scenă pictată stă în spatele ecranului.
enum SceneKind {
  /// Pajiștea: cer, dealuri, iarbă în față (trei straturi cu paralaxă).
  meadow,

  /// Iazul văzut de sus (Pescarul).
  water,

  /// Cerul de seară cu lună (Felinarele).
  evening,

  /// Pajiștea la amurg (Prinde licuriciul).
  dusk,
}

/// Un strat al scenei: imaginea și cât de mult se mișcă.
class _Layer {
  const _Layer(
    this.name, {
    this.depth = 0,
    this.drift = 0,
    this.sway = 0,
    this.alignment = Alignment.center,
  });

  final String name;

  /// Paralaxa la derulare (0 = fix, 1 = urmează degetul).
  final double depth;

  /// Alunecare lentă stânga-dreapta (px), ca norii.
  final double drift;

  /// Legănare scurtă (px), ca iarba în vânt.
  final double sway;
  final Alignment alignment;
}

List<_Layer> _layersOf(SceneKind kind) => switch (kind) {
  SceneKind.meadow => const [
    _Layer('meadow_sky', depth: 0.08, drift: 26),
    _Layer('meadow_hills', depth: 0.3, alignment: Alignment.bottomCenter),
    _Layer(
      'meadow_front',
      depth: 0.75,
      sway: 3,
      alignment: Alignment.bottomCenter,
    ),
  ],
  SceneKind.water => const [_Layer('pond', drift: 10)],
  SceneKind.evening => const [_Layer('evening', drift: 8)],
  SceneKind.dusk => const [_Layer('dusk_meadow', drift: 8)],
};

/// Imaginile unei scene (pentru pre-încărcare).
Iterable<AssetImage> sceneImages(SceneKind kind) =>
    _layersOf(kind).map((l) => illustration('scenes/${l.name}'));

/// Fundalul ecranelor: ilustrații pictate pe straturi, animate din cod (ADR-028): norii
/// alunecă, dealurile și iarba au paralaxă la derulare, iarba se leagănă. Timpul curge doar
/// la motion `full`; în modul calm scena e statică. [spec] (din seed) alege faza mișcărilor
/// și numărul de licurici, iar paleta lui e rezerva până se încarcă ilustrațiile.
/// Pe ecranele de joc (`SceneUse.game`) scena e estompată, ca stimulul să iasă în față.
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

  /// Decalajul de paralaxă (0..1), de obicei din poziția unei liste derulate.
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

    final spec = widget.spec;
    final palette = spec.palette;
    final quiet = spec.use == SceneUse.game;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: switch (widget.kind) {
            SceneKind.water => const [Color(0xFFBFE6EE), Color(0xFF7FB8C8)],
            SceneKind.evening ||
            SceneKind.dusk => const [Color(0xFF3E4A72), Color(0xFFA99BC4)],
            SceneKind.meadow => [
              Color(palette.skyTop),
              Color(palette.skyBottom),
              Color(palette.hillNear),
            ],
          },
        ),
      ),
    );
    final layers = _layersOf(widget.kind);
    // Faza mișcărilor vine din seed: fiecare scenă „respiră” puțin altfel.
    final phase = (spec.seed % 1000) / 1000 * math.pi * 2;
    final windSpeed = 0.6 + spec.wind * 20;

    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        RepaintBoundary(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final (i, l) in layers.indexed)
                  _AnimatedLayer(
                    layer: l,
                    time: _time,
                    parallax: widget.parallax,
                    phase: phase + i,
                    speed: windSpeed,
                    opaque: i == 0,
                  ),
              ],
            ),
          ),
        ),
        if (widget.kind == SceneKind.water && motion.ambient)
          IgnorePointer(
            child: CustomPaint(painter: _GlintPainter(_time, spec.seed)),
          ),
        if (widget.kind == SceneKind.evening && motion.ambient)
          IgnorePointer(
            child: CustomPaint(painter: _TwinklePainter(_time, spec.seed)),
          ),
        // Licurici doar acasă: pe ecranele de joc ar concura cu stimulul
        // (ex. „Prinde licuriciul”).
        if (motion.particles && !quiet && widget.kind == SceneKind.meadow)
          IgnorePointer(
            child: FireflyField(
              count: spec.fireflies,
              seed: spec.seed,
              color: Color(palette.glow),
              time: _time,
            ),
          ),
        if (quiet)
          IgnorePointer(
            child: ColoredBox(
              color: widget.kind == SceneKind.meadow
                  ? const Color(0x47FFFDF6)
                  : const Color(0x1AFFFDF6),
            ),
          ),
        ?widget.child,
      ],
    );
  }
}

class _AnimatedLayer extends StatelessWidget {
  const _AnimatedLayer({
    required this.layer,
    required this.time,
    required this.parallax,
    required this.phase,
    required this.speed,
    required this.opaque,
  });

  final _Layer layer;
  final ValueListenable<double> time;
  final ValueListenable<double>? parallax;
  final double phase;
  final double speed;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: illustration('scenes/${layer.name}'),
      fit: BoxFit.cover,
      alignment: layer.alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      // Lipsește stratul → se vede degradeul de rezervă de dedesubt.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
      frameBuilder: (context, child, frame, sync) => sync || !opaque
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
    );
    final listenable = Listenable.merge([time, ?parallax]);
    return AnimatedBuilder(
      animation: listenable,
      child: image,
      builder: (context, child) {
        final t = time.value;
        final p = (parallax?.value ?? 0) - 0.5;
        final dx =
            -p * layer.depth * 60 +
            math.sin(t * 0.05 * speed + phase) * layer.drift +
            math.sin(t * 1.1 + phase) * layer.sway;
        // Supradimensionare mică, ca marginile să nu apară la deplasare.
        return Transform(
          transform: Matrix4.translationValues(dx, 0, 0)
            ..multiply(Matrix4.diagonal3Values(1.08, 1.08, 1)),
          alignment: layer.alignment == Alignment.bottomCenter
              ? Alignment.bottomCenter
              : Alignment.center,
          child: child,
        );
      },
    );
  }
}

/// Sclipiri de lumină pe apă: câteva elipse moi care apar și dispar lent (≤ 0,3 Hz).
class _GlintPainter extends CustomPainter {
  _GlintPainter(this.time, this.seed) : super(repaint: time);

  final ValueListenable<double> time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final t = time.value;
    for (var i = 0; i < 9; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final speed = 0.15 + r.nextDouble() * 0.15;
      final a = (math.sin(t * speed * math.pi * 2 + i * 1.7) + 1) / 2;
      final w = 40 + r.nextDouble() * 60;
      final rect = Rect.fromCenter(
        center: Offset(x + math.sin(t * 0.2 + i) * 12, y),
        width: w,
        height: w * 0.32,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(rect.center, w / 2, [
            Color.fromRGBO(255, 255, 255, 0.28 * a),
            const Color(0x00FFFFFF),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(_GlintPainter old) => false;
}

/// Stele care sclipesc încet pe cerul de seară (sub pragul de 3 clipiri/s).
class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.time, this.seed) : super(repaint: time);

  final ValueListenable<double> time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final t = time.value;
    for (var i = 0; i < 18; i++) {
      final c = Offset(
        r.nextDouble() * size.width,
        r.nextDouble() * size.height * 0.45,
      );
      final a = (math.sin(t * (0.3 + r.nextDouble() * 0.4) + i * 2.1) + 1) / 2;
      final rad = 1.5 + r.nextDouble() * 2;
      canvas.drawCircle(
        c,
        rad * 3,
        Paint()
          ..shader = ui.Gradient.radial(c, rad * 3, [
            Color.fromRGBO(255, 246, 210, 0.75 * a),
            const Color(0x00FFF6D2),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => false;
}
