import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final numberLineLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('linia-numerelor'));

/// Linia numerelor (PAC-N5): numărul apare mare, sus; copilul atinge locul lui pe linie. Apoi
/// licuriciul zboară la locul adevărat: dacă e aproape, laudă; dacă nu, doar „Uite unde stă.”
/// (fără semn de greșeală). Se măsoară eroarea procentuală absolută (PAE).
class NumberLineScreen extends ConsumerStatefulWidget {
  const NumberLineScreen({super.key, this.game = const NumberLineGame(), this.seed});

  final NumberLineGame game;
  final int? seed;

  @override
  ConsumerState<NumberLineScreen> createState() => _NumberLineScreenState();
}

class _NumberLineScreenState extends ConsumerState<NumberLineScreen> {
  late NumberLineLevel _level;
  final _marks = <NumberLineMark>[];
  final _clock = Stopwatch();
  int _index = 0;
  int _burst = 0;

  /// Unde a atins copilul (în unități ale liniei), până la runda următoare.
  double? _mark;
  NumberLineResult? _result;
  String? _sticker;
  Timer? _timer, _askTimer;

  NumberLineRound get _round => _level.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(numberLineLevelProvider), seed: widget.seed);
    _marks.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(['Atinge locul numărului pe linie.']);
      _ask();
    });
  }

  void _ask() {
    _mark = null;
    _clock
      ..reset()
      ..start();
    if (mounted) {
      setState(() {});
      _askTimer?.cancel();
      _askTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted && _mark == null) ref.read(voiceProvider).say(['Unde stă numărul', '${_round.target}']);
      });
    }
  }

  void _tap(double value) {
    if (_mark != null || _result != null) return;
    final mark = NumberLineMark(_round, value, latencyMs: _clock.elapsedMilliseconds);
    _marks.add(mark);
    final close = NumberLineResult(_level, [mark]).isClose(mark);
    setState(() {
      _mark = value;
      if (close) _burst++;
    });
    if (close) {
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say([ref.read(cheerProvider).correct()]);
    } else {
      ref.read(sfxProvider).play(Sfx.tap);
      ref.read(voiceProvider).say(['Uite unde stă.']);
    }
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_index + 1 < _level.rounds.length) {
        _index++;
        _ask();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = NumberLineResult(_level, _marks);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.numberLineLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(numberLineLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _askTimer?.cancel();
    super.dispose();
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
                    : _board(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(MotionPolicy motion) {
    final compact = AppLayout.of(context).compact;
    final axes = _level.axes;
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(box.maxWidth - 48, 1000.0);
        final pad = compact ? 28.0 : 40.0; // capetele liniei nu stau chiar pe margine
        final lineW = width - pad * 2;
        double xOf(double v) => pad + lineW * v / axes.max;
        final numberSize = compact ? 56.0 : 88.0;
        return Center(
          child: CandyPanel(
            padding: EdgeInsets.fromLTRB(0, compact ? 8 : 16, 0, compact ? 10 : 20),
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Numărul de așezat.
                  Juice(
                    key: ValueKey('nl-$_index'),
                    enabled: motion.feedback,
                    popTick: _burst,
                    child: Container(
                      key: const ValueKey('nl-number'),
                      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28, vertical: compact ? 2 : 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3C4),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFF2C14E), width: 4),
                      ),
                      child: Text(
                        '${_round.target}',
                        style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          fontSize: numberSize,
                          color: Tokens.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 20),
                  // Linia: se atinge oriunde pe banda ei (țintă înaltă, ușor de nimerit).
                  GestureDetector(
                    key: const ValueKey('nl-line'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _tap(((d.localPosition.dx - pad) / lineW * axes.max).clamp(0.0, axes.max.toDouble())),
                    child: Semantics(
                      label: 'Linia numerelor, de la 0 la ${axes.max}',
                      button: true,
                      child: SizedBox(
                        width: width,
                        height: compact ? 110 : 150,
                        child: CustomPaint(
                          painter: _LinePainter(
                            axes: axes,
                            pad: pad,
                            mark: _mark,
                            target: _mark == null ? null : _round.target,
                            text: Theme.of(context).textTheme.titleLarge!.copyWith(color: Tokens.ink, fontWeight: FontWeight.w800),
                          ),
                          child: _mark == null
                              ? null
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Licuriciul zboară de la semnul copilului la locul adevărat.
                                    TweenAnimationBuilder<double>(
                                      key: ValueKey('nl-fly-$_index'),
                                      tween: Tween(begin: xOf(_mark!), end: xOf(_round.target.toDouble())),
                                      duration: motion.d(700),
                                      curve: Curves.easeInOutCubic,
                                      builder: (context, x, child) => Positioned(left: x - 22, top: 0, child: child!),
                                      child: const IgnorePointer(child: StimulusArt('✨', size: 44)),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Linia (ca o riglă de lemn), reperele, numerele de la capete; după atingere, semnul
/// copilului (bulină) și locul adevărat (steag galben cu numărul).
class _LinePainter extends CustomPainter {
  _LinePainter({required this.axes, required this.pad, required this.mark, required this.target, required this.text});

  final NumberLineAxes axes;
  final double pad;
  final double? mark;
  final int? target;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.55, w = size.width - pad * 2;
    double x(double v) => pad + w * v / axes.max;
    final bar = RRect.fromRectAndRadius(Rect.fromLTRB(pad - 6, y - 9, pad + w + 6, y + 9), const Radius.circular(9));
    canvas.drawRRect(bar, Paint()..color = const Color(0xFFE2B77A));
    canvas.drawRRect(bar.shift(const Offset(0, 4)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(bar, Paint()..color = const Color(0xFFF0CB8E));
    final tick = Paint()
      ..color = const Color(0xFF8A6A3A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Capetele, mereu; reperele intermediare după nivel.
    final ticks = <double>{0, axes.max.toDouble()};
    if (axes.tick > 0) {
      for (var v = axes.tick; v < axes.max; v += axes.tick) {
        ticks.add(v.toDouble());
      }
    }
    for (final v in ticks) {
      final end = v == 0 || v == axes.max;
      canvas.drawLine(Offset(x(v), y - (end ? 22 : 14)), Offset(x(v), y + (end ? 22 : 14)), tick);
    }
    for (final v in [0, axes.max]) {
      final tp = TextPainter(text: TextSpan(text: '$v', style: text), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x(v.toDouble()) - tp.width / 2, y + 26));
    }
    final m = mark, t = target;
    if (m != null) {
      canvas.drawCircle(Offset(x(m), y), 13, Paint()..color = const Color(0xFF5B9BB5));
      canvas.drawCircle(Offset(x(m), y), 13, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white);
    }
    if (t != null) {
      final tx = x(t.toDouble());
      canvas.drawLine(Offset(tx, y), Offset(tx, y - 40), Paint()
        ..color = const Color(0xFFF2A33A)
        ..strokeWidth = 4);
      final tp = TextPainter(
        text: TextSpan(text: '$t', style: text.copyWith(color: const Color(0xFF7A4A10))),
        textDirection: TextDirection.ltr,
      )..layout();
      final flag = Rect.fromLTWH(tx - tp.width / 2 - 8, y - 40 - tp.height - 4, tp.width + 16, tp.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(flag, const Radius.circular(8)), Paint()..color = const Color(0xFFFFF3C4));
      tp.paint(canvas, Offset(flag.left + 8, flag.top + 2));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.mark != mark || old.target != target || old.axes != axes;
}
