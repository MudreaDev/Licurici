import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/celebration.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/nothing_to_show.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../memory/memory_screen.dart' show MemoryCard;

final soundMemoryLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('memorie-sunete'));

/// Emblema cărților-sunet.
const _soundFace = '🔊';

/// Memorie cu sunete (COM1): o carte-sunet întoarsă îl face pe Licurici să spună sunetul
/// („miau”); perechea ei e cine îl face. La nivelurile 1–3 animalele stau la vedere (copilul
/// doar asociază), apoi toate cărțile sunt întoarse. O pereche greșită se întoarce după o clipă.
class SoundMemoryScreen extends ConsumerStatefulWidget {
  const SoundMemoryScreen({super.key, this.game = const SoundMemoryGame(), this.seed});

  final SoundMemoryGame game;
  final int? seed;

  @override
  ConsumerState<SoundMemoryScreen> createState() => _SoundMemoryScreenState();
}

class _SoundMemoryScreenState extends ConsumerState<SoundMemoryScreen> {
  late SoundMemoryLevel _level;
  bool _blocked = false;
  final _up = <int>{};
  final _matched = <int>{};
  final _moves = <SoundMove>[];
  final _moveClock = Stopwatch();
  int? _first;
  bool _locked = false;
  SoundMemoryResult? _result;
  String? _sticker;
  int _burst = 0;
  MascotMood _mood = MascotMood.idle;
  Timer? _timer;

  bool _faceUp(int i) => _up.contains(i) || _matched.contains(i) || (_level.axes.sourcesUp && !_level.cards[i].isSound);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(soundMemoryLevelProvider), seed: widget.seed, avoid: avoidedOf(ref));
    _blocked = _level.cards.length < _level.pairs * 2;
    _up.clear();
    _matched.clear();
    _moves.clear();
    _first = null;
    _locked = false;
    _result = null;
    _sticker = null;
    _mood = MascotMood.idle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say([SoundMemoryGame.instruction]);
    });
  }

  void _tap(int i) {
    if (_locked || _result != null || _matched.contains(i)) return;
    final card = _level.cards[i];
    // Cartea-sunet deja întoarsă: încă o atingere repetă sunetul.
    if (i == _first) {
      if (card.isSound) ref.read(voiceProvider).say([card.source.sound]);
      return;
    }
    if (_up.contains(i)) return;
    ref.read(sfxProvider).play(Sfx.tap);
    if (card.isSound) ref.read(voiceProvider).say([card.source.sound]);
    final first = _first;
    if (first == null) {
      _moveClock
        ..reset()
        ..start();
      setState(() {
        _up.add(i);
        _first = i;
      });
      return;
    }
    _moves.add(SoundMove(first, i, ms: _moveClock.elapsedMilliseconds));
    final match = _level.cards[first].matches(card);
    setState(() {
      _up.add(i);
      _first = null;
      if (match) {
        _matched.addAll([first, i]);
        _burst++;
        _mood = MascotMood.happy;
      } else {
        _locked = true;
        _mood = MascotMood.encourage;
      }
    });
    if (match) {
      ref.read(sfxProvider).play(Sfx.correct);
      // După sunetul cărții, Licurici leagă sunetul de cine îl face.
      ref.read(voiceProvider).say([SoundMemoryGame.says(card.source)]);
      if (_matched.length == _level.cards.length) {
        _timer = Timer(const Duration(milliseconds: 2200), _finish);
      }
    } else {
      _timer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _up.removeAll([first, i]);
          _locked = false;
          _mood = MascotMood.idle;
        });
      });
    }
  }

  void _finish() {
    if (!mounted) return;
    final result = SoundMemoryResult(_level, _moves);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.soundMemoryLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(soundMemoryLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
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
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
                          FinishAction('Mai departe', Icons.arrow_forward_rounded, Tokens.good, () => _again(next: true)),
                        ],
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(12, 4, 16, layout.compact ? 8 : 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (layout.twoPane) Mascot(size: layout.mascot, mood: _mood, reaction: _burst),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _grid(motion)),
                                  if (motion.particles)
                                    Positioned.fill(
                                      child: IgnorePointer(child: StarBurst(trigger: _burst, count: 8)),
                                    ),
                                ],
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

  Widget _grid(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final n = _level.cards.length;
      final cols = _level.axes.columns;
      final rows = (n / cols).ceil();
      const gap = 12.0;
      const ratio = 0.78;
      final h = math.min((box.maxHeight - gap * (rows - 1)) / rows, ((box.maxWidth - gap * (cols - 1)) / cols) / ratio);
      final w = h * ratio;
      return Center(
        child: SizedBox(
          width: w * cols + gap * (cols - 1),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, c) in _level.cards.indexed)
                MemoryCard(
                  key: ValueKey('sound-card-$i'),
                  face: c.isSound ? _soundFace : c.source.emoji,
                  sound: c.isSound,
                  up: _faceUp(i),
                  matched: _matched.contains(i),
                  selected: _first == i && !c.isSound,
                  tappableUp: _level.axes.sourcesUp && !c.isSound,
                  label: c.isSound ? c.source.sound : c.source.who,
                  width: w,
                  height: h,
                  motion: motion,
                  onTap: () => _tap(i),
                ),
            ],
          ),
        ),
      );
    },
  );
}
