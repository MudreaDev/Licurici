import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../aquarium/aquarium_store.dart';
import '../../aquarium/fish_art.dart';
import '../../aquarium/fish_render.dart';
import '../../aquarium/reef.dart';
import '../../aquarium/reef_life.dart';
import '../../aquarium/reef_scene.dart';
import '../../settings/settings.dart';

final trackLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('urmareste-pestele'));

enum _Phase { loading, show, swim, answer, feedback }

/// Urmărește peștele (ATN2b) în recif: peștele copilului strălucește, apoi înoată printre
/// ceilalți (cu aceeași fizică ca în acvariu, dar pe drumuri date de nivel); la oprire,
/// copilul îl atinge. Greșeala nu se ceartă: peștele lui strălucește iar („Uite-l!”).
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key, this.game = const TrackGame(), this.seed});

  final TrackGame game;
  final int? seed;

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  final _ambient = ValueNotifier<double>(0);
  final _chest = ReefChest();
  final _responses = <TrackResponse>[];
  final _timers = <Timer>[];
  final _rt = Stopwatch();
  final _images = <String, ui.Image>{};

  late TrackLevel _level;
  int _index = 0;
  _Phase _phase = _Phase.loading;
  Aquarium? _sim;
  var _owned = <String, OwnedFish>{};
  final _paths = <String, List<math.Point<double>>>{};
  final _depths = <String, List<double>>{};
  final _next = <String, int>{};
  int _early = 0;
  bool _warned = false;
  double _swimLeft = 0;
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  /// Peștele care strălucește (ținta la început și după răspuns) și cel atins.
  String? _glow;
  String? _picked;
  bool _pickedRight = false;
  double _glowSince = 0;

  TrackResult? _result;
  String? _sticker;

  TrackTrial get _trial => _level.trials[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(Caustics.load());
    _ticker.start();
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
    _ticker.dispose();
    _time.dispose();
    _ambient.dispose();
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // În fundal nu se măsoară nimic: runda curentă reîncepe la revenire.
    if (state != AppLifecycleState.resumed) {
      _cancel();
    } else if (_phase != _Phase.loading && _result == null) {
      _after(500, _beginTrial);
    }
  }

  void _cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _after(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  void _start() {
    _cancel();
    _level = widget.game.generate(ref.read(trackLevelProvider), seed: widget.seed);
    _responses.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _phase = _Phase.loading;
    unawaited(
      _loadImages().then((_) {
        if (!mounted) return;
        _beginTrial();
      }),
    );
  }

  /// Peștii colorați de copil, pe modele: peștele lui de urmărit poate fi chiar desenul lui.
  final _mine = <String, ui.Image>{};

  /// Desenele peștilor (colorate de Licurici), o dată pe model și culoare.
  Future<void> _loadImages() async {
    try {
      final owned = await ref.read(aquariumProvider.future).timeout(const Duration(seconds: 3));
      // Întâi peștii colorați de copil, apoi (dacă nu are alții) cadoul lui Licurici.
      for (final o in [...owned.where((o) => !o.entry.gift), ...owned.where((o) => o.entry.gift)]) {
        _mine.putIfAbsent(o.species.id, () => o.art);
      }
    } on Object {
      // Fără acvariu (sau încă necitit): peștii colorați de Licurici.
    }
    for (final t in _level.trials) {
      for (final f in t.fish) {
        final key = _key(f);
        if (_images.containsKey(key)) continue;
        final s = fishSpeciesById(f.species)!;
        var drawing = await paintGiftDrawing(s);
        if (f.hue != 0) {
          final shifted = await hueShifted(drawing, f.hue);
          drawing.dispose();
          drawing = shifted;
        }
        _images[key] = await buildFishImage(s, drawing);
        drawing.dispose();
      }
    }
  }

  String _key(TrackFish f) => '${f.species}@${f.hue.round()}';

  double get _width => _size.height == 0 ? 1.6 : _size.width / _size.height;

  math.Point<double> _toTank(TrackPoint p) {
    final w = _width;
    return math.Point(0.14 + p.x * (w - 0.28), Aquarium.top + 0.1 + p.y * (Aquarium.bottom - Aquarium.top - 0.22));
  }

  void _beginTrial() {
    _cancel();
    final sim = Aquarium(width: _width, seed: _level.seed + _index);
    _paths.clear();
    _depths.clear();
    _next.clear();
    final owned = <String, OwnedFish>{};
    for (final (i, f) in _trial.fish.indexed) {
      final id = 'f$i';
      final start = f.path.first;
      final at = _toTank(start);
      final fish =
          SwimmingFish(
              id: id,
              species: f.species,
              length: f.species == 'balon' ? 0.21 : 0.24,
              cruise: 0.13 * _level.axes.speed,
              at: at,
              z: start.z,
              yaw: at.x < _width / 2 ? 0 : math.pi,
              liveliness: fishSpeciesById(f.species)!.swim,
            )
            ..autopilot = false
            ..mode = FishMode.rest;
      fish
        ..target = fish.pos
        ..targetZ = fish.z;
      sim.fish.add(fish);
      _paths[id] = [for (final p in f.path) _toTank(p)];
      _depths[id] = [for (final p in f.path) p.z];
      _next[id] = 1;
      final s = fishSpeciesById(f.species)!;
      // Peștele copilului: desenul lui, dacă are unul de același model (și peștii nu trebuie
      // să fie identici — acolo toți arată la fel).
      final mine = i == _trial.target && _level.axes.similarity != TrackSimilarity.identical ? _mine[f.species] : null;
      owned[id] = OwnedFish(
        AquariumEntry(id: id, species: f.species, created: DateTime(2026)),
        s,
        mine ?? _images[_key(f)]!,
      );
    }
    setState(() {
      _sim = sim;
      _owned = owned;
      _phase = _Phase.show;
      _glow = 'f${_trial.target}';
      _glowSince = _time.value;
      _picked = null;
      _early = 0;
      _warned = false;
    });
    final one = _trial.fish.length == 1;
    ref.read(voiceProvider).say([
      if (_index == 0) one ? 'Urmărește peștele!' : 'Acesta e peștele tău. Urmărește-l!' else 'Urmărește-l!',
    ]);
    _after(TrackLevel.showMs, _swim);
  }

  void _swim() {
    setState(() {
      _phase = _Phase.swim;
      _glow = null;
    });
    _swimLeft = _level.axes.swimMs / 1000;
    for (final f in _sim!.fish) {
      f.mode = FishMode.wander;
      _aim(f);
    }
  }

  void _aim(SwimmingFish f) {
    final path = _paths[f.id]!, depth = _depths[f.id]!;
    // Când a terminat drumul, îl ia înapoi (până se termină timpul de înot).
    final i = _next[f.id]! % path.length;
    f
      ..target = path[i]
      ..targetZ = depth[i];
  }

  void _stop() {
    for (final f in _sim!.fish) {
      f
        ..mode = FishMode.rest
        ..target = f.pos
        ..targetZ = f.z;
    }
    setState(() => _phase = _Phase.answer);
    _rt
      ..reset()
      ..start();
    ref.read(voiceProvider).say([_trial.fish.length == 1 ? 'Atinge peștele!' : 'Unde e peștele tău?']);
    _after(TrackLevel.answerMs, () => _answer(null));
  }

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _time.value += dt;
    if (MotionPolicy.of(context, ref).ambient) _ambient.value += dt;
    final sim = _sim;
    if (sim == null) return;
    if (_phase == _Phase.swim) {
      for (final f in sim.fish) {
        if (f.pos.distanceTo(f.target) < 0.07 && (f.z - f.targetZ).abs() < 0.15) {
          _next[f.id] = _next[f.id]! + 1;
          _aim(f);
        }
      }
      _swimLeft -= dt;
      if (_swimLeft <= 0) _stop();
    }
    sim.step(dt);
  }

  /// Peștele atins: cel mai apropiat de deget, dacă degetul e pe el.
  String? _hit(Offset at) {
    final sim = _sim;
    if (sim == null || _size.height == 0) return null;
    final h = _size.height;
    final p = math.Point(at.dx / h, at.dy / h);
    String? best;
    var bd = double.infinity;
    for (final f in sim.fish) {
      final d = f.pos.distanceTo(p) / (f.apparentLength * 0.6);
      if (d < bd) {
        bd = d;
        best = f.id;
      }
    }
    return bd < 1.3 ? best : null;
  }

  void _tap(Offset at) {
    switch (_phase) {
      case _Phase.swim:
        _early++;
        if (!_warned) {
          _warned = true;
          ref.read(voiceProvider).say(['Așteaptă să se oprească.']);
        }
      case _Phase.answer:
        final id = _hit(at);
        if (id != null) _answer(int.parse(id.substring(1)));
      case _Phase.loading || _Phase.show || _Phase.feedback:
        break;
    }
  }

  void _answer(int? chosen) {
    if (_phase != _Phase.answer) return;
    _cancel();
    _rt.stop();
    final r = TrackResponse(
      _trial,
      chosen: chosen,
      rtMs: chosen == null ? null : _rt.elapsedMilliseconds,
      earlyTaps: _early,
    );
    _responses.add(r);
    final target = 'f${_trial.target}';
    setState(() {
      _phase = _Phase.feedback;
      _picked = chosen == null ? null : 'f$chosen';
      _pickedRight = r.correct;
      _glow = target;
      _glowSince = _time.value;
    });
    final sim = _sim!;
    final fish = sim.fish.firstWhere((f) => f.id == target);
    if (r.correct) {
      fish.joy = 1;
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say(['Bravo!']);
    } else {
      // Fără reproș: îi arătăm peștele lui.
      ref.read(voiceProvider).say(['Uite-l pe al tău!']);
    }
    _after(r.correct ? 1500 : 2400, _nextTrial);
  }

  void _nextTrial() {
    if (_index + 1 < _level.trials.length) {
      setState(() => _index++);
      _beginTrial();
    } else {
      _finish();
    }
  }

  void _finish() {
    _cancel();
    final result = TrackResult(_level, _responses);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.trackLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) ref.read(trackLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: const Color(0xFF1C6F9C),
      body: LayoutBuilder(
        builder: (context, c) {
          _size = c.biggest;
          return ReefScene(
            ambient: _ambient,
            chest: _chest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_sim != null && result == null)
                  Semantics(
                    label: 'Acvariul. Urmărește peștele tău și atinge-l când se oprește.',
                    child: GestureDetector(
                      key: const ValueKey('track-field'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _tap(d.localPosition),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: TrackFishPainter(
                            sim: _sim!,
                            fish: _owned,
                            time: _time,
                            glow: _glow,
                            glowSince: _glowSince,
                            picked: _picked,
                            pickedRight: _pickedRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Column(
                    children: [
                      TopBar(title: widget.game.name, trailing: result == null ? _dots() : null),
                      Expanded(
                        child: result == null
                            ? const SizedBox.shrink()
                            : RewardFinish(
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
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dots() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < _level.trials.length; i++)
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _responses.length
                ? (_responses[i].correct ? Tokens.good : const Color(0xFFF2C14E))
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
    ],
  );
}

/// Peștii jocului: umbre, haloul peștelui copilului, peștii (ca în acvariu), bule de bucurie.
class TrackFishPainter extends CustomPainter {
  TrackFishPainter({
    required this.sim,
    required this.fish,
    required this.time,
    required this.glow,
    required this.glowSince,
    required this.picked,
    required this.pickedRight,
  }) : super(repaint: time);

  final Aquarium sim;
  final Map<String, OwnedFish> fish;
  final ValueListenable<double> time;
  final String? glow;
  final double glowSince;
  final String? picked;
  final bool pickedRight;
  final _renderer = FishRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width, t = time.value;
    final order = List.of(sim.fish)..sort((a, b) => b.z.compareTo(a.z));
    for (final f in order) {
      final x = f.pos.x * h, floor = h * floorY(x, w, f.z);
      final sw = f.apparentLength * h * 0.7;
      final c = Offset(x, floor);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: sw, height: sw * 0.16),
        Paint()..shader = ui.Gradient.radial(c, sw / 2, [const Color(0x3312303C), const Color(0x0012303C)]),
      );
    }
    for (final f in order) {
      final c = Offset(f.pos.x * h, f.pos.y * h);
      final r = f.apparentLength * h * 0.75;
      if (f.id == glow) {
        // Haloul auriu care pulsează (apare lin).
        final k = ((t - glowSince) / 0.3).clamp(0.0, 1.0) * (0.8 + 0.2 * math.sin(t * 5));
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              c,
              r,
              [Color.fromRGBO(255, 236, 150, 0.75 * k), Color.fromRGBO(255, 214, 90, 0.3 * k), const Color(0x00FFD65A)],
              const [0, 0.55, 1],
            ),
        );
      }
      if (f.id == picked && !pickedRight) {
        // Peștele atins greșit: un cerc alb, liniștit (fără roșu, fără „X”).
        canvas.drawCircle(
          c,
          r * 0.7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.006
            ..color = const Color(0x99FFFFFF),
        );
      }
      final o = fish[f.id];
      if (o != null) _renderer.paint(canvas, h, f, o, t);
      if (f.id == picked && pickedRight) {
        final age = t - glowSince;
        final rnd = math.Random(3);
        for (var i = 0; i < 8; i++) {
          final k = (age / 1.2).clamp(0.0, 1.0);
          final o = Offset((rnd.nextDouble() - 0.5) * r, -k * h * (0.1 + rnd.nextDouble() * 0.08));
          paintBubble(canvas, c + o, h * (0.006 + rnd.nextDouble() * 0.008), 1 - k);
        }
      }
    }
  }

  @override
  bool shouldRepaint(TrackFishPainter old) =>
      old.sim != sim || old.glow != glow || old.picked != picked || old.fish != fish || old.glowSince != glowSince;
}
