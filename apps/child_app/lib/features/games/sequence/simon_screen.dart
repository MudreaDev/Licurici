import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/emoji_art.dart';
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
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
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
    _ambient.stop();
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
    _ambient.dispose();
    super.dispose();
  }

  Widget _button(String text, VoidCallback onPressed) => FilledButton(
    style: FilledButton.styleFrom(minimumSize: const Size(160, 64)),
    onPressed: onPressed,
    child: Text(text),
  );

  @override
  Widget build(BuildContext context) {
    _speaker = ref.watch(voiceProvider);
    final motion = MotionPolicy.of(context, ref);
    if (motion.ambient && !_paused) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
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
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        kind: SceneKind.meadow,
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Felinarele'),
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _EveningPainter(
                              _ambient,
                              motion.ambient && !_paused,
                            ),
                          ),
                        ),
                      ),
                      if (_paused)
                        Center(
                          child: _button('Continuăm', () {
                            setState(() => _paused = false);
                            if (_phase == _Phase.finished ||
                                _phase == _Phase.introduction) {
                              return;
                            }
                            if (_phase == _Phase.success ||
                                _phase == _Phase.moving) {
                              final pending = _pending;
                              _pending = null;
                              pending?.call();
                              return;
                            }
                            // Replay after an interruption so no part of the sequence is missed.
                            _watch();
                          }),
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
                                    size: 64,
                                    mood:
                                        _phase == _Phase.success ||
                                            _phase == _Phase.finished
                                        ? MascotMood.happy
                                        : _phase == _Phase.retry
                                        ? MascotMood.encourage
                                        : MascotMood.idle,
                                    reaction: _burst,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        message,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _phase == _Phase.finished
                                  ? SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              for (
                                                var i = 0;
                                                i <
                                                    (_wins >= 4
                                                        ? 3
                                                        : _wins >= 2
                                                        ? 2
                                                        : 1);
                                                i++
                                              )
                                                const EmojiArt('⭐', size: 64),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 8,
                                            children: [
                                              _button(
                                                'Încă o dată',
                                                () => _restart(again: true),
                                              ),
                                              _button(
                                                'Mai departe',
                                                () => _restart(again: false),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  : _phase == _Phase.introduction
                                  ? Center(child: _button('Începem', _watch))
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final side = math.min(
                                          128.0,
                                          math.max(
                                            96.0,
                                            (constraints.maxWidth - 48) /
                                                    _level.pads.length -
                                                8,
                                          ),
                                        );
                                        return Center(
                                          child: SingleChildScrollView(
                                            child: Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 8,
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
                                                      child: AnimatedContainer(
                                                        duration: motion.d(120),
                                                        width: side,
                                                        height: side,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Color.lerp(
                                                            Color(pad.argb),
                                                            const Color(
                                                              0xFFFFF4CC,
                                                            ),
                                                            _lit == pad.index
                                                                ? .65
                                                                : 0,
                                                          ),
                                                          border: Border.all(
                                                            color:
                                                                _lit ==
                                                                    pad.index
                                                                ? const Color(
                                                                    0xFFFFF3BE,
                                                                  )
                                                                : const Color(
                                                                    0xFFCED4E0,
                                                                  ),
                                                            width: 4,
                                                          ),
                                                          boxShadow:
                                                              _lit == pad.index
                                                              ? const [
                                                                  BoxShadow(
                                                                    color: Color(
                                                                      0x99FFE6A1,
                                                                    ),
                                                                    blurRadius:
                                                                        22,
                                                                    spreadRadius:
                                                                        3,
                                                                  ),
                                                                ]
                                                              : [],
                                                        ),
                                                        child: Icon(
                                                          _symbols[pad.index],
                                                          size: 36,
                                                          color: const Color(
                                                            0xFF37465B,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
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
                          child: StarBurst(trigger: _burst, count: 8),
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

  static const _symbols = [
    Icons.star_rounded,
    Icons.nightlight_round,
    Icons.spa_rounded,
    Icons.water_drop_rounded,
    Icons.wb_cloudy_rounded,
    Icons.wb_sunny_rounded,
  ];
}

class _EveningPainter extends CustomPainter {
  _EveningPainter(this.clock, this.animated) : super(repaint: clock);
  final Animation<double> clock;
  final bool animated;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF354362), Color(0xFF788697)],
        ).createShader(rect),
    );
    final drift = animated ? math.sin(clock.value * math.pi * 2) * 8 : 0.0;
    canvas.drawCircle(
      Offset(size.width * .88 + drift, size.height * .2),
      23,
      Paint()..color = const Color(0xFFF5E8BA),
    );
    final hill = Path()
      ..moveTo(0, size.height * .87)
      ..quadraticBezierTo(
        size.width * .35,
        size.height * .58,
        size.width,
        size.height * .88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF426B65));
  }

  @override
  bool shouldRepaint(_EveningPainter oldDelegate) =>
      oldDelegate.animated != animated;
}
