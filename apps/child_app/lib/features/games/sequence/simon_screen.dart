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
import '../../../shared/sfx.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

enum _Phase { introduction, watch, turn, retry, success, moving, finished }

class SimonScreen extends ConsumerStatefulWidget {
  const SimonScreen({
    super.key,
    this.game = const SimonGame(),
    this.initialLevel,
  });
  final SequenceGame game;

  /// Nivelul de pornire; implicit, cel la care a ajuns copilul data trecută (salvat pe tabletă).
  final int? initialLevel;

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

  /// Abțibildul primit la final.
  String? _sticker;
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
    _sessionLevel =
        widget.initialLevel ?? ref.read(settingsProvider).levelOf(widget.game.id);
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
    ref.read(sfxProvider).note(_lit!);
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
    ref.read(sfxProvider).note(index);
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
          ref
              .read(settingsProvider.notifier)
              .setGameLevel(widget.game.id, next);
          _phase = _Phase.finished;
          _sticker = ref.read(settingsProvider.notifier).awardSticker();
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
              TopBar(title: widget.game.name),
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (_paused)
                        PauseView(label: 'Continuăm', onResume: _resume)
                      else if (_phase == _Phase.finished)
                        RewardFinish(
                          stars: stars,
                          sticker: _sticker,
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
                                  if (_level.positions case final spots?) {
                                    // Licuricii din grădină: florile stau împrăștiate.
                                    final area = Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight - (intro ? 80 : 0),
                                    );
                                    // Cât mai mari, dar fără să se atingă: după cele mai apropiate două flori.
                                    var near = double.infinity;
                                    for (var i = 0; i < spots.length; i++) {
                                      for (
                                        var j = i + 1;
                                        j < spots.length;
                                        j++
                                      ) {
                                        final d = Offset(
                                          (spots[i].x - spots[j].x) *
                                              area.width,
                                          (spots[i].y - spots[j].y) *
                                              area.height,
                                        ).distance;
                                        near = math.min(near, d);
                                      }
                                    }
                                    final r = (near * 0.92)
                                        .clamp(
                                          52.0,
                                          math.max(
                                            52.0,
                                            math.min(
                                              150.0,
                                              area.shortestSide * 0.36,
                                            ),
                                          ),
                                        )
                                        .toDouble();
                                    return Column(
                                      children: [
                                        SizedBox.fromSize(
                                          size: area,
                                          child: Stack(
                                            children: [
                                              for (final pad in _level.pads)
                                                Positioned(
                                                  left:
                                                      spots[pad.index].x *
                                                          area.width -
                                                      r / 2,
                                                  top:
                                                      spots[pad.index].y *
                                                          area.height -
                                                      r / 2,
                                                  width: r,
                                                  height: r,
                                                  child: Semantics(
                                                    button: true,
                                                    label:
                                                        'Licuriciul ${pad.index + 1}',
                                                    child: GestureDetector(
                                                      key: ValueKey(
                                                        'simon-pad-${pad.index}',
                                                      ),
                                                      behavior: HitTestBehavior
                                                          .opaque,
                                                      onTap: () =>
                                                          _tap(pad.index),
                                                      child: _GardenFirefly(
                                                        lit: _lit == pad.index,
                                                        motion: motion,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (intro)
                                          CandyButton(
                                            label: 'Începem',
                                            icon: Icons.play_arrow_rounded,
                                            color: Tokens.good,
                                            onTap: _watch,
                                          ),
                                      ],
                                    );
                                  }
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
/// O floare din grădina de seară cu un licurici pe ea: stins (abia se vede) sau aprins
/// (halou cald). Toți licuricii sunt la fel: doar locul îi deosebește.
class _GardenFirefly extends StatelessWidget {
  const _GardenFirefly({required this.lit, required this.motion});

  final bool lit;
  final MotionPolicy motion;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: lit ? 1.12 : 1,
    duration: motion.d(150),
    child: CustomPaint(painter: _FireflyFlower(lit)),
  );
}

class _FireflyFlower extends CustomPainter {
  _FireflyFlower(this.lit);

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2;
    if (lit) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xCCFFF3A0),
              Color(0x55FFE07A),
              Color(0x00FFE07A),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    // Petalele.
    final petal = Paint()
      ..color = lit ? const Color(0xFFF9D5E5) : const Color(0xFF8C7FB8);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.save();
      canvas.translate(
        c.dx + math.cos(a) * r * 0.46,
        c.dy + math.sin(a) * r * 0.46,
      );
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 0.72, height: r * 0.46),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      r * 0.28,
      Paint()..color = lit ? const Color(0xFFFFD45E) : const Color(0xFF5E5486),
    );
    // Licuriciul: corpul și lumina din coadă.
    final body = c + Offset(0, -r * 0.07);
    canvas.drawOval(
      Rect.fromCenter(center: body, width: r * 0.3, height: r * 0.42),
      Paint()..color = const Color(0xFF3E4A5C),
    );
    canvas.drawCircle(
      body + Offset(0, r * 0.17),
      r * (lit ? 0.2 : 0.14),
      Paint()..color = lit ? const Color(0xFFFFF6B0) : const Color(0xFF9A9468),
    );
    final wing = Paint()..color = const Color(0x88E8F1FF);
    canvas.drawOval(
      Rect.fromCenter(
        center: body + Offset(-r * 0.18, -r * 0.11),
        width: r * 0.28,
        height: r * 0.17,
      ),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: body + Offset(r * 0.18, -r * 0.11),
        width: r * 0.28,
        height: r * 0.17,
      ),
      wing,
    );
  }

  @override
  bool shouldRepaint(_FireflyFlower old) => old.lit != lit;
}

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
