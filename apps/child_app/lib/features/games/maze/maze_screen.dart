import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../../../shared/cheer.dart';

final mazeLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('labirint'));

/// Labirint (FEX7): peștișorul pornește din colțul de sus-stânga, casa e în colțul opus.
/// Degetul îl duce pe culoare, celulă cu celulă; prin pereți nu trece (lovirea se numără, fără
/// niciun semn de greșeală). Drumul parcurs rămâne colorat.
class MazeScreen extends ConsumerStatefulWidget {
  const MazeScreen({super.key, this.game = const MazeGame(), this.seed});

  final MazeGame game;
  final int? seed;

  @override
  ConsumerState<MazeScreen> createState() => _MazeScreenState();
}

class _MazeScreenState extends ConsumerState<MazeScreen> {
  late MazeLevel _level;
  late MazeWalker _walker;
  final _runs = <MazeRun>[];
  final _trail = <int>[];
  final _clock = Stopwatch();
  int? _planMs;
  int _index = 0;
  int _burst = 0;
  bool _ready = false;
  MazeResult? _result;
  String? _sticker;
  Timer? _timer;

  Maze get _maze => _level.mazes[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(mazeLevelProvider),
      seed: widget.seed,
    );
    _runs.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    _beginMaze();
    Future(
      () => mounted ? precacheStimuli(context, {'🐟', '🏠'}) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Du peștișorul acasă.']);
    });
  }

  void _beginMaze() {
    _walker = MazeWalker(_maze);
    _trail
      ..clear()
      ..add(0);
    _planMs = null;
    _clock
      ..reset()
      ..start();
  }

  void _finger(Offset local, double cell) {
    if (_walker.done || _result != null) return;
    final c = (local.dx / cell).floor(), r = (local.dy / cell).floor();
    if (c < 0 || r < 0 || c >= _maze.cols || r >= _maze.rows) return;
    final before = _walker.position;
    if (_walker.toward(_maze.index(c, r))) {
      _planMs ??= _clock.elapsedMilliseconds;
      // Drumul parcurs (fără bucle: la întoarcere, coada se șterge).
      for (final i in _maze.path(before, _walker.position).skip(1)) {
        final k = _trail.indexOf(i);
        if (k >= 0) {
          _trail.removeRange(k + 1, _trail.length);
        } else {
          _trail.add(i);
        }
      }
      setState(() {});
      if (_walker.done) _arrive();
    }
  }

  void _arrive() {
    _runs.add(
      MazeRun(
        _maze,
        efficiency: _walker.efficiency,
        bumps: _walker.bumps,
        ms: _clock.elapsedMilliseconds,
        planMs: _planMs,
      ),
    );
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say([ref.read(cheerProvider).correct()]);
    setState(() => _burst++);
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_index + 1 < _level.mazes.length) {
        setState(() {
          _index++;
          _beginMaze();
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = MazeResult(_level, _runs);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.mazeLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) {
      ref
          .read(mazeLevelProvider.notifier)
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
                    : _board(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final cell = math.min(
        (box.maxWidth - 32) / _maze.cols,
        (box.maxHeight - 16) / _maze.rows,
      );
      final w = cell * _maze.cols, h = cell * _maze.rows;
      Offset center(int i) {
        final (c, r) = _maze.cell(i);
        return Offset((c + 0.5) * cell, (r + 0.5) * cell);
      }

      final art = cell * 0.72;
      final at = center(_walker.position), goal = center(_walker.goal);
      return Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xF2FFFBF4),
            borderRadius: BorderRadius.circular(18),
            boxShadow: Tokens.shadow,
          ),
          child: SizedBox(
            width: w,
            height: h,
            child: Listener(
              key: const ValueKey('maze-field'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _finger(e.localPosition, cell),
              onPointerMove: (e) => _finger(e.localPosition, cell),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MazePainter(_maze, cell, [
                        for (final i in _trail) center(i),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: goal.dx - art / 2,
                    top: goal.dy - art / 2,
                    child: IgnorePointer(child: StimulusArt('🏠', size: art)),
                  ),
                  AnimatedPositioned(
                    duration: motion.d(140),
                    left: at.dx - art / 2,
                    top: at.dy - art / 2,
                    child: IgnorePointer(
                      child: Juice(
                        enabled: motion.movement,
                        popTick: _burst,
                        child: StimulusArt(
                          '🐟',
                          key: const ValueKey('maze-fish'),
                          size: art,
                        ),
                      ),
                    ),
                  ),
                  if (motion.particles)
                    Positioned(
                      left: goal.dx - art,
                      top: goal.dy - art,
                      width: art * 2,
                      height: art * 2,
                      child: IgnorePointer(
                        child: StarBurst(trigger: _burst, count: 12),
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

class _MazePainter extends CustomPainter {
  _MazePainter(this.maze, this.cell, this.trail);

  final Maze maze;
  final double cell;
  final List<Offset> trail;

  @override
  void paint(Canvas canvas, Size size) {
    // Drumul parcurs: o dâră aurie, moale.
    if (trail.length > 1) {
      final p = Path()..moveTo(trail.first.dx, trail.first.dy);
      for (final o in trail.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = Tokens.sun.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final wall = Paint()
      ..color = const Color(0xFF7FC0A3)
      ..strokeWidth = math.max(4, cell * 0.1)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < maze.walls.length; i++) {
      final (c, r) = maze.cell(i);
      final x = c * cell, y = r * cell;
      if (!maze.open(i, MazeDir.up)) {
        canvas.drawLine(Offset(x, y), Offset(x + cell, y), wall);
      }
      if (!maze.open(i, MazeDir.left)) {
        canvas.drawLine(Offset(x, y), Offset(x, y + cell), wall);
      }
      if (c == maze.cols - 1 && !maze.open(i, MazeDir.right)) {
        canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), wall);
      }
      if (r == maze.rows - 1 && !maze.open(i, MazeDir.down)) {
        canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), wall);
      }
    }
  }

  @override
  bool shouldRepaint(_MazePainter old) =>
      old.maze != maze || old.cell != cell || old.trail.length != trail.length;
}
