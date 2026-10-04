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
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

class GazeProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

final gazeLevelProvider = NotifierProvider<GazeProgress, int>(GazeProgress.new);

/// Unde se uită? (ATN3–4): Licurici, în mijloc, se întoarce spre unul din cele două obiecte
/// (și, la început, arată cu mâna). Copilul atinge obiectul. Dacă greșește când indiciul e
/// doar privirea, Licurici adaugă și gestul (ajutor); runda continuă până la răspunsul bun.
class GazeScreen extends ConsumerStatefulWidget {
  const GazeScreen({super.key, this.game = const GazeGame(), this.seed});

  final GazeGame game;
  final int? seed;

  @override
  ConsumerState<GazeScreen> createState() => _GazeScreenState();
}

class _GazeScreenState extends ConsumerState<GazeScreen> {
  late GazeLevel _level;
  final _answers = <GazeAnswer>[];
  final _clock = Stopwatch();
  final _timers = <Timer>[];
  int _round = 0;
  bool _cueOn = false;
  bool _extraCue = false;
  int? _firstChoice;
  int? _firstMs;
  bool _solved = false;
  final _shake = [0, 0];
  int _burst = 0;
  bool _ready = false;
  GazeResult? _result;
  String? _sticker;

  GazeRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _after(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  void _cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _start() {
    _cancel();
    _level = widget.game.generate(
      ref.read(gazeLevelProvider),
      seed: widget.seed,
    );
    _answers.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _beginRound();
    });
  }

  void _beginRound() {
    setState(() {
      _cueOn = false;
      _extraCue = false;
      _firstChoice = null;
      _firstMs = null;
      _solved = false;
    });
    ref.read(voiceProvider).say([_level.question]);
    // O clipă de privit înainte, apoi Licurici se întoarce.
    _after(900, () {
      setState(() => _cueOn = true);
      _clock
        ..reset()
        ..start();
    });
  }

  MascotMood get _mood {
    if (_solved) return MascotMood.happy;
    if (!_cueOn) return MascotMood.idle;
    final point = _level.axes.cue == GazeCue.point || _extraCue;
    final left = _r.side == 0;
    return point
        ? (left ? MascotMood.pointLeft : MascotMood.pointRight)
        : (left ? MascotMood.lookLeft : MascotMood.lookRight);
  }

  void _tap(int side) {
    if (!_cueOn || _solved || _result != null) return;
    if (_firstChoice == null) {
      _firstChoice = side;
      _firstMs = _clock.elapsedMilliseconds;
    }
    if (side == _r.side) {
      _answers.add(
        GazeAnswer(
          _r,
          firstChoice: _firstChoice!,
          ms: _firstMs,
          extraCue: _extraCue && _level.axes.cue == GazeCue.look,
        ),
      );
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say([_r.target.word, 'Bravo']);
      setState(() {
        _solved = true;
        _burst++;
      });
      _after(1500, () {
        if (_round + 1 < _level.rounds.length) {
          setState(() => _round++);
          _beginRound();
        } else {
          _finish();
        }
      });
    } else {
      ref.read(voiceProvider).say(['Mai încearcă']);
      setState(() {
        _shake[side]++;
        _extraCue = true; // gestul se adaugă (sau rămâne) ca ajutor
      });
    }
  }

  void _finish() {
    final result = GazeResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.gazeLevel(result));
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
          .read(gazeLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _cancel();
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
                    : _scene(motion, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scene(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight, w = box.maxWidth;
      final mascot = math.min(h * 0.82, w * 0.36);
      final card = math.min(h * 0.42, w * 0.22).clamp(80.0, 230.0);
      // Fără cadrele de privire (încă negenerate), o săgeată blândă arată direcția.
      final framesReady = IllustrationIndex.has('mascot/look_left');
      return Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Mascot(
              key: const ValueKey('gaze-mascot'),
              size: mascot,
              mood: _mood,
              reaction: _round,
            ),
          ),
          if (!framesReady && _cueOn && !_solved)
            Align(
              alignment: Alignment(_r.side == 0 ? -0.3 : 0.3, -0.2),
              child: Icon(
                _r.side == 0
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                size: mascot * 0.25,
                color: Tokens.sun,
              ),
            ),
          for (var side = 0; side < 2; side++)
            Align(
              alignment: Alignment(side == 0 ? -0.92 : 0.92, -0.1),
              child: Juice(
                enabled: motion.movement,
                shakeTick: _shake[side],
                popTick: _solved && side == _r.side ? 1 : 0,
                child: CandyPressable(
                  key: ValueKey('gaze-object-$side'),
                  color: _solved && side == _r.side
                      ? Tokens.goodSoft
                      : const Color(0xFFFFFDF8),
                  lipColor: const Color(0xFFE3D9C6),
                  border: _solved && side == _r.side ? Tokens.good : null,
                  borderWidth: _solved && side == _r.side ? 4 : 0,
                  width: card,
                  height: card,
                  semanticLabel: _r.objects[side].word,
                  onTap: () => _tap(side),
                  child: Center(
                    child: StimulusArt(
                      _r.objects[side].emoji,
                      size: card * 0.72,
                    ),
                  ),
                ),
              ),
            ),
          if (motion.particles)
            Align(
              alignment: Alignment(_r.side == 0 ? -0.92 : 0.92, -0.1),
              child: SizedBox.square(
                dimension: card * 1.6,
                child: IgnorePointer(
                  child: StarBurst(trigger: _burst, count: 10),
                ),
              ),
            ),
        ],
      );
    },
  );
}
