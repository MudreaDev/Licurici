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

final searchLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('cauta'),
);

/// Caută (ATN2): obiectele sunt împrăștiate pe pajiște; în colț se vede ce căutăm. Atingerea
/// altui obiect doar îl clatină; ținta găsită sare, cu steluțe. După 8 s fără găsire, ținta
/// începe să pulseze ușor (ajutor, P3).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.game = const SearchGame(), this.seed});

  final SearchGame game;
  final int? seed;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late SearchLevel _level;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  final _finds = <SearchFind>[];
  final _clock = Stopwatch();
  final _shake = <int, int>{};
  int _round = 0;
  int _wrong = 0;
  String? _firstWrong;
  bool _found = false;
  bool _hint = false;
  int _burst = 0;
  bool _ready = false;
  SearchResult? _result;
  String? _sticker;
  Timer? _timer;
  Timer? _hintTimer;

  SearchRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _hintTimer?.cancel();
    _level = widget.game.generate(
      ref.read(searchLevelProvider),
      seed: widget.seed,
    );
    _finds.clear();
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
    _wrong = 0;
    _firstWrong = null;
    _found = false;
    _hint = false;
    _shake.clear();
    ref.read(voiceProvider).say([_r.says]);
    _clock
      ..reset()
      ..start();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_found) setState(() => _hint = true);
    });
  }

  void _tap(SearchItem item) {
    if (_found || _result != null) return;
    if (item.object.emoji == _r.target.emoji) {
      _hintTimer?.cancel();
      final ms = _clock.elapsedMilliseconds;
      _finds.add(
        SearchFind(_r, ms: ms, wrongTaps: _wrong, firstWrong: _firstWrong),
      );
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say(['Bravo']);
      setState(() {
        _found = true;
        _burst++;
      });
      _timer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        if (_round + 1 < _total) {
          setState(() => _round++);
          _beginRound();
        } else {
          _finish();
        }
      });
    } else {
      _firstWrong ??= item.object.word;
      ref.read(voiceProvider).say([item.object.word]);
      setState(() {
        _wrong++;
        _shake[item.index] = (_shake[item.index] ?? 0) + 1;
      });
    }
  }

  void _finish() {
    final result = SearchResult(_level, _finds);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.searchLevel(result));
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
          .read(searchLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
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
                    : AnimatedSwitcher(
                        duration: motion.d(300),
                        child: KeyedSubtree(
                          key: ValueKey('search-round-$_round'),
                          child: _field(motion, layout),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      // Ținta, în stânga (cât un „bilețel”); obiectele, în restul zonei.
      final panel = math.min(
        box.maxHeight * 0.42,
        layout.compact ? 96.0 : 170.0,
      );
      final w = box.maxWidth - panel - 24, h = box.maxHeight - 8;
      final cell = math.min(w / _r.cols, h / _r.rows);
      final side = (cell * 0.82).clamp(36.0, 150.0);
      return Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12),
            child: _TargetCard(object: _r.target, side: panel),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final it in _r.items)
                  Positioned(
                    // Abaterea din celulă nu scoate obiectul din ecran.
                    left: (it.x * w - side / 2).clamp(0.0, w - side),
                    top: (it.y * h - side / 2).clamp(0.0, h - side),
                    width: side,
                    height: side,
                    child: _SearchObject(
                      key: ValueKey('search-item-${it.index}'),
                      item: it,
                      side: side,
                      found: _found && it.object.emoji == _r.target.emoji,
                      hint: _hint && it.object.emoji == _r.target.emoji,
                      shakeTick: _shake[it.index] ?? 0,
                      motion: motion,
                      onTap: () => _tap(it),
                    ),
                  ),
                if (motion.particles)
                  for (final it in _r.items)
                    if (it.object.emoji == _r.target.emoji)
                      Positioned(
                        left: it.x * w - side,
                        top: it.y * h - side,
                        width: side * 2,
                        height: side * 2,
                        child: IgnorePointer(
                          child: StarBurst(trigger: _burst, count: 10),
                        ),
                      ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.object, required this.side});

  final ObjectWord object;
  final double side;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('search-target'),
    width: side,
    padding: EdgeInsets.all(side * 0.08),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFBF4),
      borderRadius: BorderRadius.circular(Tokens.radius),
      border: Border.all(color: Tokens.sun, width: 4),
      boxShadow: Tokens.shadow,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_rounded,
          size: side * 0.2,
          color: shade(Tokens.sun, 0.3),
        ),
        StimulusArt(object.emoji, size: side * 0.62),
      ],
    ),
  );
}

class _SearchObject extends StatelessWidget {
  const _SearchObject({
    super.key,
    required this.item,
    required this.side,
    required this.found,
    required this.hint,
    required this.shakeTick,
    required this.motion,
    required this.onTap,
  });

  final SearchItem item;
  final double side;
  final bool found;
  final bool hint;
  final int shakeTick;
  final MotionPolicy motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: item.object.word,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: Juice(
        enabled: motion.movement,
        shakeTick: shakeTick,
        popTick: found ? 1 : 0,
        pulse: hint,
        child: AnimatedScale(
          scale: found ? 1.3 : 1,
          duration: motion.d(300),
          curve: Curves.easeOutBack,
          child: Transform.rotate(
            angle: motion.movement && !found ? item.tilt : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: found ? Tokens.sun.withValues(alpha: 0.35) : null,
              ),
              child: StimulusArt(
                item.object.emoji,
                size: side,
                semanticLabel: item.object.word,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
