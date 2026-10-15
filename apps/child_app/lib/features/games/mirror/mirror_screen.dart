import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/drawn_face.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final mirrorLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('oglinda'));

/// Centrul unei părți a feței, ca parte din latura pătratului în care e desenată fața
/// (aceeași geometrie ca `FacePainter`: centrul la 0,5 / 0,54, raza 0,38).
Offset partCenter(FacePart part, [int? side]) {
  final s = (side ?? -1).toDouble();
  return switch (part) {
    FacePart.par => const Offset(0.5, 0.2),
    FacePart.nas => const Offset(0.5, 0.645),
    FacePart.gura => const Offset(0.5, 0.76),
    FacePart.ochi => Offset(0.5 + s * 0.14, 0.55),
    FacePart.urechi => Offset(0.5 + s * 0.372, 0.56),
  };
}

/// Partea cea mai apropiată de punctul [p] (în fracții din latură), dacă e destul de aproape.
MirrorTouch? touchAt(Offset p) {
  MirrorTouch? best;
  var bestD = 0.15;
  for (final part in FacePart.values) {
    for (final side in part.paired ? const [-1, 1] : const [null]) {
      final d = (partCenter(part, side) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = MirrorTouch(part, side);
      }
    }
  }
  return best;
}

/// Oglinda (IMI1–3): Licurici zboară și atinge, pe rând, părți ale feței prietenului (fiecare
/// atingere face un cerc de lumină); apoi „Acum tu!” — copilul atinge aceleași locuri pe fața din
/// oglindă. O atingere greșită face oglinda să tremure; după două, Licurici arată din nou.
class MirrorScreen extends ConsumerStatefulWidget {
  const MirrorScreen({super.key, this.game = const MirrorGame(), this.seed});

  final MirrorGame game;
  final int? seed;

  @override
  ConsumerState<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends ConsumerState<MirrorScreen> {
  late MirrorLevel _level;
  final _answers = <MirrorAnswer>[];
  final _clock = Stopwatch();
  int _index = 0;
  int _step = 0;
  int _wrong = 0;
  MirrorTouch? _firstWrong;
  bool _repeated = false;
  bool _demo = false;

  /// Unde e Licurici pe fața modelului (null = în colț, odihnindu-se).
  Offset? _pointer;
  int _modelRing = 0, _mirrorRing = 0, _shake = 0, _burst = 0;
  Offset _modelRingAt = Offset.zero, _mirrorRingAt = Offset.zero;
  MascotMood _mood = MascotMood.idle;
  MirrorResult? _result;
  String? _sticker;

  /// Crește la fiecare pornire / ieșire, ca demonstrațiile vechi să se oprească.
  int _gen = 0;

  MirrorRound get _r => _level.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _gen++;
    _level = widget.game.generate(ref.read(mirrorLevelProvider), seed: widget.seed);
    _answers.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _beginRound(first: true);
  }

