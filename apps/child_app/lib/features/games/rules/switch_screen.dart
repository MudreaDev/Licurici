import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

class SwitchProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

final switchLevelProvider = NotifierProvider<SwitchProgress, int>(
  SwitchProgress.new,
);

/// Regula se schimbă (FEX3–4): cartonașul de sus se pune într-una din cutii, după regula
/// arătată (culoare sau formă). Se atinge cutia sau se trage cartonașul în ea. Greșeala doar
/// clatină cartonașul (se înregistrează prima alegere); la schimbarea regulii, anunțul e
/// rostit și arătat mare, ca schimbarea să fie predictibilă.
class SwitchScreen extends ConsumerStatefulWidget {
  const SwitchScreen({super.key, this.game = const SwitchGame(), this.seed});

  final SwitchGame game;
  final int? seed;

  @override
  ConsumerState<SwitchScreen> createState() => _SwitchScreenState();
}

class _SwitchScreenState extends ConsumerState<SwitchScreen> {
  late SwitchLevel _level;
  final _responses = <SwitchResponse>[];
  final _clock = Stopwatch();
  int _index = 0;
  bool _answered = false;
  bool _announcing = false;
  int _shake = 0;
  final _boxPop = [0, 0];
  int _burst = 0;
  bool _ready = false;
  SwitchResult? _result;
  String? _sticker;
  Timer? _timer;

