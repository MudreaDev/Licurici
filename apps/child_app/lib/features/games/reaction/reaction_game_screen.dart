import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../data/session.dart';
import '../../../shared/art_cache.dart';
import '../../../shared/celebration.dart';
import '../../../shared/emoji_art.dart';
import '../../../shared/mascot.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';

class ReactionProgress extends Notifier<int> {
  @override
  int build() => 1;
  void advance() => state++;
  void setLevel(int level) => state = level;
}

final reactionLevelProvider =
    NotifierProvider.family<ReactionProgress, int, String>(
      (_) => ReactionProgress(),
    );

enum _Phase { introduction, gap, visible, finished }

class ReactionGameScreen extends ConsumerStatefulWidget {
  const ReactionGameScreen({super.key, required this.game});
  final ReactionGame game;

  @override
  ConsumerState<ReactionGameScreen> createState() => _ReactionGameScreenState();
}

class _ReactionGameScreenState extends ConsumerState<ReactionGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late ReactionLevel _level;
  late Speaker _speaker;
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final _drift = AnimationController(vsync: this);
  late final _effect = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  final _reactionClock = Stopwatch();
  final _phaseClock = Stopwatch();
  final _responses = <ReactionResponse>[];
  Timer? _timer;
  Duration _remaining = Duration.zero;
  VoidCallback? _deadline;
  _Phase _phase = _Phase.introduction;
  int _index = 0, _offTargetTaps = 0, _generation = 0, _burst = 0;
  bool _ready = false, _paused = false, _tapped = false, _painted = false;
  ReactionSummary? _summary;
  MotionPolicy _motion = const MotionPolicy(MotionLevel.off);
  ReactionStimulus get _stimulus => _level.stimuli[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speaker = ref.read(voiceProvider);
    _start();
  }

  void _start() {
    final generation = ++_generation;
    _cancelDeadline();
    _reactionClock
      ..stop()
      ..reset();
    _drift.reset();
    _effect.reset();
    _level = widget.game.generate(
      ref.read(reactionLevelProvider(widget.game.id)),
    );
    _responses.clear();
    _index = _offTargetTaps = 0;
    _phase = _Phase.introduction;
    _summary = null;
    _ready = false;
    precacheArt({..._level.art, '⭐'}).then((_) {
      if (!mounted || generation != _generation) return;
      setState(() => _ready = true);
      if (!_paused) _speaker.say([_level.instruction]);
    });
  }

  void _cancelDeadline() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _phaseClock.stop();
  }

  void _schedule(Duration duration, VoidCallback callback) {
    _cancelDeadline();
    _remaining = duration;
    _deadline = callback;
    _armDeadline();
  }

  void _armDeadline() {
    if (_paused) return;
    _phaseClock
      ..reset()
      ..start();
    _timer = Timer(_remaining, () {
      _phaseClock.stop();
      final callback = _deadline;
      _deadline = null;
      if (mounted && !_paused) callback?.call();
    });
  }

  void _begin() {
    _speaker.stop();
    _enterGap();
  }

  void _enterGap() {
    setState(() {
      _phase = _Phase.gap;
      _tapped = _painted = false;
    });
    _schedule(Duration(milliseconds: _stimulus.gapBeforeMs), _show);
  }

  void _show() {
    _drift
      ..duration = Duration(milliseconds: _stimulus.visibleMs)
      ..value = 0;
    _effect.value = 0;
    setState(() => _phase = _Phase.visible);
    final generation = _generation;
    // The first painted frame, not the timer callback, defines stimulus onset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _generation ||
          _phase != _Phase.visible ||
          _paused) {
        return;
      }
      _painted = true;
      _reactionClock.reset();
      if (!_paused) _reactionClock.start();
      _schedule(Duration(milliseconds: _stimulus.visibleMs), _next);
      if (!_paused && _motion.movement) _drift.forward();
    });
  }

  void _next() {
    _reactionClock.stop();
    _drift.stop();
    _effect.stop();
    if (++_index < _level.stimuli.length) {
      _enterGap();
    } else {
      setState(() {
        _summary = ReactionSummary.score(
          _level,
          _responses,
          offTargetTaps: _offTargetTaps,
        );
        _phase = _Phase.finished;
        _burst++;
      });
      final session = ref.read(sessionProvider.notifier);
      final level = _level, responses = List.of(_responses);
      session.record((s) => s.reactionLevel(level, responses));
      session.checkpoint();
      _speaker.say(['Ai terminat! Bravo!']);
    }
  }

  void _tapStimulus() {
    if (_paused || !_painted || _tapped || _phase != _Phase.visible) return;
    _responses.add(
      ReactionResponse(
        index: _stimulus.index,
        tapped: true,
        reactionMs: _reactionClock.elapsedMilliseconds,
      ),
    );
    _reactionClock.stop();
    setState(() {
      _tapped = true;
      if (_stimulus.isGo) _burst++;
    });
    if (_motion.feedback) _effect.forward(from: 0);
  }

  void _pause() {
    if (_paused) return;
    _timer?.cancel();
    _remaining = _remaining - _phaseClock.elapsed;
    if (_remaining.isNegative) _remaining = Duration.zero;
    _phaseClock.stop();
    _reactionClock.stop();
    _drift.stop();
    _effect.stop();
    _ambient.stop();
    _speaker.stop();
    ref
        .read(sessionProvider.notifier)
        .record((s) => s.event(SessionEventKind.pause, gameId: widget.game.id));
    setState(() => _paused = true);
  }

  void _resume() {
    setState(() => _paused = false);
    if (_phase == _Phase.visible && !_painted) {
      _show();
      return;
    }
    if (_deadline != null) _armDeadline();
    if (_phase == _Phase.visible && _painted) {
      if (!_tapped) _reactionClock.start();
      if (_motion.movement) _drift.forward();
      if (_tapped && _motion.feedback) _effect.forward();
    }
    if (_phase == _Phase.introduction && _ready) {
      _speaker.say([_level.instruction]);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _cancelDeadline();
    _reactionClock.stop();
    _speaker.stop();
    _ambient.dispose();
    _drift.dispose();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _speaker = ref.watch(voiceProvider);
    final motion = MotionPolicy.of(context, ref);
    _motion = motion;
    if (motion.ambient && !_paused && _phase != _Phase.finished) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
    if (!motion.movement) _drift.stop();
    if (!motion.feedback) _effect.stop();
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        kind: widget.game.id == 'pescarul' ? SceneKind.water : SceneKind.meadow,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: widget.game.name,
                trailing: SizedBox(
                  width: 64,
                  height: 64,
                  child: IconButton(
                    tooltip: _paused ? 'Continuă' : 'Pauză',
                    onPressed: _paused ? _resume : _pause,
                    icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _paused
                    ? Center(child: _button('Continuă', _resume))
                    : _phase == _Phase.introduction
                    ? _introduction()
                    : _phase == _Phase.finished
                    ? ReactionFinish(
                        summary: _summary!,
                        onAgain: () => setState(_start),
                        onNext: () {
                          ref
                              .read(
                                reactionLevelProvider(widget.game.id).notifier,
                              )
                              .setLevel(
                                _summary!.suggestedNextLevel(_level.level),
                              );
                          setState(_start);
                        },
                        burst: _burst,
                      )
                    : _scene(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introduction() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _level.instruction,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _example(_level.goArt, 'Da, atinge', Icons.touch_app_rounded),
              if (_level.noGoArt case final art?) ...[
                const SizedBox(width: 40),
                _example(art, 'Nu atinge', Icons.pan_tool_outlined),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _button(
            _ready ? 'Începem' : 'Se pregătește…',
            _ready ? _begin : null,
          ),
        ],
      ),
    ),
  );

  Widget _example(String art, String label, IconData icon) => Column(
    children: [
      EmojiArt(art, size: 64),
      Row(
        children: [
          Icon(icon, color: const Color(0xFF527D79)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    ],
  );

  Widget _scene(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final visible = _phase == _Phase.visible;
      final s = _stimulus;
      final side = math.max(64.0, math.max(64.0, box.maxHeight * .16) * s.size);
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ScenePainter(
                    pond: widget.game.id == 'pescarul',
                    clock: _ambient,
                    animated: motion.ambient,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Listener(
                key: const ValueKey('reaction-field'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _offTargetTaps++,
              ),
            ),
            if (visible)
              AnimatedBuilder(
                animation: Listenable.merge([_drift, _effect]),
                builder: (context, _) {
                  final elapsed = _drift.value * s.visibleMs;
                  final pop = motion.movement
                      ? 1 +
                            .08 *
                                math.sin(math.pi * (elapsed / 180).clamp(0, 1))
                      : 1.0;
                  final feedback = motion.movement && _tapped
                      ? math.sin(_effect.value * math.pi)
                      : 0.0;
                  final x =
                      s.x + (motion.movement ? s.driftX * _drift.value : 0);
                  final left = (x * box.maxWidth - side / 2).clamp(
                    0.0,
                    math.max(0.0, box.maxWidth - side),
                  );
                  final top = (s.y * box.maxHeight - side / 2).clamp(
                    0.0,
                    math.max(0.0, box.maxHeight - side),
                  );
                  final gone =
                      _tapped && (!motion.feedback || _effect.isCompleted);
                  return Positioned(
                    left: left.toDouble(),
                    top: top.toDouble(),
                    width: side,
                    height: side,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (!gone)
                          Positioned.fill(
                            child: Semantics(
                              button: true,
                              label: 'Atinge obiectul',
                              onTap: _tapStimulus,
                              child: Listener(
                                key: ValueKey('reaction-stimulus-${s.index}'),
                                behavior: HitTestBehavior.opaque,
                                // Pointer contact avoids the tap recognizer's
                                // press timeout in the reaction-time measurement.
                                onPointerDown: (_) => _tapStimulus(),
                                child: Transform.translate(
                                  offset: Offset(
                                    s.isGo
                                        ? 0
                                        : 4 *
                                              feedback *
                                              math.cos(_effect.value * math.pi),
                                    0,
                                  ),
                                  child: Transform.scale(
                                    scale: pop + (s.isGo ? .12 * feedback : 0),
                                    child: Opacity(
                                      opacity: _tapped && motion.feedback
                                          ? 1 - _effect.value
                                          : 1,
                                      child: EmojiArt(s.art, size: side),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (motion.particles)
                          Positioned.fill(
                            child: StarBurst(
                              trigger: _burst,
                              count: 8,
                              enabled: motion.particles,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

Widget _button(String label, VoidCallback? onPressed) => FilledButton(
  style: FilledButton.styleFrom(minimumSize: const Size(180, 64)),
  onPressed: onPressed,
  child: Text(label),
);

class ReactionFinish extends ConsumerStatefulWidget {
  const ReactionFinish({
    super.key,
    required this.summary,
    required this.onAgain,
    required this.onNext,
    required this.burst,
  });
  final ReactionSummary summary;
  final VoidCallback onAgain, onNext;
  final int burst;

  @override
  ConsumerState<ReactionFinish> createState() => _ReactionFinishState();
}

class _ReactionFinishState extends ConsumerState<ReactionFinish> {
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _celebrate = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ai terminat! Bravo!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Mascot(
                      size: 90,
                      mood: _celebrate ? MascotMood.happy : MascotMood.idle,
                      reaction: _celebrate ? 1 : 0,
                    ),
                    for (var i = 0; i < widget.summary.stars; i++)
                      const EmojiArt('⭐', size: 64)
                          .animate(delay: motion.d(i * 250))
                          .fadeIn(duration: motion.d(200))
                          .scaleXY(
                            begin: motion.movement ? .7 : 1,
                            end: 1,
                            duration: motion.d(300),
                            curve: Curves.easeOutBack,
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _button('Încă o dată', widget.onAgain),
                    _button('Mai departe', widget.onNext),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (motion.particles)
          Positioned.fill(
            child: StarBurst(
              trigger: _celebrate ? widget.burst : 0,
              enabled: motion.particles,
            ),
          ),
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.pond,
    required this.clock,
    required this.animated,
  }) : super(repaint: clock);
  final bool pond, animated;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animated ? clock.value * math.pi * 2 : 0.0;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pond
              ? const [Color(0xFFD5ECE5), Color(0xFF85B9C3)]
              : const [Color(0xFF454C75), Color(0xFF8D9BAA)],
        ).createShader(rect),
    );
    if (pond) {
      final paint = Paint()
        ..color = const Color(0x5574A6AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var row = 0; row < 5; row++) {
        final path = Path();
        for (var x = 0.0; x <= size.width; x += 8) {
          final y =
              size.height * (row + .5) / 5 + 4 * math.sin(x / 90 + t + row);
          x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
      }
      for (var i = 0; i < 7; i++) {
        canvas.drawCircle(
          Offset(
            size.width * (i + .5) / 7 + 3 * math.sin(t + i),
            size.height * (.78 + .07 * math.sin(t + i * 2)),
          ),
          4 + (i % 3).toDouble(),
          paint,
        );
      }
    } else {
      canvas.drawCircle(
        Offset(size.width * .85, size.height * .18),
        22,
        Paint()..color = const Color(0xFFF2E4AE),
      );
      final grass = Paint()
        ..color = const Color(0xFF466D68)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 45; i++) {
        final x = i * size.width / 44;
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + 6 * math.sin(t + i), size.height - 18 - (i % 5) * 5),
          grass,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.pond != pond || oldDelegate.animated != animated;
}
