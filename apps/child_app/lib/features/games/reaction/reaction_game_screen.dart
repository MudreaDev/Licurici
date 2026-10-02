import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../shared/pause_view.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/mascot.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

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

  /// Abțibildul primit la final.
  String? _sticker;
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
    // Ilustrațiile pictate cer contextul: după ce ecranul e montat.
    Future(
      () => mounted ? precacheStimuli(context, {..._level.art, '⭐'}) : null,
    ).then((_) {
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
        _sticker = ref.read(settingsProvider.notifier).awardSticker();
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
    _drift.dispose();
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _speaker = ref.watch(voiceProvider);
    final motion = MotionPolicy.of(context, ref);
    _motion = motion;
    if (!motion.movement) _drift.stop();
    if (!motion.feedback) _effect.stop();
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        kind: widget.game.id == 'pescarul' ? SceneKind.water : SceneKind.dusk,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: widget.game.name,
                trailing: BarButton(
                  icon: _paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: Tokens.mint,
                  label: _paused ? 'Continuă' : 'Pauză',
                  onTap: _paused ? _resume : _pause,
                ),
              ),
              Expanded(
                child: _paused
                    ? PauseView(onResume: _resume)
                    : _phase == _Phase.introduction
                    ? _introduction()
                    : _phase == _Phase.finished
                    ? ReactionFinish(
                        summary: _summary!,
                        sticker: _sticker,
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

  Widget _introduction() {
    final compact = AppLayout.of(context).compact;
    final art = compact ? 76.0 : 120.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Mascot(size: compact ? 96 : 170, mood: MascotMood.wave),
            const SizedBox(width: 8),
            CandyPanel(
              padding: EdgeInsets.fromLTRB(28, compact ? 12 : 22, 28, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _level.instruction,
                    textAlign: TextAlign.center,
                    style:
                        (compact
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineMedium)!
                            .copyWith(color: const Color(0xFF3D5A80)),
                  ),
                  SizedBox(height: compact ? 8 : 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _example(_level.goArt, 'Da, atinge', true, art),
                      if (_level.noGoArt case final noGo?) ...[
                        SizedBox(width: compact ? 20 : 36),
                        _example(noGo, 'Nu atinge', false, art),
                      ],
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 18),
                  CandyButton(
                    label: _ready ? 'Începem' : 'Se pregătește…',
                    icon: Icons.play_arrow_rounded,
                    color: Tokens.good,
                    onTap: _ready ? _begin : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exemplul din instrucțiune: ce atingem (bifă verde) și ce lăsăm în pace (mânuță oprită).
  Widget _example(String art, String label, bool go, double size) {
    final color = go ? Tokens.good : Tokens.gentle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size + 24,
              height: size + 24,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tint(color, 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
              ),
              child: StimulusArt(art, size: size),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  go ? Icons.check_rounded : Icons.do_not_touch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium!.copyWith(color: shade(color, 0.2)),
        ),
      ],
    );
  }

  Widget _scene(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final visible = _phase == _Phase.visible;
      final s = _stimulus;
      final side = math.max(64.0, math.max(64.0, box.maxHeight * .16) * s.size);
      return ClipRect(
        child: Stack(
          children: [
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
                        // Un cerc de apă se lărgește unde apare peștele (o singură dată).
                        if (widget.game.id == 'pescarul' && motion.feedback)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('ripple-${s.index}'),
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOut,
                                builder: (context, t, _) =>
                                    CustomPaint(painter: _RipplePainter(t)),
                              ),
                            ),
                          ),
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
                                      child: _Glow(
                                        on: s.art == '✨',
                                        child: StimulusArt(
                                          s.art,
                                          size: side,
                                          // Peștii privesc în direcția în care înoată.
                                          flip: motion.movement && s.driftX < 0,
                                        ),
                                      ),
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

class ReactionFinish extends ConsumerStatefulWidget {
  const ReactionFinish({
    super.key,
    required this.summary,
    required this.onAgain,
    required this.onNext,
    required this.burst,
    this.sticker,
  });
  final ReactionSummary summary;
  final String? sticker;
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
        RewardFinish(
          stars: widget.summary.stars,
          sticker: widget.sticker,
          actions: [
            FinishAction(
              'Încă o dată',
              Icons.replay_rounded,
              Tokens.primary,
              widget.onAgain,
            ),
            FinishAction(
              'Mai departe',
              Icons.arrow_forward_rounded,
              Tokens.good,
              widget.onNext,
            ),
          ],
        ),
        if (motion.particles)
          Positioned.fill(
            child: IgnorePointer(
              child: StarBurst(
                trigger: _celebrate ? widget.burst : 0,
                enabled: motion.particles,
              ),
            ),
          ),
      ],
    );
  }
}

/// Cercuri pe apă care se lărgesc și se sting.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final (i, delay) in const [0.0, 0.25].indexed) {
      final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final r = size.width * (0.35 + 0.5 * p);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 0.9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 - i
          ..color = Color.fromRGBO(255, 255, 255, 0.6 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

/// Halou cald în spatele licuriciului (lumina lui).
class _Glow extends StatelessWidget {
  const _Glow({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => !on
      ? child
      : DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x99FFE9A0), Color(0x33F2CF6B), Color(0x00F2CF6B)],
              stops: [0.2, 0.6, 1],
            ),
          ),
          child: child,
        );
}
