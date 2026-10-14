import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/nothing_to_show.dart';
import '../../../shared/celebration.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../../../shared/cheer.dart';

/// Nivelul fiecărui joc de trasat (id-ul jocului: „Trasează”, „Unește punctele”).
final traceLevelProvider = NotifierProvider.family<GameLevel, int, String>(GameLevel.new);

/// Trasează (MOT1–3): copilul duce personajul cu degetul pe drum până la ținta lui. Drumul
/// e desenat din cod; partea parcursă se colorează. Ieșirea de pe drum nu se pedepsește:
/// personajul doar așteaptă degetul să revină.
class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key, this.game = const TraceGame(), this.seed});

  final TraceGame game;
  final int? seed;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen>
    with SingleTickerProviderStateMixin {
  late TraceLevel _level;
  bool _blocked = false;
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _runs = <TraceRun>[];
  final _clock = Stopwatch();
  TraceTracker? _tracker;
  Size? _field;
  int _index = 0;
  int _burst = 0;
  bool _ready = false;
  bool _holding = false;
  bool _arrived = false;
  TraceResult? _result;
  String? _sticker;
  Timer? _timer;

  TracePath get _path => _level.paths[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    // Fără imaginile pe care copilul nu trebuie să le vadă (alese de adult, `avoidItems`).
    final avoid = avoidedOf(ref);
    final level = generateAvoiding(
      (seed) => widget.game.generate(ref.read(traceLevelProvider(widget.game.id)), seed: seed),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _runs.clear();
    _index = 0;
    _tracker = null;
    _result = null;
    _sticker = null;
    _arrived = false;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _beginPath();
    });
  }

  void _beginPath() {
    _tracker =
        null; // se creează la primul layout (are nevoie de mărimea zonei)
    _arrived = false;
    _clock
      ..reset()
      ..start();
    ref.read(voiceProvider).say([_path.trip.says]);
  }

  TraceTracker _trackerFor(Size field) {
    // Urmărirea depinde de proporțiile zonei; la o schimbare de mărime (rar: fereastră
    // redimensionată) drumul reîncepe.
    if (_tracker == null || _field != field) {
      _tracker = TraceTracker(
        _path,
        width: _level.axes.width,
        aspect: field.width / field.height,
      );
      _field = field;
    }
    return _tracker!;
  }

  void _down(Offset pos, Size field) {
    if (_arrived || _result != null) return;
    final t = _trackerFor(field);
    final grabbed = t.down(pos.dx / field.width, pos.dy / field.height);
    setState(() => _holding = grabbed);
  }

  void _move(Offset pos, Size field) {
    if (!_holding || _arrived) return;
    final t = _trackerFor(field);
    final before = t.progress;
    t.move(pos.dx / field.width, pos.dy / field.height);
    if (t.progress != before) setState(() {});
    if (t.done) _arrive();
  }

  void _up() {
    _tracker?.up();
    if (_holding) setState(() => _holding = false);
  }

  void _arrive() {
    _arrived = true;
    _holding = false;
    _runs.add(_tracker!.result(ms: _clock.elapsedMilliseconds));
    ref.read(sfxProvider).play(Sfx.correct);
    setState(() {
      _burst++;
    });
    // La un desen din puncte, Licurici spune ce a ieșit („O casă!”).
    ref.read(voiceProvider).say([_path.figure?.name ?? ref.read(cheerProvider).correct()]);
    _timer = Timer(Duration(milliseconds: _path.figure == null ? 1300 : 1900), () {
      if (!mounted) return;
      if (_index + 1 < _level.paths.length) {
        setState(() {
          _index++;
        });
        _beginPath();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = TraceResult(_level, _runs);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.traceLevel(result));
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
          .read(traceLevelProvider(widget.game.id).notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return const NothingToShow();
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    if (motion.movement && !_idle.isAnimating) {
      _idle.repeat();
    } else if (!motion.movement && _idle.isAnimating) {
      _idle.stop();
    }
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
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          0,
                          8,
                          layout.compact ? 4 : 12,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: _board(motion)),
                            Positioned(
                              right: 8,
                              bottom: 4,
                              child: _Dots(
                                total: _level.paths.length,
                                done: _runs.length,
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

  Widget _board(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final field = Size(box.maxWidth, box.maxHeight);
      final tracker = _trackerFor(field);
      final road = _level.axes.width * field.height;
      final art = math.max(56.0, road * 1.25);
      Offset px(math.Point<double> p) =>
          Offset(p.x * field.width, p.y * field.height);
      final at = px(tracker.position);
      final goal = px(_path.points.last);
      return Listener(
        key: const ValueKey('trace-field'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e.localPosition, field),
        onPointerMove: (e) => _move(e.localPosition, field),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedSwitcher(
          duration: motion.d(350),
          child: Stack(
            key: ValueKey('trace-path-$_index'),
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: switch (_path.figure) {
                      final f? => _DotPainter(
                        points: [for (final p in _path.points) px(p)],
                        marks: [for (final m in dotMarks(f)) px(m)],
                        closed: f.closed,
                        progress: tracker.progress,
                        guide: _level.axes.guide,
                        done: _arrived,
                        dot: field.height * (_level.axes.guide == TraceGuide.none ? 0.026 : 0.034),
                        numberStyle: Theme.of(context).textTheme.titleLarge!,
                      ),
                      null => _RoadPainter(
                        points: [for (final p in _path.points) px(p)],
                        width: road,
                        progress: tracker.progress,
                        guide: _level.axes.guide,
                      ),
                    },
                  ),
                ),
              ),
              // Desenul din puncte: ce a ieșit apare în mijloc, la final.
              if (_path.figure case final f?)
                Positioned(
                  left: field.width / 2 - field.height * 0.16,
                  top: field.height / 2 - field.height * 0.16,
                  width: field.height * 0.32,
                  height: field.height * 0.32,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _arrived ? 1 : 0,
                      duration: motion.d(350),
                      child: AnimatedScale(
                        scale: _arrived ? 1 : 0.6,
                        duration: motion.d(400),
                        curve: Curves.easeOutBack,
                        child: StimulusArt(f.emoji, size: field.height * 0.32, semanticLabel: f.name),
                      ),
                    ),
                  ),
                ),
              // Ținta, la capătul drumului.
              if (_path.figure == null)
              Positioned(
                left: goal.dx - art / 2,
                top: goal.dy - art / 2,
                width: art,
                height: art,
                child: IgnorePointer(
                  child: AnimatedScale(
                    scale: _arrived ? 1.2 : 1,
                    duration: motion.d(300),
                    curve: Curves.easeOutBack,
                    child: StimulusArt(_path.trip.goal, size: art),
                  ),
                ),
              ),
              // Personajul, unde a ajuns degetul.
              AnimatedBuilder(
                animation: _idle,
                builder: (context, child) {
                  // Plutește ușor cât așteaptă; „crește” când e ținut.
                  final bob = motion.movement && !_holding
                      ? 4 * math.sin(_idle.value * 2 * math.pi)
                      : 0.0;
                  final pulse =
                      !_holding && tracker.progress == 0 && motion.movement
                      ? 1 + 0.06 * math.sin(_idle.value * 2 * math.pi)
                      : 1.0;
                  // La desenele din puncte, vârful creionului (colțul din stânga-jos al
                  // desenului ✏️) stă în punct, ca numărul și punctul să rămână vizibile.
                  final pen = _path.figure != null;
                  return Positioned(
                    left: pen ? at.dx - art * 0.12 : at.dx - art / 2,
                    top: (pen ? at.dy - art * 0.88 : at.dy - art / 2) + bob,
                    width: art,
                    height: art,
                    child: Transform.scale(
                      scale: (_holding ? 1.12 : 1) * pulse,
                      child: child,
                    ),
                  );
                },
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('trace-traveler'),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Tokens.sun.withValues(alpha: 0.45),
                          Tokens.sun.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: StimulusArt(_path.trip.traveler, size: art),
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
                    child: StarBurst(trigger: _burst, count: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Drumul: margine caldă, „nisip” deschis, partea parcursă aurie; ghidaj cu puncte pe mijloc
/// și o săgeată la start (după nivel).
class _RoadPainter extends CustomPainter {
  _RoadPainter({
    required this.points,
    required this.width,
    required this.progress,
    required this.guide,
  });

  final List<Offset> points;
  final double width;
  final int progress;
  final TraceGuide guide;

  Path _path(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final road = _path(points);
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Umbră moale, margine, suprafață.
    canvas.drawPath(
      road.shift(const Offset(0, 4)),
      stroke(const Color(0x22000000), width + 10),
    );
    canvas.drawPath(road, stroke(const Color(0xFFE3D2B4), width + 10));
    canvas.drawPath(road, stroke(const Color(0xFFFFF6E3), width));

    // Partea parcursă.
    if (progress > 0) {
      canvas.drawPath(
        _path(points.sublist(0, progress + 1)),
        stroke(Tokens.sun.withValues(alpha: 0.85), width * 0.7),
      );
    }

    if (guide == TraceGuide.dots) {
      final dot = Paint()..color = const Color(0xFFC9B48E);
      final step = math.max(1, points.length ~/ 14);
      for (var i = progress + step; i < points.length - step; i += step) {
        canvas.drawCircle(points[i], math.max(3, width * 0.07), dot);
      }
    }

    if (guide != TraceGuide.none && progress == 0) {
      // Săgeata: din start, în direcția drumului.
      final metric = road.computeMetrics().first;
      _arrow(canvas, metric, width);
    }
  }

  void _arrow(Canvas canvas, PathMetric metric, double width) {
    final t = metric.getTangentForOffset(math.min(metric.length, width * 1.6));
    if (t == null) return;
    final dir = t.vector;
    final normal = Offset(-dir.dy, dir.dx);
    final tip = t.position + dir * width * 0.35;
    final base = t.position - dir * width * 0.15;
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (base + normal * width * 0.28).dx,
        (base + normal * width * 0.28).dy,
      )
      ..lineTo(
        (base - normal * width * 0.28).dx,
        (base - normal * width * 0.28).dy,
      )
      ..close();
    canvas.drawPath(arrow, Paint()..color = Tokens.good.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.progress != progress ||
      old.width != width ||
      old.guide != guide ||
      old.points != points;
}

/// Bulinele drumurilor: câte sunt și câte s-au terminat.
class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: i < done ? Tokens.sun : Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE3D2B4), width: 2),
          ),
        ),
    ],
  );
}

