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
import '../../../shared/nothing_to_show.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final rhythmLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('toba-magica'),
);

enum _Phase { listen, play, done }

/// Toba magică (IMI4): Licurici bate ritmul (toba sare, se aude), apoi copilul bate la fel.
/// Dacă ritmul nu iese, Licurici îl mai bate o dată și copilul mai încearcă (ajutor, P4).
/// Se poate cere oricând să audă din nou (butonul cu urechea).
class RhythmScreen extends ConsumerStatefulWidget {
  const RhythmScreen({super.key, this.game = const RhythmGame(), this.seed});

  final RhythmGame game;
  final int? seed;

  @override
  ConsumerState<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends ConsumerState<RhythmScreen>
    with SingleTickerProviderStateMixin {
  late RhythmLevel _level;
  final _plays = <RhythmPlay>[];
  final _taps = <RhythmBeat>[];

  /// Ceasul bătăilor: timpul cadrelor (precizie ~16 ms), pornit doar cât e rândul copilului.
  /// Merge și cu timpul simulat din teste, spre deosebire de un `Stopwatch`.
  late final _ticker = createTicker((elapsed) => _now = elapsed);
  Duration _now = Duration.zero;
  Duration _firstTap = Duration.zero;
  final _hop = [0, 0];
  final _timers = <Timer>[];
  int _round = 0;
  int _replays = 0;
  int? _startMs;
  int _generation = 0;
  int _burst = 0;
  int _reaction = 0;
  MascotMood _mood = MascotMood.idle;
  _Phase _phase = _Phase.listen;
  bool _ready = false;
  RhythmResult? _result;
  String? _sticker;

  RhythmPattern get _pattern => _level.patterns[_round];

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
    if (isAvoided(widget.game.emoji, avoidedOf(ref))) return;
    _generation++;
    _level = widget.game.generate(
      ref.read(rhythmLevelProvider),
      seed: widget.seed,
    );
    _plays.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, {'🥁'}) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _beginRound();
    });
  }

  void _beginRound() {
    _replays = 0;
    _startMs = null;
    _listen(intro: true);
  }

  /// Licurici bate ritmul; la final e rândul copilului.
  void _listen({bool intro = false}) {
    _cancel();
    if (_ticker.isActive) _ticker.stop();
    final generation = ++_generation;
    setState(() {
      _phase = _Phase.listen;
      _taps.clear();
      _mood = MascotMood.idle;
    });
    final voice = ref.read(voiceProvider);
    voice.say([
      intro ? 'Ascultă ritmul lui Licurici.' : 'Mai ascultăm o dată.',
    ]);
    const lead = 1500;
    for (final b in _pattern.beats) {
      _after(lead + b.atMs, () {
        if (generation != _generation) return;
        ref.read(sfxProvider).drum(b.drum);
        setState(() => _hop[b.drum]++);
      });
    }
    _after(lead + _pattern.durationMs + 700, () {
      if (generation != _generation) return;
      setState(() => _phase = _Phase.play);
      voice.say(['Bate și tu la fel.']);
      _now = Duration.zero;
      if (_ticker.isActive) _ticker.stop();
      _ticker.start();
    });
  }

  void _tap(int drum) {
    if (_phase != _Phase.play || _result != null) return;
    ref.read(sfxProvider).drum(drum);
    if (_taps.isEmpty) {
      _startMs ??= _now.inMilliseconds;
      _firstTap = _now;
    }
    setState(() {
      _taps.add(RhythmBeat((_now - _firstTap).inMilliseconds, drum));
      _hop[drum]++;
    });
    _cancel();
    // Gata când a bătut cât modelul (puțin după), sau după o pauză lungă.
    _after(
      _taps.length >= _pattern.beats.length ? 500 : RhythmGame.step * 2 + 1200,
      _evaluate,
    );
  }

  void _evaluate() {
    if (_phase != _Phase.play) return;
    _ticker.stop();
    final play = RhythmPlay(
      _pattern,
      List.of(_taps),
      startMs: _startMs,
      replays: _replays,
    );
    if (play.correct || _replays >= 1) {
      _plays.add(play);
      setState(() {
        _phase = _Phase.done;
        if (play.correct) {
          _burst++;
          _mood = MascotMood.happy;
          _reaction++;
        }
      });
      if (play.correct) {
        ref.read(sfxProvider).play(Sfx.correct);
        ref.read(voiceProvider).say(['Bravo']);
      }
      _after(1400, () {
        if (_round + 1 < _level.patterns.length) {
          setState(() => _round++);
          _beginRound();
        } else {
          _finish();
        }
      });
    } else {
      // Încă o dată, cu modelul repetat.
      _replays++;
      setState(() {
        _mood = MascotMood.encourage;
        _reaction++;
      });
      _after(600, _listen);
    }
  }

  void _replay() {
    if (_phase != _Phase.play) return;
    _replays++;
    _listen();
  }

  void _finish() {
    final result = RhythmResult(_level, _plays);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.rhythmLevel(result));
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
          .read(rhythmLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _generation++;
    _cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Adultul a ales „Tobe și zgomote” printre imaginile de evitat: jocul tobei nu se arată.
    if (isAvoided(widget.game.emoji, avoidedOf(ref))) return const NothingToShow();
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final result = _result;
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        kind: SceneKind.dusk,
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
      final drums = _level.axes.drums;
      final side = math
          .min(box.maxHeight * 0.62, box.maxWidth / (drums + 1.4))
          .clamp(96.0, 300.0);
      final title = Theme.of(context).textTheme;
      final listening = _phase == _Phase.listen;
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: OutlinedTitle(
                listening ? 'Ascultă' : 'Rândul tău',
                key: const ValueKey('rhythm-phase'),
                style: layout.compact ? title.titleLarge : title.headlineMedium,
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var d = 0; d < drums; d++) ...[
                  if (d > 0) SizedBox(width: side * 0.25),
                  Juice(
                    enabled: motion.movement,
                    popTick: _hop[d],
                    child: Semantics(
                      button: true,
                      label: 'Toba ${d + 1}',
                      child: GestureDetector(
                        key: ValueKey('rhythm-drum-$d'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _tap(d),
                        // Toba mare sună jos, cea mică sus: se deosebesc și ca formă.
                        child: _Drum(
                          side: d == 0 ? side : side * 0.78,
                          tint: d == 1,
                          dim: listening,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Mascot(
                size: layout.compact ? 80 : 140,
                mood: _mood,
                reaction: _reaction,
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 8,
            child: CandyPressable(
              key: const ValueKey('rhythm-replay'),
              color: _phase == _Phase.play
                  ? Tokens.sun
                  : const Color(0xFFE8E2D6),
              lipColor: shade(Tokens.sun, 0.15),
              width: layout.compact ? 56 : 76,
              height: layout.compact ? 56 : 76,
              radius: 40,
              semanticLabel: 'Ascultă din nou',
              onTap: _phase == _Phase.play ? _replay : null,
              child: Icon(
                Icons.hearing_rounded,
                color: Colors.white,
                size: layout.compact ? 30 : 40,
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
  );
}

/// Toba pictată; a doua tobă e mai mică și lavandă (aceeași ilustrație, nuanțată). Cât ascultă copilul,
/// tobele sunt ușor estompate — semn că acum nu e rândul lui.
class _Drum extends StatelessWidget {
  const _Drum({required this.side, required this.tint, required this.dim});

  final double side;
  final bool tint;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    Widget art = StimulusArt('🥁', size: side);
    if (tint) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFFC9B8F0),
          BlendMode.modulate,
        ),
        child: art,
      );
    }
    return AnimatedOpacity(
      opacity: dim ? 0.75 : 1,
      duration: const Duration(milliseconds: 250),
      child: art,
    );
  }
}
