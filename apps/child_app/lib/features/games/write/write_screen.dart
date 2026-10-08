import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

/// Nivelul curent, separat pe joc (cifre / litere).
class WriteProgress extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};
  int of(String id) => state[id] ?? 1;
  void setLevel(String id, int level) => state = {...state, id: level};
}

final writeLevelProvider = NotifierProvider<WriteProgress, Map<String, int>>(WriteProgress.new);

/// Culorile cretei, câte una pe trăsătură.
const _chalk = [Color(0xFFFFD45E), Color(0xFF7FE0C9), Color(0xFFFF9FC0), Color(0xFF9CC8FF), Color(0xFFC4A6FF)];

/// Scriem cifrele / Scriem literele: o tablă de școală cu semnul scris ca un șanț de cretă.
/// Copilul duce steluța pe fiecare trăsătură, în ordine (cifra de la începutul trăsăturii
/// arată care urmează); partea scrisă se colorează. Ieșirea de pe drum nu se pedepsește:
/// steluța așteaptă degetul. La final: semnul strălucește și Licurici îl spune.
class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key, required this.game, this.seed});

  final WritingGame game;
  final int? seed;

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> with SingleTickerProviderStateMixin {
  late WritingLevel _level;
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  final _runs = <WritingRun>[];
  final _strokeRuns = <TraceRun>[];
  final _clock = Stopwatch();
  List<TracePath>? _paths;
  TraceTracker? _tracker;
  Size? _field;
  int _index = 0;
  int _stroke = 0;
  int _burst = 0;
  bool _ready = false;
  bool _holding = false;
  bool _glyphDone = false;
  WritingResult? _result;
  String? _sticker;
  Timer? _timer;

  Glyph get _glyph => _level.glyphs[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(writeLevelProvider.notifier).of(widget.game.id), seed: widget.seed);
    _runs.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    final pictures = {for (final g in _level.glyphs) ?g.picture};
    Future(() => mounted ? precacheStimuli(context, pictures) : null).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _beginGlyph();
    });
  }

  void _beginGlyph() {
    _paths = null; // se așază la primul layout (depind de mărimea tablei)
    _tracker = null;
    _stroke = 0;
    _strokeRuns.clear();
    _glyphDone = false;
    _clock
      ..reset()
      ..start();
    ref.read(voiceProvider).say([widget.game.instructionFor(_glyph)]);
  }

  List<TracePath> _pathsFor(Size field) {
    // Așezarea depinde de proporțiile tablei; la o schimbare de mărime semnul reîncepe.
    if (_paths == null || _field != field) {
      _paths = _glyph.fit(field.width / field.height, height: 0.78);
      _field = field;
      _stroke = 0;
      _strokeRuns.clear();
      _tracker = null;
    }
    return _paths!;
  }

  TraceTracker _trackerFor(Size field) {
    final paths = _pathsFor(field);
    return _tracker ??= TraceTracker(paths[_stroke], width: _level.axes.width, aspect: field.width / field.height);
  }

  void _down(Offset pos, Size field) {
    if (_glyphDone || _result != null) return;
    final grabbed = _trackerFor(field).down(pos.dx / field.width, pos.dy / field.height);
    setState(() => _holding = grabbed);
  }

  void _move(Offset pos, Size field) {
    if (!_holding || _glyphDone) return;
    final t = _trackerFor(field);
    final before = t.progress;
    t.move(pos.dx / field.width, pos.dy / field.height);
    if (t.progress != before) setState(() {});
    if (t.done) _strokeDone(field);
  }

  void _up() {
    _tracker?.up();
    if (_holding) setState(() => _holding = false);
  }

  void _strokeDone(Size field) {
    _strokeRuns.add(_tracker!.result());
    _holding = false;
    if (_stroke + 1 < _paths!.length) {
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _stroke++;
        _tracker = TraceTracker(_paths![_stroke], width: _level.axes.width, aspect: field.width / field.height);
      });
      return;
    }
    _glyphDone = true;
    _runs.add(WritingRun(_glyph, List.of(_strokeRuns), ms: _clock.elapsedMilliseconds));
    ref.read(sfxProvider).play(Sfx.correct);
    setState(() => _burst++);
    ref.read(voiceProvider).say([widget.game.praiseFor(_glyph)]);
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      if (_index + 1 < _level.glyphs.length) {
        setState(() => _index++);
        _beginGlyph();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = WritingResult(_level, _runs);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.writingLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) {
      ref.read(writeLevelProvider.notifier).setLevel(widget.game.id, _result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  Widget build(BuildContext context) {
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
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
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
                        padding: EdgeInsets.fromLTRB(12, 0, 12, layout.compact ? 6 : 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _Chalkboard(child: _board(motion))),
                            SizedBox(width: layout.compact ? 8 : 16),
                            SizedBox(width: layout.compact ? 120 : 220, child: _side(layout)),
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

  /// În dreapta: poza cuvântului (când are), Licurici și cât a scris.
  Widget _side(AppLayout layout) {
    final g = _glyph;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: CandyPanel(
              key: ValueKey(_index),
              padding: EdgeInsets.all(layout.compact ? 6 : 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      child: Text(
                        g.char,
                        style: text.displayLarge!.copyWith(color: Tokens.ink, fontWeight: FontWeight.w800, height: 1),
                      ),
                    ),
                  ),
                  if (g.picture != null)
                    Expanded(flex: 3, child: StimulusArt(g.picture!, size: layout.compact ? 64 : 120))
                  else if (int.tryParse(g.char) case final n? when n > 0)
                    Expanded(flex: 3, child: _Count(n)),
                  if (g.word != null)
                    FittedBox(
                      child: Text(g.word!, style: text.titleMedium!.copyWith(color: Tokens.ink)),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: layout.compact ? 4 : 10),
        Mascot(size: layout.compact ? 64 : 110, mood: _glyphDone ? MascotMood.happy : MascotMood.idle),
        _Dots(total: _level.glyphs.length, done: _runs.length),
      ],
    );
  }

  Widget _board(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final field = Size(box.maxWidth, box.maxHeight);
      final paths = _pathsFor(field);
      final tracker = _trackerFor(field);
      final road = _level.axes.width * field.height;
      Offset px(math.Point<double> p) => Offset(p.x * field.width, p.y * field.height);
      final at = px(tracker.position);
      final star = math.max(44.0, road * 1.3);
      return Semantics(
        label: 'Tabla. ${widget.game.instructionFor(_glyph)} Duce steluța cu degetul pe fiecare trăsătură.',
        child: Listener(
          key: const ValueKey('write-field'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e.localPosition, field),
          onPointerMove: (e) => _move(e.localPosition, field),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) => CustomPaint(
                    painter: _GlyphPainter(
                      strokes: [
                        for (final p in paths) [for (final q in p.points) px(q)],
                      ],
                      width: road,
                      active: _glyphDone ? paths.length : _stroke,
                      progress: tracker.progress,
                      guide: _level.axes.guide,
                      pulse: motion.movement ? _idle.value : 0,
                      shine: _glyphDone,
                    ),
                  ),
                ),
              ),
              if (!_glyphDone)
                AnimatedBuilder(
                  animation: _idle,
                  builder: (context, child) {
                    final pulse = !_holding && tracker.progress == 0 && motion.movement
                        ? 1 + 0.1 * math.sin(_idle.value * 2 * math.pi)
                        : 1.0;
                    return Positioned(
                      left: at.dx - star / 2,
                      top: at.dy - star / 2,
                      width: star,
                      height: star,
                      child: IgnorePointer(
                        child: Transform.scale(scale: (_holding ? 1.15 : 1) * pulse, child: child),
                      ),
                    );
                  },
                  child: CustomPaint(painter: _StarPainter()),
                ),
              if (motion.particles)
                Positioned.fill(
                  child: IgnorePointer(child: StarBurst(trigger: _burst, count: 14)),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Tabla: verde, cu ramă de lemn și urme ușoare de cretă.
class _Chalkboard extends StatelessWidget {
  const _Chalkboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB57A45), Color(0xFF8C5A2E)],
      ),
      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 5))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(painter: const _SlatePainter(), child: child),
      ),
    ),
  );
}

