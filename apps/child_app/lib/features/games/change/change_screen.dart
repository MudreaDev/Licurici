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
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final changeLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('ce-s-a-schimbat'),
);

enum _Phase { look, cover, answer, done }

/// Ce s-a schimbat? (ATN5): „Privește bine!” (o bară arată cât mai e de privit), apoi o
/// cortină de nori acoperă scena o clipă, apoi scena revine schimbată. Copilul atinge ce e
/// nou sau, dacă ceva a dispărut, alege de jos ce lipsește. Greșeala doar clatină; după ea,
/// răspunsul bun pulsează.
class ChangeScreen extends ConsumerStatefulWidget {
  const ChangeScreen({super.key, this.game = const ChangeGame(), this.seed});

  final ChangeGame game;
  final int? seed;

  @override
  ConsumerState<ChangeScreen> createState() => _ChangeScreenState();
}

class _ChangeScreenState extends ConsumerState<ChangeScreen>
    with SingleTickerProviderStateMixin {
  late ChangeLevel _level;
  late final _lookBar = AnimationController(vsync: this);
  final _answers = <ChangeAnswer>[];
  final _timers = <Timer>[];
  final _clock = Stopwatch();
  final _shake = <String, int>{};
  int _round = 0;
  _Phase _phase = _Phase.look;
  bool _answered = false;
  bool _hint = false;
  int _burst = 0;
  bool _ready = false;
  ChangeResult? _result;
  String? _sticker;

  ChangeRound get _r => _level.rounds[_round];

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
      ref.read(changeLevelProvider),
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
      _phase = _Phase.look;
      _answered = false;
      _hint = false;
      _shake.clear();
    });
    ref.read(voiceProvider).say(['Privește bine!']);
    _lookBar
      ..duration = Duration(milliseconds: _level.axes.lookMs)
      ..forward(from: 0);
    _after(_level.axes.lookMs, () {
      setState(() => _phase = _Phase.cover);
      _after(ChangeLevel.coverMs, () {
        setState(() => _phase = _Phase.answer);
        ref.read(voiceProvider).say([_r.question]);
        _clock
          ..reset()
          ..start();
      });
    });
  }

  void _pick(ObjectWord o) {
    if (_phase != _Phase.answer) return;
    final correct = o == _r.target;
    if (!_answered) {
      _answered = true;
      _answers.add(
        ChangeAnswer(
          _r,
          correct: correct,
          chosen: o.word,
          ms: _clock.elapsedMilliseconds,
        ),
      );
    }
    if (correct) {
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say([o.word, 'Bravo']);
      setState(() {
        _phase = _Phase.done;
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
        _shake[o.emoji] = (_shake[o.emoji] ?? 0) + 1;
        _hint = true;
      });
    }
  }

  void _finish() {
    final result = ChangeResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.changeLevel(result));
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
          .read(changeLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _cancel();
    _lookBar.dispose();
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

  Widget _board(MotionPolicy motion, AppLayout layout) {
    final title = Theme.of(context).textTheme;
    final disappear = _r.kind == ChangeKind.disappear;
    final showAfter = _phase == _Phase.answer || _phase == _Phase.done;
    final items = showAfter ? _r.after : _r.before;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: layout.compact ? 34 : 50,
            child: _phase == _Phase.look
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedTitle(
                        'Privește bine!',
                        style: layout.compact
                            ? title.titleLarge
                            : title.headlineSmall,
                      ),
                      const SizedBox(width: 14),
                      // Cât mai e de privit: bara se golește.
                      SizedBox(
                        width: layout.compact ? 90 : 160,
                        height: 12,
                        child: AnimatedBuilder(
                          animation: _lookBar,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: 1 - _lookBar.value,
                              backgroundColor: Colors.white54,
                              color: Tokens.sun,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : showAfter
                ? OutlinedTitle(
                    _r.question,
                    style: layout.compact
                        ? title.titleLarge
                        : title.headlineSmall,
                  )
                : null,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final cw = box.maxWidth / _r.cols;
                final ch = box.maxHeight / _r.rows;
                final side = (math.min(cw, ch) * 0.78).clamp(44.0, 170.0);
                return Stack(
                  children: [
                    for (final it in items)
                      Positioned(
                        left: (it.cell % _r.cols) * cw + (cw - side) / 2,
                        top: (it.cell ~/ _r.cols) * ch + (ch - side) / 2,
                        width: side,
                        height: side,
                        child: Juice(
                          enabled: motion.movement,
                          shakeTick: _shake[it.object.emoji] ?? 0,
                          popTick:
                              _phase == _Phase.done && it.object == _r.target
                              ? 1
                              : 0,
                          pulse:
                              _hint &&
                              !disappear &&
                              _phase == _Phase.answer &&
                              it.object == _r.target,
                          child: Semantics(
                            button: true,
                            label: it.object.word,
                            child: GestureDetector(
                              key: ValueKey('change-item-${it.object.emoji}'),
                              behavior: HitTestBehavior.opaque,
                              onTapDown: disappear
                                  ? null
                                  : (_) => _pick(it.object),
                              child: StimulusArt(
                                it.object.emoji,
                                size: side,
                                semanticLabel: it.object.word,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Cortina: un nor mare care acoperă scena o clipă.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _phase == _Phase.cover ? 1 : 0,
                          duration: motion.d(250),
                          child: DecoratedBox(
                            key: const ValueKey('change-cover'),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F2FF),
                              borderRadius: BorderRadius.circular(
                                Tokens.radius,
                              ),
                              boxShadow: Tokens.shadow,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.cloud_rounded,
                                size: math.min(box.maxHeight * 0.5, 160),
                                color: Tokens.lavender,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (motion.particles)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: StarBurst(trigger: _burst, count: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (disappear && showAfter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final o in _r.options)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Juice(
                        enabled: motion.movement,
                        shakeTick: _shake[o.emoji] ?? 0,
                        pulse:
                            _hint && o == _r.target && _phase == _Phase.answer,
                        child: CandyPressable(
                          key: ValueKey('change-option-${o.emoji}'),
                          color: const Color(0xFFFFFDF8),
                          lipColor: const Color(0xFFE3D9C6),
                          width: layout.compact ? 70 : 110,
                          height: layout.compact ? 70 : 110,
                          padding: const EdgeInsets.all(8),
                          semanticLabel: o.word,
                          onTap: () => _pick(o),
                          child: StimulusArt(
                            o.emoji,
                            size: layout.compact ? 50 : 84,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
