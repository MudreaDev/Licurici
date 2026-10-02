import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../shared/illustration.dart';
import '../../../shared/pause_view.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/mascot.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';

enum _Phase { introduction, watch, turn, retry, success, moving, finished }

class SimonScreen extends ConsumerStatefulWidget {
  const SimonScreen({
    super.key,
    this.game = const SimonGame(),
    this.initialLevel = 1,
  });
  final SimonGame game;
  final int initialLevel;

  @override
  ConsumerState<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends ConsumerState<SimonScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late SequenceLevel _level;
  late Speaker _speaker;
  late int _sessionLevel;
  late int _nextSessionLevel;
  Timer? _timer;
  VoidCallback? _pending;
  final _taps = <int>[];
  _Phase _phase = _Phase.introduction;
  int _round = 0, _wins = 0, _attempt = 0, _position = 0, _burst = 0;
  int? _lit;
  bool _locked = false, _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speaker = ref.read(voiceProvider);
    _sessionLevel = widget.initialLevel;
    _nextSessionLevel = _sessionLevel;
    _level = widget.game.generate(_sessionLevel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speaker.say([_level.instruction]);
    });
  }

  void _after(int ms, VoidCallback action) {
    _timer?.cancel();
    _pending = action;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (mounted && !_paused) {
        _pending = null;
        action();
      }
    });
  }

  void _watch() {
    _speaker.stop();
    setState(() {
      _phase = _Phase.watch;
      _position = 0;
      _lit = null;
      _locked = false;
      _taps.clear();
    });
    _after(450, _lightNext);
  }

  void _lightNext() {
    setState(() => _lit = _level.sequence[_position]);
    _after(_level.axes.onMs, () {
      setState(() => _lit = null);
      _after(_level.axes.gapMs, () {
        if (++_position < _level.sequence.length) {
          _lightNext();
        } else {
          setState(() => _phase = _Phase.turn);
          _speaker.say([
            _level.axes.reverse
                ? 'Atinge-le invers, de la ultimul.'
                : 'Rândul tău',
          ]);
        }
      });
    });
  }

  void _tap(int index) {
    if (_phase != _Phase.turn || _locked || _paused) return;
    setState(() {
      _locked = true;
      _lit = index;
      _taps.add(index);
    });
    final result = SequenceResult(_level, List.of(_taps));
    // One onset per 450 ms at most, including repeated taps on the same pad.
    _after(250, () {
      setState(() => _lit = null);
      _after(200, () {
        if (result.correctPrefix != _taps.length) {
          if (_attempt++ == 0) {
            setState(() => _phase = _Phase.retry);
            _speaker.say(['Mai privim o dată']);
            _after(1200, _watch);
          } else {
            _finishRound(result);
          }
        } else if (result.complete) {
          _finishRound(result);
        } else {
          setState(() => _locked = false);
        }
      });
    });
  }

  void _finishRound(SequenceResult result) {
    final session = ref.read(sessionProvider.notifier);
    final secondChance = _attempt > 0;
    session.record((s) => s.sequence(result, secondChance: secondChance));
    session.checkpoint();
    setState(() {
      if (result.complete) {
        _wins++;
        _burst++;
      }
      _phase = result.complete ? _Phase.success : _Phase.moving;
    });
    _speaker.say([result.complete ? 'Bravo!' : 'Continuăm']);
    _after(1000, () {
      final next = result.suggestedNextLevel(_level.level);
      setState(() {
        _round++;
        if (_round == 5) {
          _nextSessionLevel = next;
          _phase = _Phase.finished;
        } else {
          _level = widget.game.generate(next);
          _attempt = 0;
        }
      });
      if (_phase != _Phase.finished) {
        _watch();
      } else {
        _speaker.say(['Ai terminat! Bravo!']);
      }
    });
  }

  void _restart({required bool again}) {
    _timer?.cancel();
    setState(() {
      if (!again) _sessionLevel = _nextSessionLevel;
      _level = widget.game.generate(_sessionLevel);
      _round = _wins = _attempt = 0;
      _lit = null;
      _phase = _Phase.introduction;
    });
    _speaker.say([_level.instruction]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _paused) return;
    _timer?.cancel();
    _speaker.stop();
    setState(() {
      _paused = true;
      _lit = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _speaker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _speaker = ref.watch(voiceProvider);
    final motion = MotionPolicy.of(context, ref);
    final message = switch (_phase) {
      _Phase.introduction => _level.instruction,
      _Phase.watch => 'Privește',
      _Phase.turn =>
        _level.axes.reverse ? 'Rândul tău — de la ultimul' : 'Rândul tău',
      _Phase.retry => 'Mai privim o dată',
      _Phase.success => 'Bravo!',
      _Phase.moving => 'Continuăm',
      _Phase.finished => 'Ai terminat! Bravo!',
    };
    final compact = AppLayout.of(context).compact;
    final stars = _wins >= 4 ? 3 : (_wins >= 2 ? 2 : 1);
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        kind: SceneKind.evening,
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Felinarele'),
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (_paused)
                        PauseView(label: 'Continuăm', onResume: _resume)
                      else if (_phase == _Phase.finished)
                        RewardFinish(
                          stars: stars,
                          actions: [
                            FinishAction(
                              'Încă o dată',
                              Icons.replay_rounded,
                              Tokens.primary,
                              () => _restart(again: true),
                            ),
                            FinishAction(
                              'Mai departe',
                              Icons.arrow_forward_rounded,
                              Tokens.good,
                              () => _restart(again: false),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Mascot(
                                    size: compact ? 64 : 110,
                                    mood: _phase == _Phase.success
                                        ? MascotMood.happy
                                        : _phase == _Phase.retry
                                        ? MascotMood.encourage
                                        : _phase == _Phase.watch
                                        ? MascotMood.think
                                        : MascotMood.idle,
                                    reaction: _burst,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: AnimatedSwitcher(
                                        duration: motion.d(200),
                                        child: SpeechBubble(
                                          key: ValueKey(message),
                                          tail: BubbleTail.left,
                                          child: Text(
                                            message,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              // La început felinarele stau stinse, cu butonul dedesubt.
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final intro = _phase == _Phase.introduction;
                                  final side = math.min(
                                    210.0,
                                    math.max(
                                      // În joc ținta are mereu ≥ 96 dp; la prezentare felinarele pot fi mai mici.
                                      intro ? 48.0 : 96.0,
                                      math.min(
                                        (constraints.maxWidth - 48) /
                                                _level.pads.length -
                                            12,
                                        (constraints.maxHeight -
                                                (intro ? 110 : 0)) *
                                            0.8,
                                      ),
                                    ),
                                  );
                                  return Center(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 12,
                                            runSpacing: 8,
                                            children: [
                                              for (final pad in _level.pads)
                                                Semantics(
                                                  label:
                                                      'Felinarul ${pad.index + 1}',
                                                  button: true,
                                                  enabled:
                                                      _phase == _Phase.turn &&
                                                      !_locked,
                                                  value: _lit == pad.index
                                                      ? 'aprins'
                                                      : 'stins',
                                                  child: GestureDetector(
                                                    key: ValueKey(
                                                      'simon-pad-${pad.index}',
                                                    ),
                                                    onTap: () =>
                                                        _tap(pad.index),
                                                    child: _Lantern(
                                                      pad: pad,
                                                      side: side,
                                                      lit: _lit == pad.index,
                                                      motion: motion,
                                                      symbol:
                                                          _symbols[pad.index],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (intro) ...[
                                            const SizedBox(height: 18),
                                            CandyButton(
                                              label: 'Începem',
                                              icon: Icons.play_arrow_rounded,
                                              color: Tokens.good,
                                              onTap: _watch,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      if (motion.particles && !_paused)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: StarBurst(trigger: _burst, count: 8),
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

  void _resume() {
    setState(() => _paused = false);
    if (_phase == _Phase.finished || _phase == _Phase.introduction) {
      return;
    }
    if (_phase == _Phase.success || _phase == _Phase.moving) {
      final pending = _pending;
      _pending = null;
      pending?.call();
      return;
    }
    // Replay after an interruption so no part of the sequence is missed.
    _watch();
  }

  static const _symbols = [
    Icons.star_rounded,
    Icons.nightlight_round,
    Icons.spa_rounded,
    Icons.water_drop_rounded,
    Icons.wb_cloudy_rounded,
    Icons.wb_sunny_rounded,
  ];
}

/// Un felinar pictat (`sprites/lantern_<culoare>`): stins = hârtie mată; aprins = mai
/// luminos, cu un halou cald și o mică creștere. Fără ilustrație — cercul colorat cu simbol.
class _Lantern extends StatelessWidget {
  const _Lantern({
    required this.pad,
    required this.side,
    required this.lit,
    required this.motion,
    required this.symbol,
  });

  final SequencePad pad;
  final double side;
  final bool lit;
  final MotionPolicy motion;
  final IconData symbol;

  static const _names = [
    'yellow',
    'blue',
    'peach',
    'green',
    'lavender',
    'pink',
  ];

  @override
  Widget build(BuildContext context) {
    final color = Color(pad.argb);
    final fallback = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(color, const Color(0xFFFFF4CC), lit ? .65 : 0),
        border: Border.all(
          color: lit ? const Color(0xFFFFF3BE) : const Color(0xFFCED4E0),
          width: 4,
        ),
      ),
      child: Icon(symbol, size: side * 0.3, color: const Color(0xFF37465B)),
    );
    final image = Image(
      image: illustration('sprites/lantern_${_names[pad.index % 6]}'),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
    return SizedBox.square(
      dimension: side,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Haloul: lumina felinarului aprins se revarsă în jur.
          AnimatedOpacity(
            opacity: lit ? 1 : 0,
            duration: motion.d(120),
            child: Container(
              width: side * 1.5,
              height: side * 1.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xCCFFF1B8),
                    Color(0x55FFD772),
                    Color(0x00FFD772),
                  ],
                  stops: [0.15, 0.5, 1],
                ),
              ),
            ),
          ),
          AnimatedScale(
            scale: lit && motion.feedback ? 1.08 : 1,
            duration: motion.d(120),
            curve: Curves.easeOut,
            child: ColorFiltered(
              // Aprins: mai luminos și mai cald. Stins: ușor estompat, ca în amurg.
              colorFilter: ColorFilter.matrix(
                lit
                    ? const [
                        1.1, 0, 0, 0, 55, //
                        0, 1.1, 0, 0, 45,
                        0, 0, 1.0, 0, 15,
                        0, 0, 0, 1, 0,
                      ]
                    : const [
                        0.86, 0, 0, 0, 0, //
                        0, 0.86, 0, 0, 0,
                        0, 0, 0.92, 0, 0,
                        0, 0, 0, 1, 0,
                      ],
              ),
              child: image,
            ),
          ),
        ],
      ),
    );
  }
}
