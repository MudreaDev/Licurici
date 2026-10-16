import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/parts.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final fittsLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('atinge-rapid'));

/// Atinge rapid (MOT0, legea lui Fitts): bulele apar pe rând; copilul le sparge cât de repede
/// poate. Prima bulă (mare) e startul; de la ea se măsoară timpul de mișcare până la fiecare
/// bulă. Atingerile pe lângă se numără, fără niciun semn de greșeală.
class FittsScreen extends ConsumerStatefulWidget {
  const FittsScreen({super.key, this.game = const FittsGame(), this.seed});

  final FittsGame game;
  final int? seed;

  @override
  ConsumerState<FittsScreen> createState() => _FittsScreenState();
}

class _FittsScreenState extends ConsumerState<FittsScreen> {
  late FittsLevel _level;
  final _hits = <FittsHit>[];
  final _clock = Stopwatch();
  int _index = 0;
  int _misses = 0;

  /// Bulele sparte recent (locul și momentul), pentru stropii care se împrăștie.
  final _pops = <(Offset, int)>[];
  FittsResult? _result;
  String? _sticker;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _level = widget.game.generate(ref.read(fittsLevelProvider), seed: widget.seed);
    _hits.clear();
    _index = 0;
    _misses = 0;
    _result = null;
    _sticker = null;
    _clock
      ..stop()
      ..reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(['Sparge bulele cât de repede poți.']);
    });
  }

  void _tapAt(Offset p, double unit) {
    if (_result != null) return;
    final t = _level.targets[_index];
    final c = Offset(t.x * unit, t.y * unit);
    // Ținta e cercul bulei, puțin mai largă (degetul copilului nu e un vârf de creion).
    if ((p - c).distance > t.size * unit * 0.6) {
      if (_index > 0) _misses++;
      return;
    }
    ref.read(sfxProvider).play(Sfx.bubble);
    if (_index > 0) {
      _hits.add(FittsHit(_index, _clock.elapsedMilliseconds, misses: _misses));
    }
    _misses = 0;
    _clock
      ..reset()
      ..start();
    setState(() {
      _pops.add((c, DateTime.now().millisecondsSinceEpoch));
      if (_pops.length > 6) _pops.removeAt(0);
      if (_index + 1 < _level.targets.length) {
        _index++;
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _clock.stop();
    final result = FittsResult(_level, _hits);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.fittsLevel(result));
    session.checkpoint();
    _result = result;
    _sticker = ref.read(settingsProvider.notifier).awardSticker();
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(fittsLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final result = _result;
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: widget.game.name),
              Expanded(
                child: result != null
                    ? RewardFinish(
                        stars: result.stars,
                        sticker: _sticker,
                        actions: [
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
                          FinishAction('Mai departe', Icons.arrow_forward_rounded, Tokens.good, () => _again(next: true)),
                        ],
                      )
                    : _field(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final unit = math.min((box.maxWidth - 24) / FittsGame.aspect, box.maxHeight - 12);
      final t = _level.targets[_index];
      final size = t.size * unit;
      return Center(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x55FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x99FFFFFF), width: 3),
          ),
          child: SizedBox(
            width: unit * FittsGame.aspect,
            height: unit,
            child: GestureDetector(
              key: const ValueKey('fitts-field'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _tapAt(d.localPosition, unit),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (at, born) in _pops)
                    Positioned(
                      key: ValueKey('pop-$born-${at.dx}'),
                      left: at.dx - 40,
                      top: at.dy - 40,
                      child: IgnorePointer(child: _Pop(enabled: motion.feedback)),
                    ),
                  Positioned(
                    key: ValueKey('fitts-target-$_index'),
                    left: t.x * unit - size / 2,
                    top: t.y * unit - size / 2,
                    child: IgnorePointer(
                      child: Semantics(
                        label: _index == 0 ? 'Bula de start' : 'Bula $_index',
                        child: _Bubble(size: size, start: _index == 0, animate: motion.movement),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Bula: sticloasă, cu luciu; cea de start e aurie și pulsează ușor.
class _Bubble extends StatefulWidget {
  const _Bubble({required this.size, required this.start, required this.animate});

  final double size;
  final bool start;
  final bool animate;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Transform.scale(
      scale: widget.animate ? Curves.easeOutBack.transform(_c.value) : 1,
      child: hasPart('bubble')
          ? SizedBox.square(
              dimension: widget.size,
              child: Part('bubble', fit: BoxFit.contain, tint: widget.start ? const Color(0xFFF2C14E) : null),
            )
          : CustomPaint(size: Size.square(widget.size), painter: _BubblePainter(widget.start)),
    ),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.start);

  final bool start;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, c = Offset(r, r);
    final tint = start ? const Color(0xFFF2C14E) : const Color(0xFF6CC3E0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.3, -r * 0.35),
          r * 1.2,
          [Colors.white.withValues(alpha: 0.9), tint.withValues(alpha: 0.55), tint.withValues(alpha: 0.85)],
          const [0, 0.55, 1],
        ),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.06)
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * 0.35, -r * 0.4), width: r * 0.5, height: r * 0.28),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.start != start;
}

/// Stropii unei bule sparte: câteva picături care se împrăștie și dispar.
class _Pop extends StatefulWidget {
  const _Pop({required this.enabled});

  final bool enabled;

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.enabled
      ? const SizedBox(width: 80, height: 80)
      : AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(size: const Size.square(80), painter: _PopPainter(_c.value)),
        );
}

class _PopPainter extends CustomPainter {
  _PopPainter(this.k);

  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    if (k >= 1) return;
    final c = size.center(Offset.zero);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85 * (1 - k));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (10 + 26 * k), 4 * (1 - k) + 1, p);
    }
  }

  @override
  bool shouldRepaint(_PopPainter old) => old.k != k;
}
