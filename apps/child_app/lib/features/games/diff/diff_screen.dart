import 'dart:async';
import 'dart:math' as math;

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

final diffLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('diferente'),
);

/// Găsește diferențele (POT8): două „poze” una lângă alta; copilul atinge în a doua locurile
/// diferite. Fiecare diferență găsită se încercuiește în ambele poze. Atingerea pe un loc la
/// fel nu are niciun semn (doar se numără).
class DiffScreen extends ConsumerStatefulWidget {
  const DiffScreen({super.key, this.game = const SpotDiffGame(), this.seed});

  final SpotDiffGame game;
  final int? seed;

  @override
  ConsumerState<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends ConsumerState<DiffScreen> {
  late DiffLevel _level;
  bool _blocked = false;
  final _solves = <DiffSolve>[];
  final _found = <int>{};
  final _clock = Stopwatch();
  int _scene = 0;
  int _wrong = 0;
  int _burst = 0;
  bool _ready = false;
  DiffResult? _result;
  String? _sticker;
  Timer? _timer;

  DiffScene get _s => _level.scenes[_scene];

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
      (seed) => widget.game.generate(ref.read(diffLevelProvider), seed: seed, avoid: avoid),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _solves.clear();
    _scene = 0;
    _found.clear();
    _wrong = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Ce e altfel în poza a doua?']);
      _clock
        ..reset()
        ..start();
    });
  }

  void _tap(int cell) {
    if (_result != null || _found.length == _s.differences.length) return;
    if (_s.differences.containsKey(cell) && !_found.contains(cell)) {
      ref.read(sfxProvider).play(Sfx.correct);
      setState(() {
        _found.add(cell);
        _burst++;
      });
      if (_found.length == _s.differences.length) _complete();
    } else if (!_found.contains(cell)) {
      _wrong++;
    }
  }

  void _complete() {
    _solves.add(
      DiffSolve(_s, wrongTaps: _wrong, ms: _clock.elapsedMilliseconds),
    );
    ref.read(voiceProvider).say(['Ai găsit toate diferențele!']);
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_scene + 1 < _level.scenes.length) {
        setState(() {
          _scene++;
          _found.clear();
          _wrong = 0;
        });
        _clock
          ..reset()
          ..start();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = DiffResult(_level, _solves);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.diffLevel(result));
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
          .read(diffLevelProvider.notifier)
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
    if (_blocked) return const NothingToShow();
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

  Widget _board(MotionPolicy motion, AppLayout layout) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Column(
      children: [
        // Câte am găsit: buline care se umplu.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _s.differences.length; i++)
              Container(
                width: layout.compact ? 16 : 22,
                height: layout.compact ? 16 : 22,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _found.length ? Tokens.good : Colors.white70,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _panel(_s.left, interactive: false)),
              const SizedBox(width: 14),
              Expanded(
                child: _panel(_s.right, interactive: true, motion: motion),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _panel(
    Map<int, ObjectWord> items, {
    required bool interactive,
    MotionPolicy? motion,
  }) => LayoutBuilder(
    builder: (context, box) {
      final cw = box.maxWidth / _s.cols, ch = box.maxHeight / _s.rows;
      final side = (math.min(cw, ch) * 0.72).clamp(28.0, 130.0);
      return Container(
        key: ValueKey(interactive ? 'diff-right' : 'diff-left'),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFBF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
          boxShadow: Tokens.shadow,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var cell = 0; cell < _s.cols * _s.rows; cell++)
              Positioned(
                left: (cell % _s.cols) * cw,
                top: (cell ~/ _s.cols) * ch,
                width: cw,
                height: ch,
                child: Semantics(
                  button: true,
                  label: 'Căsuța ${cell + 1}',
                  child: GestureDetector(
                    key: interactive ? ValueKey('diff-cell-$cell') : null,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: interactive ? (_) => _tap(cell) : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (items[cell] case final o?)
                          StimulusArt(
                            o.emoji,
                            size: side,
                            semanticLabel: o.word,
                          ),
                        if (_found.contains(cell))
                          Container(
                            width: side * 1.25,
                            height: side * 1.25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Tokens.good, width: 4),
                            ),
                          ),
                        if (interactive && motion != null && motion.particles)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _found.contains(cell)
                                  ? StarBurst(trigger: _burst, count: 8)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