class _SlatePainter extends CustomPainter {
  const _SlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(r.center, size.longestSide * 0.7, const [Color(0xFF3F7A5C), Color(0xFF2C5C45)]),
    );
    // Urme șterse de cretă.
    final rnd = math.Random(4);
    for (var i = 0; i < 14; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: size.width * (0.1 + rnd.nextDouble() * 0.25), height: size.height * 0.06),
        Paint()..color = const Color(0x0DFFFFFF),
      );
    }
    // Liniatura de caiet, foarte discretă.
    final line = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1.5;
    for (final y in [0.11, 0.89]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), line);
    }
  }

  @override
  bool shouldRepaint(_SlatePainter old) => false;
}

/// Semnul: șanțurile de cretă, trăsăturile scrise (colorate), trăsătura de acum cu
/// începutul numerotat și ajutorul (puncte, săgeată), după nivel.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.strokes,
    required this.width,
    required this.active,
    required this.progress,
    required this.guide,
    required this.pulse,
    required this.shine,
  });

  final List<List<Offset>> strokes;
  final double width;
  final int active;
  final int progress;
  final TraceGuide guide;
  final double pulse;
  final bool shine;

  Path _path(List<Offset> pts, [int? upTo]) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i <= (upTo ?? pts.length - 1) && i < pts.length; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final round = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Șanțurile (tot semnul), ca o urmă de cretă.
    for (final s in strokes) {
      canvas.drawPath(
        _path(s),
        round
          ..strokeWidth = width
          ..color = const Color(0x33FFFFFF),
      );
      canvas.drawPath(
        _path(s),
        round
          ..strokeWidth = width * 0.12
          ..color = const Color(0x22FFFFFF),
      );
    }
    // Trăsăturile scrise și cea de acum, până unde a ajuns.
    for (var i = 0; i < strokes.length && i <= active; i++) {
      final done = i < active;
      if (!done && progress == 0) continue;
      final col = _chalk[i % _chalk.length];
      final p = _path(strokes[i], done ? null : progress);
      if (shine) {
        canvas.drawPath(
          p,
          round
            ..strokeWidth = width * 1.5
            ..color = col.withValues(alpha: 0.35),
        );
      }
      canvas.drawPath(
        p,
        round
          ..strokeWidth = width * 0.62
          ..color = col,
      );
      canvas.drawPath(
        p.shift(Offset(-width * 0.08, -width * 0.08)),
        round
          ..strokeWidth = width * 0.16
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }
    if (active >= strokes.length) return;
    final s = strokes[active];
    // Ajutorul: puncte pe mijloc, săgeți pe direcție.
    if (guide == TraceGuide.dots) {
      final dot = Paint()..color = const Color(0xCCFFFFFF);
      for (var i = progress + 4; i < s.length - 1; i += 5) {
        canvas.drawCircle(s[i], width * 0.08, dot);
      }
    }
    if (guide != TraceGuide.none && progress == 0) {
      final k = math.min(s.length - 1, 8);
      final dir = s[k] - s[0];
      final n = dir / math.max(dir.distance, 1e-6);
      final tip = s[0] + n * width * (1.5 + 0.2 * math.sin(pulse * 2 * math.pi));
      final side = Offset(-n.dy, n.dx) * width * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx + n.dx * width * 0.45, tip.dy + n.dy * width * 0.45)
          ..lineTo(tip.dx + side.dx, tip.dy + side.dy)
          ..lineTo(tip.dx - side.dx, tip.dy - side.dy)
          ..close(),
        Paint()..color = const Color(0xFFFFE27A),
      );
    }
    // Începutul trăsăturii: un cerc verde cu numărul ei (ordinea scrisului).
    if (progress == 0 && strokes.length > 1) {
      final c = s[0] + Offset(-width * 0.9, -width * 0.9);
      canvas.drawCircle(c, width * 0.42, Paint()..color = const Color(0xFF6FCF97));
      final tp = TextPainter(
        text: TextSpan(
          text: '${active + 1}',
          style: TextStyle(color: Colors.white, fontSize: width * 0.55, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => true;
}

/// Steluța pe care o duce degetul.
class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, const [Color(0x88FFF3B0), Color(0x00FFF3B0)]));
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * 0.62 : r * 0.28;
      final q = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFD45E));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFE7A92B),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// Cât înseamnă cifra: atâtea steluțe, așezate ca pe zar (câte 3 pe rând).
class _Count extends StatelessWidget {
  const _Count(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final rows = (n / 3).ceil();
      final side = math.min(box.maxWidth / 3, box.maxHeight / rows) * 0.9;
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              SizedBox.square(
                dimension: side,
                child: CustomPaint(painter: _StarPainter()),
              ),
          ],
        ),
      );
    },
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? Tokens.good : Colors.white.withValues(alpha: 0.7),
            ),
          ),
      ],
    ),
  );
}
