import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Step;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../data/session.dart';
import '../../shared/celebration.dart';
import '../../shared/illustration.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/sfx.dart';
import '../../shared/top_bar.dart';
import '../../shared/voice.dart';
import '../settings/settings.dart';

/// Starea unui felinar (o treaptă a unei arii).
enum LanternState {
  /// Treaptă stăpânită: felinarul arde.
  lit,

  /// Exersată, încă nestăpânită: pâlpâie.
  glowing,

  /// Încă neîncepută: stins.
  off,
}

/// O stație a hărții: o arie cu felinarele treptelor ei (doar treptele cu jocuri pe care
/// copilul le vede).
class MapStation {
  const MapStation(this.domain, this.lanterns);

  final Domain domain;
  final List<(Step, LanternState)> lanterns;
}

/// Hărțile copilului, din sesiunile salvate (plan §3 f, §6): copilul nu vede niveluri, ci
/// felinare aprinse.
final mapStationsProvider = FutureProvider.autoDispose<List<MapStation>>((ref) async {
  final records = await ref.watch(sessionStoreProvider).all();
  final visible = ref.watch(settingsProvider.select((s) => s.visibleGames));
  final progress = {for (final p in progressFromSessions(records)) p.stepId: p};
  return [
    for (final ladder in ladders)
      if (ladder.steps.any((s) => s.games.any(visible.contains)))
        MapStation(ladder.domain, [
          for (final step in ladder.steps)
            if (step.games.any(visible.contains))
              (
                step,
                switch (progress[step.id]) {
                  final p? when p.mastered => LanternState.lit,
                  _? => LanternState.glowing,
                  null => LanternState.off,
                },
              ),
        ]),
  ];
});

/// Harta cu felinare (`/harta`): o cărare de seară, derulată orizontal, cu câte o stație pe
/// arie (ilustrația ariei) și felinarele treptelor după ea. Felinarele aprinse ard cald, cele
/// începute pâlpâie, celelalte așteaptă. Când s-a aprins unul nou de la ultima vizită,
/// Licurici zboară la el și îl sărbătorește. Atingerea unei stații deschide jocurile ariei.
class LanternMapScreen extends ConsumerStatefulWidget {
  const LanternMapScreen({super.key});

  @override
  ConsumerState<LanternMapScreen> createState() => _LanternMapScreenState();
}

class _LanternMapScreenState extends ConsumerState<LanternMapScreen> with SingleTickerProviderStateMixin {
  late final _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  final _scroll = ScrollController();
  bool _greeted = false;
  int _burst = 0;

  /// Felinarul nou (index global), dacă s-a aprins unul de la ultima vizită.
  int? _fresh;