/// Desenul din puncte: punctele numerotate (punctul următor cu halou la nivelurile mici), linia
/// trasă până unde a ajuns degetul; la final, conturul întreg.
class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.points,
    required this.marks,
    required this.closed,
    required this.progress,
    required this.guide,
    required this.done,
    required this.dot,
    required this.numberStyle,
  });

  final List<Offset> points;
  final List<Offset> marks;
  final bool closed;
  final int progress;
  final TraceGuide guide;
  final bool done;

  /// Raza unui punct.
  final double dot;

  /// Fontul aplicației pentru numere (desenul nu are acces la temă).
  final TextStyle numberStyle;

  /// Puncte dese pe fiecare latură (`dotPathPoints`).
  static const perSide = 12;

  @override
  void paint(Canvas canvas, Size size) {
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Linia trasă de copil.
    final upTo = done ? points.length - 1 : progress;
    if (upTo > 0) {
      final drawn = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1).take(upTo)) {
        drawn.lineTo(o.dx, o.dy);
      }
      if (done && closed) drawn.close();
      canvas.drawPath(drawn, stroke(Tokens.primaryDark, dot * 0.45));
    }

    // Care punct urmează (după cât din drum s-a parcurs).
    final reached = progress ~/ perSide;
    final next = done ? -1 : (reached + 1) % marks.length;
    final center = marks.fold(Offset.zero, (a, b) => a + b) / marks.length.toDouble();
    for (final (i, m) in marks.indexed) {
      final isDone = i <= reached || done;
      if (i == next && guide == TraceGuide.dots) {
        canvas.drawCircle(m, dot * 1.9, Paint()..color = Tokens.sun.withValues(alpha: 0.45));
      }
      canvas.drawCircle(m, dot, Paint()..color = isDone ? Tokens.sun : const Color(0xFFFFFDF8));
      canvas.drawCircle(m, dot, stroke(Tokens.primaryDark, dot * 0.22));
      // Numărul, lângă punct, spre exteriorul desenului (nu peste linii).
      final out = m - center;
      final dir = out.distance == 0 ? const Offset(0, -1) : out / out.distance;
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: numberStyle.copyWith(fontSize: dot * 1.5, fontWeight: FontWeight.w800, color: Tokens.ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, m + dir * dot * 2.4 - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.progress != progress || old.done != done || old.points != points || old.dot != dot;
}
