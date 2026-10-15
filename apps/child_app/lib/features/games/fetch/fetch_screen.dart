import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/nothing_to_show.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final fetchLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('adu-mi'));

/// Adu-mi (LRC1–2): Licurici cere un obiect („Adu-mi mingea”); copilul îl trage în coș sau doar
/// îl atinge (pentru copiii cu dificultăți motorii). Un obiect greșit se clatină și rămâne pe masă;
/// după două greșeli, obiectul cerut pulsează (ajutor). „Mai spune” repetă cererea oricând.
class FetchScreen extends ConsumerStatefulWidget {
  const FetchScreen({super.key, this.game = const FetchGame(), this.seed});

  final FetchGame game;
  final int? seed;

  @override
  ConsumerState<FetchScreen> createState() => _FetchScreenState();
}

class _FetchScreenState extends ConsumerState<FetchScreen> {
  late FetchLevel _level;
  final _answers = <FetchAnswer>[];
  final _clock = Stopwatch();
  final _shake = <String, int>{};
  final _inBasket = <ObjectWord>{};
  int _index = 0;
  int _wrong = 0;
  ObjectWord? _firstWrong;
  int _burst = 0;
  MascotMood _mood = MascotMood.idle;
  FetchResult? _result;
  String? _sticker;
  Timer? _timer;
  bool _blocked = false;

  FetchRound get _r => _level.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(fetchLevelProvider), seed: widget.seed, avoid: avoidedOf(ref));
    _blocked = _level.rounds.any((r) => r.table.length < _level.axes.objects);
    _answers.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _beginRound();
  }

  void _beginRound() {
    _inBasket.clear();
    _shake.clear();
    _wrong = 0;
    _firstWrong = null;
    _mood = MascotMood.idle;
    _clock
      ..reset()
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  void _ask() {
    if (mounted && _result == null) ref.read(voiceProvider).say(_r.speak);
  }

  void _bring(ObjectWord o) {
    if (_result != null || _inBasket.contains(o) || _inBasket.length == _r.wanted.length) return;
    if (!_r.wanted.contains(o)) {
      _wrong++;
      _firstWrong ??= o;
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _shake[o.word] = (_shake[o.word] ?? 0) + 1;
        _mood = MascotMood.encourage;
      });
      ref.read(voiceProvider).say([ref.read(cheerProvider).retry()]);
      return;
    }
    ref.read(sfxProvider).play(Sfx.bubble);
    setState(() => _inBasket.add(o));
    if (_inBasket.length < _r.wanted.length) return;
    _answers.add(FetchAnswer(_r, wrong: _wrong, ms: _clock.elapsedMilliseconds, firstWrong: _firstWrong));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Mulțumesc', ref.read(cheerProvider).correct(firstTry: _wrong == 0)]);
    setState(() {
      _burst++;
      _mood = MascotMood.happy;
    });
    _timer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
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
    final result = FetchResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.fetchLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(fetchLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
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
                        key: const ValueKey('fetch-repeat'),
                        icon: Icons.record_voice_over_rounded,
                        color: Tokens.lavender,
                        label: 'Mai spune',
                        onTap: _ask,
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
      final left = [for (final o in _r.table) if (!_inBasket.contains(o)) o];
      final n = _r.table.length;
      final cols = n <= 3 ? n : (n <= 4 ? 2 : 3);
      final rows = (n / cols).ceil();
      final tableW = box.maxWidth * 0.62;
      final size = math.min(140.0, math.min((tableW - 40) / cols - 24, (box.maxHeight - 40) / rows - 24));
      final hint = _wrong >= 2;
      return Row(
        children: [
          // Masa: obiectele (se trag sau se ating).
          SizedBox(
            width: tableW,
            child: Center(
              child: CandyPanel(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    for (final o in left)
                      Juice(
                        key: ValueKey('fetch-${o.word}'),
                        enabled: motion.movement,
                        shakeTick: _shake[o.word] ?? 0,
                        pulse: hint && _r.wanted.contains(o),
                        child: Draggable<ObjectWord>(
                          data: o,
                          feedback: Material(type: MaterialType.transparency, child: StimulusArt(o.emoji, size: size)),
                          childWhenDragging: Opacity(opacity: 0.3, child: StimulusArt(o.emoji, size: size)),
                          child: Semantics(
                            button: true,
                            label: o.word,
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _bring(o),
                              child: StimulusArt(o.emoji, size: size),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Licurici cu coșul: aici se aduc obiectele.
          Expanded(
            child: DragTarget<ObjectWord>(
              onAcceptWithDetails: (d) => _bring(d.data),
              builder: (context, candidates, _) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascot(size: math.min(150, box.maxHeight * 0.36), mood: _mood, reaction: _burst),
                  const SizedBox(height: 8),
                  Juice(
                    enabled: motion.feedback,
                    popTick: _burst,
                    child: AnimatedContainer(
                      key: const ValueKey('fetch-basket'),
                      duration: motion.d(150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty ? const Color(0xFFFFF3C4) : const Color(0xCCFFF8EC),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFD9B26A), width: 4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StimulusArt('🧺', size: math.min(110, box.maxHeight * 0.26)),
                          for (final o in _inBasket) StimulusArt(o.emoji, size: math.min(64, box.maxHeight * 0.15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
