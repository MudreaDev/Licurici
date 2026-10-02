import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';

enum _Phase { intro, inhale, hold, exhale, done }

/// Respiră (FEX6): o floare se deschide la inspir și se închide la expir, iar Licurici
/// respiră în același ritm. Fără scor, fără grabă; se poate opri oricând. Ritmul e
/// animația însăși, deci rămâne și în modul calm (lent, fără particule); doar cu „reduce
/// motion” floarea stă pe loc și ghidează doar textul și vocea.
class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key, this.game = const BreathingGame()});

  final BreathingGame game;

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends ConsumerState<BreathingScreen>
    with SingleTickerProviderStateMixin {
  /// Cât de deschisă e floarea (0 = boboc, 1 = deschisă).
  late final _open = AnimationController(vsync: this, value: 0.15);
  _Phase _phase = _Phase.intro;
  int _cycle = 0;
  Timer? _timer;

  BreathPattern get _p => widget.game.pattern;

  void _begin() {
    ref
        .read(sessionProvider.notifier)
        .record(
          (r) => r.event(SessionEventKind.breathing, gameId: widget.game.id),
        );
    _cycle = 0;
    _inhale();
  }

  void _inhale() {
    setState(() => _phase = _Phase.inhale);
    ref.read(voiceProvider).say(['Inspiră']);
    _open.animateTo(
      1,
      duration: Duration(seconds: _p.inhale),
      curve: Curves.easeInOut,
    );
    _timer = Timer(Duration(seconds: _p.inhale), _hold);
  }

  void _hold() {
    if (!mounted) return;
    setState(() => _phase = _Phase.hold);
    ref.read(voiceProvider).say(['Ține']);
    _timer = Timer(Duration(seconds: _p.hold), _exhale);
  }

  void _exhale() {
    if (!mounted) return;
    setState(() => _phase = _Phase.exhale);
    ref.read(voiceProvider).say(['Expiră']);
    _open.animateTo(
      0.15,
      duration: Duration(seconds: _p.exhale),
      curve: Curves.easeInOut,
    );
    _timer = Timer(Duration(seconds: _p.exhale), () {
      if (!mounted) return;
      if (++_cycle < _p.cycles) {
        _inhale();
      } else {
        setState(() => _phase = _Phase.done);
        ref.read(voiceProvider).say(['Bravo']);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _open.stop();
    ref.read(voiceProvider).stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final text = Theme.of(context).textTheme;
    final cue = switch (_phase) {
      _Phase.intro => 'Respiră cu mine',
      _Phase.inhale => 'Inspiră…',
      _Phase.hold => 'Ține…',
      _Phase.exhale => 'Expiră…',
      _Phase.done => 'Bravo!',
    };
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, 1),
        kind: SceneKind.dusk,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: widget.game.name),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    layout.compact ? 8 : 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (layout.twoPane)
                        AnimatedBuilder(
                          animation: _open,
                          // Licurici respiră și el: crește puțin la inspir.
                          builder: (context, child) => Transform.scale(
                            scale: motion.feedback ? 1 + 0.08 * _open.value : 1,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                          child: Mascot(
                            size: layout.compact ? 100 : 180,
                            mood: _phase == _Phase.done
                                ? MascotMood.happy
                                : MascotMood.idle,
                            reaction: _phase == _Phase.done ? 1 : 0,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _open,
                                builder: (context, _) => CustomPaint(
                                  size: Size.infinite,
                                  painter: _FlowerPainter(
                                    motion.feedback ? _open.value : 0.6,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: motion.d(300),
                              child: OutlinedTitle(
                                cue,
                                key: ValueKey(cue),
                                color: const Color(0xFF3D5A80),
                                style: layout.compact
                                    ? text.headlineMedium
                                    : text.displaySmall,
                              ),
                            ),
                            SizedBox(height: layout.compact ? 6 : 12),
                            _controls(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() => switch (_phase) {
    _Phase.intro => CandyButton(
      key: const ValueKey('breathe-start'),
      label: 'Începem',
      icon: Icons.play_arrow_rounded,
      color: Tokens.good,
      onTap: _begin,
    ),
    _Phase.done => Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        CandyButton(
          label: 'Încă o dată',
          icon: Icons.replay_rounded,
          color: Tokens.lavender,
          onTap: _begin,
        ),
        CandyButton(
          label: 'Acasă',
          icon: Icons.home_rounded,
          color: Tokens.good,
          onTap: () => context.go('/'),
        ),
      ],
    ),
    _ => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _p.cycles; i++)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _cycle
                  ? Tokens.lavender
                  : (i == _cycle ? Colors.white : const Color(0x66FFFFFF)),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        const SizedBox(width: 16),
        CandyButton(
          label: 'Gata',
          icon: Icons.stop_rounded,
          color: Tokens.peach,
          minWidth: 120,
          onTap: () {
            _stop();
            setState(() => _phase = _Phase.done);
          },
        ),
      ],
    ),
  };
}

/// Floarea care respiră: 8 petale care se deschid din boboc, cu un miez luminos.
class _FlowerPainter extends CustomPainter {
  _FlowerPainter(this.t);

  /// 0 = boboc, 1 = complet deschisă.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.42;
    // Halou cald, mai mare când floarea e deschisă.
    canvas.drawCircle(
      c,
      r * (0.7 + 0.5 * t),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 241, 190, 0.55 * (0.4 + 0.6 * t)),
            const Color(0x00FFF1BE),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2)),
    );
    const petals = 8;
    final length = r * (0.35 + 0.65 * t);
    final width = length * (0.42 + 0.1 * t);
    for (var layer = 0; layer < 2; layer++) {
      final colors = layer == 0
          ? const [Color(0xFFB9B3E0), Color(0xFF9C95D2)]
          : const [Color(0xFFF6CDBD), Color(0xFFEFA98F)];
      final scale = layer == 0 ? 1.0 : 0.72;
      for (var i = 0; i < petals; i++) {
        // Simetric față de verticală: boboc = petalele suprapuse în sus; deschisă =
        // răsfirate în cerc.
        final slot = (i + (layer == 0 ? 0.5 : 1.0)) / petals - 0.5;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(slot * math.pi * 2 * (0.12 + 0.88 * t));
        final l = length * scale;
        final w = width * scale;
        final petal = Path()
          ..moveTo(0, 0)
          ..cubicTo(w * 0.9, -l * 0.25, w * 0.7, -l * 0.95, 0, -l)
          ..cubicTo(-w * 0.7, -l * 0.95, -w * 0.9, -l * 0.25, 0, 0)
          ..close();
        canvas.drawPath(
          petal,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: colors,
            ).createShader(Rect.fromLTWH(-w, -l, w * 2, l)),
        );
        canvas.drawPath(
          petal,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0x66FFFFFF),
        );
        canvas.restore();
      }
    }
    canvas.drawCircle(
      c,
      r * (0.12 + 0.06 * t),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF6C8), Color(0xFFF2CF6B)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.2)),
    );
  }

  @override
  bool shouldRepaint(_FlowerPainter old) => old.t != t;
}
