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
import '../rules/switch_screen.dart' show shapePath;

final buildLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('construieste'),
);

/// Construiește la fel (IMI5): modelul în stânga, grila goală în dreapta, paleta jos. Copilul
/// alege o piesă (o atinge sau o trage) și o pune în locul ei. Piesa greșită nu se pune (doar
/// locul se clatină). De la nivelul 6 modelul se ascunde; ochiul îl arată din nou (ajutor).
class BuildScreen extends ConsumerStatefulWidget {
  const BuildScreen({super.key, this.game = const BuildGame(), this.seed});

  final BuildGame game;
  final int? seed;

  @override
  ConsumerState<BuildScreen> createState() => _BuildScreenState();
}

class _BuildScreenState extends ConsumerState<BuildScreen> {
  late BuildLevel _level;
  final _solves = <BuildSolve>[];
  final _placed = <int>{};
  final _shake = <int, int>{};
  final _clock = Stopwatch();
  int _round = 0;
  int _wrong = 0;
  int? _selected;
  bool _hidden = false;
  bool _peeked = false;
  bool _done = false;
  int _burst = 0;
  bool _ready = false;
  BuildResult? _result;
  String? _sticker;
  Timer? _timer;

  BuildRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(buildLevelProvider),
      seed: widget.seed,
    );
    _solves.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = true;
    _beginRound();
  }

  void _beginRound() {
    _placed.clear();
    _shake.clear();
    _wrong = 0;
    _selected = null;
    _hidden = false;
    _peeked = false;
    _done = false;
    final hide = _level.axes.hideModelMs;
    ref.read(voiceProvider).say([
      hide == null ? 'Fă la fel ca modelul.' : 'Ține minte modelul!',
    ]);
    if (hide != null) {
      _timer = Timer(Duration(milliseconds: hide), () {
        if (mounted) setState(() => _hidden = true);
      });
    }
    _clock
      ..reset()
      ..start();
  }

  void _peek() {
    if (!_hidden) return;
    _peeked = true;
    setState(() => _hidden = false);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_done) setState(() => _hidden = true);
    });
  }

  void _put(int paletteIndex, int cell) {
    if (_done || _placed.contains(cell)) return;
    if (_r.palette[paletteIndex] == _r.model[cell]) {
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() => _placed.add(cell));
      if (_placed.length == _r.model.length) _complete();
    } else {
      setState(() {
        _wrong++;
        _shake[cell] = (_shake[cell] ?? 0) + 1;
      });
    }
  }

  void _complete() {
    _timer?.cancel();
    _solves.add(
      BuildSolve(
        _r,
        wrongMoves: _wrong,
        ms: _clock.elapsedMilliseconds,
        peeked: _peeked,
      ),
    );
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Bravo']);
    setState(() {
      _done = true;
      _hidden = false;
      _burst++;
    });
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_round + 1 < _level.rounds.length) {
        setState(() => _round++);
        _beginRound();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = BuildResult(_level, _solves);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.buildLevel(result));
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
          .read(buildLevelProvider.notifier)
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
      final palette = layout.compact ? 58.0 : 86.0;
      // − paleta, spațiile și chenarul grilei (padding 12 + margine 6).
      final gridH = box.maxHeight - palette - 34 - 20;
      final cell = math
          .min(gridH / _r.rows, (box.maxWidth - 80) / 2 / _r.cols)
          .clamp(40.0, 150.0);
      Widget grid({required bool model}) => Container(
        key: ValueKey(model ? 'build-model' : 'build-work'),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFBF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: model ? Tokens.lavender : Tokens.mint,
            width: 3,
          ),
          boxShadow: Tokens.shadow,
        ),
        child: SizedBox(
          width: cell * _r.cols,
          height: cell * _r.rows,
          child: Stack(
            children: [
              for (var i = 0; i < _r.model.length; i++)
                Positioned(
                  left: (i % _r.cols) * cell,
                  top: (i ~/ _r.cols) * cell,
                  width: cell,
                  height: cell,
                  child: model
                      ? (_hidden
                            ? const SizedBox.shrink()
                            : _Piece(_r.model[i], side: cell))
                      : DragTarget<int>(
                          onAcceptWithDetails: (d) => _put(d.data, i),
                          builder: (context, hover, _) => Semantics(
                            button: true,
                            label: 'Locul ${i + 1}',
                            child: GestureDetector(
                              key: ValueKey('build-cell-$i'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _selected == null
                                  ? null
                                  : () => _put(_selected!, i),
                              child: Juice(
                                enabled: motion.movement,
                                shakeTick: _shake[i] ?? 0,
                                child: _placed.contains(i)
                                    ? _Piece(_r.model[i], side: cell)
                                    : Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: hover.isNotEmpty
                                              ? Tokens.sun.withValues(
                                                  alpha: 0.3,
                                                )
                                              : const Color(0x14000000),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                ),
              if (model && _hidden)
                Positioned.fill(
                  child: Center(
                    child: CandyPressable(
                      key: const ValueKey('build-peek'),
                      color: Tokens.lavender,
                      lipColor: shade(Tokens.lavender, 0.15),
                      width: 64,
                      height: 64,
                      radius: 32,
                      semanticLabel: 'Arată modelul',
                      onTap: _peek,
                      child: const Icon(
                        Icons.visibility_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              if (!model && motion.particles)
                Positioned.fill(
                  child: IgnorePointer(
                    child: StarBurst(trigger: _burst, count: 12),
                  ),
                ),
            ],
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  grid(model: true),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: layout.compact ? 28 : 40,
                  ),
                  grid(model: false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, p) in _r.palette.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Draggable<int>(
                      data: i,
                      feedback: _Piece(p, side: palette),
                      child: Semantics(
                        button: true,
                        label: 'Piesa ${i + 1}',
                        child: GestureDetector(
                          key: ValueKey('build-palette-$i'),
                          // Piesa rămâne aleasă: același tip se pune de mai multe ori.
                          onTap: () => setState(() => _selected = i),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selected == i
                                    ? Tokens.sun
                                    : Colors.transparent,
                                width: 4,
                              ),
                            ),
                            child: _Piece(p, side: palette),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// O piesă: pătrat crem cu forma colorată.
class _Piece extends StatelessWidget {
  const _Piece(this.card, {required this.side});

  final SwitchCard card;
  final double side;

  @override
  Widget build(BuildContext context) => Container(
    width: side,
    height: side,
    padding: EdgeInsets.all(side * 0.14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDF8),
      borderRadius: BorderRadius.circular(side * 0.16),
      border: Border.all(color: const Color(0xFFE3D9C6), width: 2),
    ),
    child: CustomPaint(painter: _ShapePainter(card)),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.card);

  final SwitchCard card;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shapePath(card.shape.id, Offset.zero & size);
    canvas.drawPath(path, Paint()..color = Color(card.color.argb));
    canvas.drawPath(
      path,
      Paint()
        ..color = shade(Color(card.color.argb), 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, size.width / 28),
    );
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.card != card;
}
