import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final causeLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('atinge-si-vezi'),
);

/// Atinge și vezi (COG1): obiectele de pe pajiște reacționează la atingere — fiecare în felul
/// lui, cu sunet. Nu există greșeli; după 10 reacții vine finalul cu abțibildul. Atingerile pe
/// lângă se numără (fără niciun semn), ca să vedem cât de țintite sunt.
class CauseScreen extends ConsumerStatefulWidget {
  const CauseScreen({super.key, this.game = const CauseGame(), this.seed});

  final CauseGame game;
  final int? seed;

  @override
  ConsumerState<CauseScreen> createState() => _CauseScreenState();
}

class _CauseScreenState extends ConsumerState<CauseScreen>
    with TickerProviderStateMixin {
  late CauseLevel _level;
  final _controllers = <AnimationController>[];
  final _touches = <CauseTouch>[];
  final _clock = Stopwatch();
  final _bursts = <int, int>{};
  final _random = math.Random();
  int _reactions = 0;
  bool _ready = false;
  CauseResult? _result;
  String? _sticker;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    _level = widget.game.generate(
      ref.read(causeLevelProvider),
      seed: widget.seed,
    );
    for (final o in _level.objects) {
      _controllers.add(
        AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: o.object.reaction == CauseReaction.float ? 1400 : 800,
          ),
        ),
      );
    }
    _touches.clear();
    _bursts.clear();
    _reactions = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Atinge și vezi ce se întâmplă!']);
      _clock
        ..reset()
        ..start();
    });
  }

  int? _since() {
    final ms = _clock.elapsedMilliseconds;
    _clock
      ..reset()
      ..start();
    return ms;
  }

  void _touchObject(int i, MotionPolicy motion) {
    if (_result != null) return;
    final o = _level.objects[i].object;
    _touches.add(
      CauseTouch(onObject: true, object: o.emoji, sinceLastMs: _since()),
    );
    if (motion.feedback) _controllers[i].forward(from: 0);
    final sfx = ref.read(sfxProvider);
    if (o.sound case final s?) {
      ref.read(voiceProvider).say([s]);
    } else {
      switch (o.reaction) {
        case CauseReaction.bang:
          sfx.drum(0);
        case CauseReaction.spin:
          sfx.play(Sfx.star);
        case CauseReaction.bloom || CauseReaction.float:
          sfx.note(_random.nextInt(6));
        case CauseReaction.jump:
          sfx.play(Sfx.tap);
      }
    }
    setState(() {
      _reactions++;
      _bursts[i] = (_bursts[i] ?? 0) + 1;
    });
    if (_reactions >= _level.goal) {
      _timer = Timer(const Duration(milliseconds: 1500), _finish);
    }
  }

  void _touchElsewhere() {
    if (_result != null || !_ready) return;
    _touches.add(const CauseTouch(onObject: false));
  }

  void _finish() {
    if (!mounted) return;
    final result = CauseResult(_level, _touches);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.causeLevel(result));
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
          .read(causeLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
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
                    : _field(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final side = math.max(80.0, _level.size * h);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Listener(
              key: const ValueKey('cause-field'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _touchElsewhere(),
            ),
          ),
          for (final (i, o) in _level.objects.indexed)
            Positioned(
              left: (o.x * w - side / 2).clamp(0.0, w - side),
              top: (o.y * h - side / 2).clamp(0.0, h - side),
              width: side,
              height: side,
              child: Semantics(
                button: true,
                label: 'Obiectul ${i + 1}',
                child: GestureDetector(
                  key: ValueKey('cause-object-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _touchObject(i, motion),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedBuilder(
                        animation: _controllers[i],
                        builder: (context, child) => _react(
                          o.object.reaction,
                          _controllers[i].value,
                          side,
                          motion,
                          child!,
                        ),
                        child: StimulusArt(o.object.emoji, size: side),
                      ),
                      if (motion.particles)
                        Positioned(
                          left: -side / 2,
                          top: -side / 2,
                          width: side * 2,
                          height: side * 2,
                          child: IgnorePointer(
                            child: StarBurst(
                              trigger: _bursts[i] ?? 0,
                              count: o.object.reaction == CauseReaction.spin
                                  ? 14
                                  : 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  /// Reacția fiecărui tip de obiect, la momentul [t] (0…1) al animației.
  Widget _react(
    CauseReaction kind,
    double t,
    double side,
    MotionPolicy motion,
    Widget child,
  ) {
    if (t == 0 || t == 1) return child;
    // Fără mișcare (modul redus): doar o luminare scurtă.
    if (!motion.movement) {
      return Opacity(
        opacity: 0.6 + 0.4 * (1 - math.sin(t * math.pi)),
        child: child,
      );
    }
    final bump = math.sin(t * math.pi); // 0 → 1 → 0
    switch (kind) {
      case CauseReaction.bloom:
        return Transform.rotate(
          angle: 0.18 * math.sin(t * math.pi * 2),
          child: Transform.scale(scale: 1 + 0.35 * bump, child: child),
        );
      case CauseReaction.jump:
        final squash = t < 0.12 ? 1 - (t / 0.12) * 0.15 : 1.0;
        return Transform.translate(
          offset: Offset(0, -side * 0.4 * bump),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(2 - squash, squash, 1),
            child: child,
          ),
        );
      case CauseReaction.float:
        return Transform.translate(
          offset: Offset(
            side * 0.08 * math.sin(t * math.pi * 3),
            -side * 0.7 * bump,
          ),
          child: child,
        );
      case CauseReaction.bang:
        final s = t < 0.15
            ? 1 - (t / 0.15) * 0.18
            : 0.82 + 0.18 * ((t - 0.15) / 0.85);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1 + (1 - s) * 0.6, s, 1),
          child: child,
        );
      case CauseReaction.spin:
        return Transform.rotate(
          angle: Curves.easeOut.transform(t) * math.pi * 2,
          child: Transform.scale(scale: 1 + 0.2 * bump, child: child),
        );
    }
  }
}