  @override
  void dispose() {
    _ambient.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static const _stationGap = 460.0;
  static const _lead = 230.0;

  void _greet(List<MapStation> stations) {
    if (_greeted) return;
    _greeted = true;
    final lit = [for (final s in stations) for (final l in s.lanterns) l.$2 == LanternState.lit];
    final count = lit.where((x) => x).length;
    final seen = ref.read(settingsProvider).lanternsSeen;
    final voice = ref.read(voiceProvider);
    if (count > seen) {
      // Ultimul felinar aprins: acolo zboară Licurici.
      final i = lit.lastIndexWhere((x) => x);
      setState(() {
        _fresh = i;
        _burst++;
      });
      ref.read(sfxProvider).play(Sfx.star);
      voice.say(['Ai aprins un felinar nou!']);
      ref.read(settingsProvider.notifier).setLanternsSeen(count);
      _scrollTo(stations, i);
    } else {
      voice.say([count == 0 ? 'Joacă-te și aprinzi felinarele.' : 'Uite câte felinare ai aprins!']);
    }
  }

  void _scrollTo(List<MapStation> stations, int lantern) {
    var k = 0;
    for (final (si, s) in stations.indexed) {
      if (lantern < k + s.lanterns.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          final target = (_lead + si * _stationGap - 200).clamp(0.0, _scroll.position.maxScrollExtent);
          _scroll.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
        });
        return;
      }
      k += s.lanterns.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(mapStationsProvider);
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    if (motion.ambient && !_ambient.isAnimating) {
      _ambient.repeat();
    } else if (!motion.ambient && _ambient.isAnimating) {
      _ambient.stop();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A55),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _SkyPainter())),
          stations.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _greet(list));
              return _map(list, motion, layout);
            },
          ),
          SafeArea(child: Align(alignment: Alignment.topCenter, child: TopBar(title: 'Harta mea'))),
        ],
      ),
    );
  }

  Widget _map(List<MapStation> stations, MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight;
      final width = _lead * 2 + (stations.length - 1) * _stationGap + 200;
      return SingleChildScrollView(
        key: const ValueKey('map-scroll'),
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(width, box.maxWidth),
          height: h,
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final t = _ambient.value * 20;
              final spots = _layout(stations, h);
              var global = 0;
              final children = <Widget>[
                Positioned.fill(child: CustomPaint(painter: _TrailPainter(spots: spots, height: h, t: t))),
              ];
              for (final (si, st) in stations.indexed) {
                final p = spots.stations[si];
                final r = math.min(h * 0.13, 70.0);
                children.add(
                  Positioned(
                    left: p.dx - r,
                    top: p.dy - r,
                    width: r * 2,
                    height: r * 2 + 34,
                    child: GestureDetector(
                      key: ValueKey('map-station-${st.domain.code}'),
                      onTap: () => context.go('/arie/${st.domain.code.toLowerCase()}'),
                      child: Column(
                        children: [
                          Container(
                            width: r * 2,
                            height: r * 2,
                            padding: EdgeInsets.all(r * 0.1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: domainColor(st.domain),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: ClipOval(child: Illustration(domainIllustration(st.domain), fallbackEmoji: '✨')),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            childLabel(st.domain),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              color: Colors.white,
                              shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                for (final (li, (step, state)) in st.lanterns.indexed) {
                  final q = spots.lanterns[si][li];
                  final fresh = global == _fresh;
                  final size = math.min(h * 0.12, 64.0);
                  children.add(
                    Positioned(
                      left: q.dx - size / 2,
                      top: q.dy - size,
                      width: size,
                      height: size * 1.2,
                      child: Semantics(
                        label: state == LanternState.lit ? 'Felinar aprins' : 'Felinar stins',
                        child: GestureDetector(
                          key: ValueKey('lantern-${step.id}'),
                          onTap: () => ref.read(sfxProvider).play(state == LanternState.lit ? Sfx.star : Sfx.tap),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: fresh && motion.feedback ? 0 : 1, end: 1),
                            duration: const Duration(milliseconds: 1400),
                            curve: Curves.easeOutBack,
                            builder: (context, k, _) => CustomPaint(
                              painter: _LanternPainter(state: state, t: t + global * 0.7, light: fresh ? k : 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (fresh) {
                    children.add(
                      Positioned(
                        left: q.dx + size * 0.2,
                        top: q.dy - size * 2.1,
                        child: IgnorePointer(child: Mascot(size: layout.compact ? 70 : 100, mood: MascotMood.celebrate)),
                      ),
                    );
                    if (motion.particles) {
                      children.add(
                        Positioned(
                          left: q.dx - 100,
                          top: q.dy - 160,
                          width: 200,
                          height: 200,
                          child: IgnorePointer(child: StarBurst(trigger: _burst, count: 16)),
                        ),
                      );
                    }
                  }
                  global++;
                }
              }
              if (_fresh == null && stations.isNotEmpty) {
                // Licurici stă la prima stație și așteaptă.
                final p = spots.stations.first;
                children.add(
                  Positioned(
                    left: p.dx + 50,
                    top: p.dy - 150,
                    child: IgnorePointer(child: Mascot(size: layout.compact ? 64 : 90, mood: MascotMood.wave)),
                  ),
                );
              }
              return Stack(clipBehavior: Clip.none, children: children);
            },
          ),
        ),
      );
    },
  );

  /// Unde stau stațiile și felinarele: pe o cărare care urcă și coboară lin.
  _Spots _layout(List<MapStation> stations, double h) {
    double y(double x) => h * (0.6 + 0.12 * math.sin(x / 300));
    final st = <Offset>[], lt = <List<Offset>>[];
    for (final (i, s) in stations.indexed) {
      final x = _lead + i * _stationGap;
      st.add(Offset(x, y(x)));
      final n = s.lanterns.length;
      lt.add([
        for (var k = 0; k < n; k++)
          () {
            final lx = x + 110 + (k + 0.5) * (_stationGap - 160) / n;
            return Offset(lx, y(lx) - 6);
          }(),
      ]);
    }
    return _Spots(st, lt, y);
  }
}

class _Spots {
  const _Spots(this.stations, this.lanterns, this.y);

  final List<Offset> stations;
  final List<List<Offset>> lanterns;
  final double Function(double x) y;
}

/// Cerul de seară cu stele, luna și dealurile în depărtare (static).
class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF16204A), Color(0xFF34407A), Color(0xFF6E5B8E)], const [0, 0.55, 1]),
    );
    final r = math.Random(3);
    for (var i = 0; i < 90; i++) {
      final c = Offset(r.nextDouble() * w, r.nextDouble() * h * 0.55);
      canvas.drawCircle(c, 0.6 + r.nextDouble() * 1.6, Paint()..color = Color.fromRGBO(255, 250, 230, 0.4 + r.nextDouble() * 0.5));
    }
    final moon = Offset(w * 0.82, h * 0.18);
    canvas.drawCircle(moon, h * 0.16, Paint()..shader = ui.Gradient.radial(moon, h * 0.16, const [Color(0x44FFF3C4), Color(0x00FFF3C4)]));
    canvas.drawCircle(moon, h * 0.06, Paint()..color = const Color(0xFFFFF1C2));
    for (final (base, amp, col) in [(0.62, 0.06, const Color(0xFF2B3566)), (0.72, 0.05, const Color(0xFF253058))]) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 20; x += 20) {
        p.lineTo(x, h * (base - amp * (0.5 + 0.5 * math.sin(x / w * 7 + base * 10))));
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// Pământul de sub cărare, cărarea (pietre luminoase) și licuricii care plutesc.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.spots, required this.height, required this.t});

  final _Spots spots;
  final double height;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = height;
    // Pajiștea de noapte.
    final ground = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 20; x += 20) {
      ground.lineTo(x, spots.y(x) + h * 0.06);
    }
    ground
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(ground, Paint()..shader = ui.Gradient.linear(Offset(0, h * 0.6), Offset(0, h), const [Color(0xFF2E5B4A), Color(0xFF1C3B33)]));
    // Cărarea: dale rotunde, puțin luminoase.
    final stone = Paint()..color = const Color(0xFFD8C9A3);
    for (var x = 20.0; x < w; x += 34) {
      final c = Offset(x, spots.y(x) + 6);
      canvas.drawOval(Rect.fromCenter(center: c, width: 22, height: 10), stone);
    }
    // Licurici care plutesc deasupra pajiștii.
    final r = math.Random(9);
    for (var i = 0; i < 40; i++) {
      final x0 = r.nextDouble() * w, y0 = h * (0.35 + r.nextDouble() * 0.5), ph = r.nextDouble() * 6;
      final c = Offset(x0 + math.sin(t * 0.4 + ph) * 20, y0 + math.cos(t * 0.3 + ph) * 12);
      final a = 0.35 + 0.35 * math.sin(t * 1.3 + ph);
      canvas.drawCircle(c, 9, Paint()..shader = ui.Gradient.radial(c, 9, [Color.fromRGBO(255, 240, 150, a * 0.6), const Color(0x00FFF096)]));
      canvas.drawCircle(c, 2, Paint()..color = Color.fromRGBO(255, 250, 200, a));
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => true;
}

/// Felinarul pe stâlp: aprins (halou cald), pâlpâind (lumină slabă care respiră) sau stins.
class _LanternPainter extends CustomPainter {
  _LanternPainter({required this.state, required this.t, this.light = 1});

  final LanternState state;
  final double t;

  /// 0…1: cât s-a aprins (animația felinarului nou).
  final double light;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final lamp = Offset(w / 2, h * 0.3);
    final glow = switch (state) {
      LanternState.lit => (0.85 + 0.15 * math.sin(t * 2)) * light,
      LanternState.glowing => 0.25 + 0.15 * math.sin(t * 1.4),
      LanternState.off => 0.0,
    };
    if (glow > 0) {
      canvas.drawCircle(
        lamp,
        w * 0.9,
        Paint()..shader = ui.Gradient.radial(lamp, w * 0.9, [Color.fromRGBO(255, 214, 110, 0.55 * glow), const Color(0x00FFD66E)]),
      );
    }
    // Stâlpul.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.46, h * 0.42, w * 0.08, h * 0.56), Radius.circular(w * 0.03)),
      Paint()..color = const Color(0xFF3B3346),
    );
    // Lampa: acoperiș, sticlă, bază.
    final roof = Path()
      ..moveTo(w * 0.24, h * 0.16)
      ..lineTo(w * 0.5, h * 0.02)
      ..lineTo(w * 0.76, h * 0.16)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF4A3F5C));
    final glass = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.3, h * 0.16, w * 0.7, h * 0.42), Radius.circular(w * 0.06));
    canvas.drawRRect(
      glass,
      Paint()..color = Color.lerp(const Color(0xFF5A5470), const Color(0xFFFFE9A0), glow.clamp(0.0, 1.0))!,
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..color = const Color(0xFF4A3F5C),
    );
    if (glow > 0.5) canvas.drawCircle(lamp, w * 0.08, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: glow * 0.9));
  }

  @override
  bool shouldRepaint(_LanternPainter old) => old.state != state || old.t != t || old.light != light;
}