  SwitchItem get _item => _level.items[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(switchLevelProvider),
      seed: widget.seed,
    );
    _responses.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _ready = true;
    _announce(first: true);
  }

  /// Anunță regula (la început, la fiecare schimbare de bloc; amestecat: o dată, cu semnul).
  void _announce({bool first = false}) {
    final voice = ref.read(voiceProvider);
    setState(() {
      _announcing = true;
      _answered = false;
    });
    voice.say([
      if (first && _level.axes.mixed)
        'Uită-te la semn: culoare sau formă.'
      else
        SwitchGame.announce(_item.rule),
    ]);
    _timer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _announcing = false);
      _clock
        ..reset()
        ..start();
    });
  }

  void _choose(int box) {
    if (_announcing || _result != null) return;
    final ms = _clock.elapsedMilliseconds;
    if (!_answered) {
      _responses.add(SwitchResponse(_item, chosen: box, ms: ms));
      _answered = true;
    }
    if (box != _item.answer) {
      ref.read(voiceProvider).say(['Mai încearcă']);
      setState(() => _shake++);
      return;
    }
    ref.read(sfxProvider).play(Sfx.correct);
    setState(() {
      _boxPop[box]++;
      _burst++;
    });
    _timer = Timer(const Duration(milliseconds: 450), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _level.items.length) {
      _finish();
      return;
    }
    final changed =
        _level.items[_index + 1].rule != _item.rule && !_level.axes.mixed;
    setState(() {
      _index++;
      _answered = false;
    });
    if (changed) {
      _announce();
    } else {
      _clock
        ..reset()
        ..start();
    }
  }

  void _finish() {
    final result = SwitchResult(_level, _responses);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.switchLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) {
      ref
          .read(switchLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
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
                          FinishAction(
                            'Încă o dată',
                            Icons.replay_rounded,
                            Tokens.primary,
                            () => _again(next: false),
                          ),
                          FinishAction(
                            'Mai departe',
                            Icons.arrow_forward_rounded,
                            Tokens.good,
                            () => _again(next: true),
                          ),
                        ],
                      )
                    : !_ready
                    ? const SizedBox.shrink()
                    : _board(motion, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight, w = box.maxWidth;
      final card = math.min(h * 0.36, w * 0.22).clamp(70.0, 220.0);
      final boxSide = math.min(h * 0.42, w * 0.3).clamp(90.0, 260.0);
      final rule = _item.rule;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Stack(
          children: [
            Column(
              children: [
                _RuleBanner(
                  rule: rule,
                  big: _announcing,
                  compact: layout.compact,
                  motion: motion,
                ),
                const Spacer(),
                // Cartonașul de sortat: se poate trage în cutie.
                AnimatedSwitcher(
                  duration: motion.d(250),
                  child: Juice(
                    key: ValueKey('switch-card-$_index'),
                    enabled: motion.movement,
                    shakeTick: _shake,
                    child: Draggable<int>(
                      data: _index,
                      maxSimultaneousDrags: _announcing ? 0 : 1,
                      feedback: Material(
                        type: MaterialType.transparency,
                        child: _Card(
                          card: _item.card,
                          side: card,
                          cue: _level.axes.mixed ? rule : null,
                        ),
                      ),
                      childWhenDragging: SizedBox.square(dimension: card),
                      child: _Card(
                        key: const ValueKey('switch-card'),
                        card: _item.card,
                        side: card,
                        cue: _level.axes.mixed ? rule : null,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var b = 0; b < 2; b++)
                      DragTarget<int>(
                        onAcceptWithDetails: (_) => _choose(b),
                        builder: (context, hover, _) => Juice(
                          enabled: motion.movement,
                          popTick: _boxPop[b],
                          child: CandyPressable(
                            key: ValueKey('switch-box-$b'),
                            color: hover.isNotEmpty
                                ? const Color(0xFFFFF4D6)
                                : const Color(0xFFFFFBF4),
                            lipColor: b == 0
                                ? shade(Tokens.peach, 0.1)
                                : shade(Tokens.mint, 0.1),
                            border: b == 0 ? Tokens.peach : Tokens.mint,
                            borderWidth: 5,
                            width: boxSide,
                            height: boxSide * 0.72,
                            semanticLabel: 'Cutia ${b + 1}',
                            onTap: () => _choose(b),
                            child: Center(
                              child: _Card(
                                card: _level.targets[b],
                                side: boxSide * 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (motion.particles)
              Positioned.fill(
                child: IgnorePointer(
                  child: StarBurst(trigger: _burst, count: 8),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Regula curentă: un semn (paletă = culoare, forme = formă) și cuvântul. Mare cât e anunțată.
class _RuleBanner extends StatelessWidget {
  const _RuleBanner({
    required this.rule,
    required this.big,
    required this.compact,
    required this.motion,
  });

  final SortRule rule;
  final bool big;
  final bool compact;
  final MotionPolicy motion;

  @override
  Widget build(BuildContext context) {
    final color = rule == SortRule.color;
    final text = Theme.of(context).textTheme;
    return AnimatedScale(
      scale: big ? 1.25 : 1,
      duration: motion.d(300),
      curve: Curves.easeOutBack,
      child: Container(
        key: const ValueKey('switch-rule'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFBF4),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
          boxShadow: Tokens.shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RuleIcon(rule: rule, size: compact ? 26 : 36),
            const SizedBox(width: 10),
            Text(
              color ? 'După culoare' : 'După formă',
              style: (compact ? text.titleMedium : text.titleLarge)!.copyWith(
                color: Tokens.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Semnul regulii: patru buline colorate (culoare) sau trei forme goale (formă).
class _RuleIcon extends StatelessWidget {
  const _RuleIcon({required this.rule, required this.size});

  final SortRule rule;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _RuleIconPainter(rule)),
  );
}

class _RuleIconPainter extends CustomPainter {
  _RuleIconPainter(this.rule);

  final SortRule rule;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 4.4;
    final centers = [
      Offset(size.width * 0.28, size.height * 0.28),
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width * 0.28, size.height * 0.72),
      Offset(size.width * 0.72, size.height * 0.72),
    ];
    if (rule == SortRule.color) {
      for (final (i, c) in centers.indexed) {
        canvas.drawCircle(c, r, Paint()..color = Color(cardColors[i].argb));
      }
    } else {
      final ink = Paint()
        ..color = Tokens.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 14;
      for (final (i, c) in centers.indexed) {
        canvas.drawPath(
          shapePath(cardShapes[i].id, Rect.fromCircle(center: c, radius: r)),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RuleIconPainter old) => old.rule != rule;
}

/// Un cartonaș: fond crem, forma colorată desenată din cod; la regula amestecată, semnul
/// regulii în colț.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.card, required this.side, this.cue});

  final SwitchCard card;
  final double side;
  final SortRule? cue;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${card.shape.name} ${card.color.name}',
    child: Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(side * 0.14),
        border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
        boxShadow: Tokens.shadow,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(side * 0.16),
              child: CustomPaint(
                painter: _ShapePainter(card.shape.id, Color(card.color.argb)),
              ),
            ),
          ),
          if (cue != null)
            Positioned(
              right: side * 0.05,
              top: side * 0.05,
              child: _RuleIcon(rule: cue!, size: side * 0.24),
            ),
        ],
      ),
    ),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);

  final String shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shapePath(shape, Offset.zero & size);
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = shade(color, 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 28
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// Conturul formelor (stea, cerc, inimă, pătrat) încadrate în [r].
Path shapePath(String shape, Rect r) {
  final c = r.center;
  final s = r.shortestSide / 2;
  switch (shape) {
    case 'cerc':
      return Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.95));
    case 'patrat':
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: c, radius: s * 0.85),
          Radius.circular(s * 0.18),
        ),
      );
    case 'inima':
      final p = Path()
        ..moveTo(c.dx, c.dy + s * 0.9)
        ..cubicTo(
          c.dx - s * 1.25,
          c.dy + s * 0.05,
          c.dx - s * 0.75,
          c.dy - s * 1.05,
          c.dx,
          c.dy - s * 0.4,
        )
        ..cubicTo(
          c.dx + s * 0.75,
          c.dy - s * 1.05,
          c.dx + s * 1.25,
          c.dy + s * 0.05,
          c.dx,
          c.dy + s * 0.9,
        )
        ..close();
      return p;
    default: // stea
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final rad = i.isEven ? s : s * 0.45;
        final o = c + Offset(math.cos(a) * rad, math.sin(a) * rad);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p..close();
  }
}