  void _beginRound({bool first = false}) {
    _step = 0;
    _wrong = 0;
    _firstWrong = null;
    _repeated = false;
    _mood = MascotMood.idle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(intro: first));
  }

  Future<bool> _wait(int ms, int gen) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return mounted && gen == _gen && _result == null;
  }

  /// Demonstrația: Licurici atinge, pe rând, fiecare loc; apoi copilul.
  Future<void> _show({bool intro = false}) async {
    if (!mounted || _result != null || _demo) return;
    final gen = ++_gen;
    setState(() => _demo = true);
    if (intro) ref.read(voiceProvider).say([MirrorGame.instruction]);
    if (!await _wait(intro ? 1200 : 400, gen)) return;
    for (final t in _r.touches) {
      setState(() => _pointer = partCenter(t.part, t.side));
      if (!await _wait(650, gen)) return;
      ref.read(sfxProvider).play(Sfx.bubble);
      setState(() {
        _modelRing++;
        _modelRingAt = partCenter(t.part, t.side);
      });
      if (!await _wait(750, gen)) return;
    }
    setState(() {
      _pointer = null;
      _demo = false;
    });
    ref.read(voiceProvider).say(['Acum tu!']);
    _clock
      ..reset()
      ..start();
  }

  void _replay() {
    if (_demo || _result != null) return;
    _repeated = true;
    _show();
  }

  void _touch(Offset p) {
    if (_demo || _result != null || _step >= _r.touches.length) return;
    final t = touchAt(p);
    if (t == null) return;
    final ok = _r.touches[_step].accepts(t);
    setState(() {
      _mirrorRing++;
      _mirrorRingAt = partCenter(t.part, t.side);
    });
    if (!ok) {
      _wrong++;
      _firstWrong ??= t;
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _shake++;
        _mood = MascotMood.encourage;
      });
      if (_wrong == 2) {
        _repeated = true;
        _show();
      } else {
        ref.read(voiceProvider).say([ref.read(cheerProvider).retry()]);
      }
      return;
    }
    ref.read(sfxProvider).note(_step);
    setState(() => _step++);
    if (_step < _r.touches.length) return;
    _answers.add(MirrorAnswer(_r, wrong: _wrong, ms: _clock.elapsedMilliseconds, firstWrong: _firstWrong, modelRepeated: _repeated));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say([ref.read(cheerProvider).correct(firstTry: _wrong == 0)]);
    setState(() {
      _burst++;
      _mood = MascotMood.happy;
    });
    final gen = _gen;
    _wait(1600, gen).then((go) {
      if (!go) return;
      if (_index + 1 < _level.rounds.length) {
        setState(() {
          _index++;
          _beginRound();
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = MirrorResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.mirrorLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(mirrorLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  void dispose() {
    _gen++;
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
              TopBar(
                title: widget.game.name,
                trailing: result == null
                    ? BarButton(
                        key: const ValueKey('mirror-replay'),
                        icon: Icons.visibility_rounded,
                        color: Tokens.lavender,
                        label: 'Arată din nou',
                        onTap: _replay,
                      )
                    : null,
              ),
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

  Widget _board(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final f = math.min(box.maxHeight - 40, box.maxWidth * 0.36);
      final bee = f * 0.3;
      final pointer = _pointer;
      // Licurici: pe față (vârful luminii pe locul atins) sau odihnindu-se sus, în stânga.
      final beeAt = pointer == null ? Offset(-bee * 0.2, -bee * 0.35) : Offset(pointer.dx * f - bee * 0.5, pointer.dy * f - bee * 0.78);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Prietenul pe care îl atinge Licurici.
          CandyPanel(
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(
              key: const ValueKey('mirror-model'),
              dimension: f,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _Face(look: _r.model)),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _Ring(tick: _modelRing, at: _modelRingAt, motion: motion),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: motion.d(550),
                    curve: Curves.easeInOutCubic,
                    left: beeAt.dx,
                    top: beeAt.dy,
                    child: IgnorePointer(
                      child: Mascot(size: bee, mood: _mood, reaction: _burst),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Oglinda: copilul atinge aici.
          Juice(
            enabled: motion.movement,
            shakeTick: _shake,
            popTick: _burst,
            child: Container(
              padding: EdgeInsets.all(f * 0.06),
              decoration: ShapeDecoration(
                shape: const OvalBorder(side: BorderSide(color: Color(0xFFC8955A), width: 10)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF4FBFF), Color(0xFFD6ECF7), Color(0xFFF4FBFF)],
                ),
                shadows: Tokens.shadow,
              ),
              child: Semantics(
                button: true,
                label: 'Fața din oglindă',
                child: GestureDetector(
                  key: const ValueKey('mirror-face'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _touch(d.localPosition / f),
                  child: SizedBox.square(
                    dimension: f,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _Face(look: _r.mirror)),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _Ring(tick: _mirrorRing, at: _mirrorRingAt, motion: motion),
                          ),
                        ),
                        // Câte atingeri mai sunt: buline sub bărbie.
                        if (_r.touches.length > 1)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _r.touches.length; i++)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: f * 0.045,
                                    height: f * 0.045,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < _step ? Tokens.good : const Color(0x55000000),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Fața desenată, cu nasul (fața din `drawn_face` nu are nas: aici e ținta unei atingeri).
class _Face extends StatelessWidget {
  const _Face({required this.look});

  final FaceLook look;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: DrawnFace(FaceSpec(look, FaceEmotion.bucuros, 0.6), size: double.infinity)),
      Positioned.fill(child: CustomPaint(painter: _NosePainter())),
    ],
  );
}

class _NosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, (size.height - s) / 2 + s * 0.645);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, s * 0.01), width: s * 0.09, height: s * 0.06),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawArc(
      Rect.fromCenter(center: c, width: s * 0.08, height: s * 0.05),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.016
        ..color = const Color(0x99553A2A),
    );
  }

  @override
  bool shouldRepaint(_NosePainter old) => false;
}

/// Cercul de lumină al unei atingeri: crește și se stinge.
class _Ring extends StatelessWidget {
  const _Ring({required this.tick, required this.at, required this.motion});

  final int tick;
  final Offset at;
  final MotionPolicy motion;

  @override
  Widget build(BuildContext context) {
    if (tick == 0) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(tick),
      tween: Tween(begin: 0, end: 1),
      duration: motion.d(700),
      builder: (context, v, _) => CustomPaint(painter: _RingPainter(at, v)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.at, this.v);

  final Offset at;
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v >= 1) return;
    final s = size.shortestSide;
    final c = Offset(at.dx * s, at.dy * s);
    final r = s * (0.04 + 0.08 * v);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE27A).withValues(alpha: 0.45 * (1 - v)));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.015
        ..color = const Color(0xFFF2B630).withValues(alpha: 1 - v),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.at != at;
}
