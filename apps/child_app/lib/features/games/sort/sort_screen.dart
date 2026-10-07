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

class SortProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

final sortLevelProvider = NotifierProvider<SortProgress, int>(SortProgress.new);

/// Culoarea fiecărei grupe (cutia și buza ei).
Color _binColor(int i) =>
    const [Tokens.peach, Tokens.mint, Tokens.lavender, Tokens.primary][i % 4];

/// Sortăm (COG3) — prima mecanică `dragDrop`: lucrurile se trag în cutia grupei lor. Pentru
/// copiii cărora tragerea le e grea: atingi lucrul, apoi cutia. Greșeala nu se pedepsește:
/// lucrul se clatină blând și rămâne de pus.
class SortScreen extends ConsumerStatefulWidget {
  const SortScreen({
    super.key,
    this.game = const SortGame(),
    this.seed,
    this.preset,
    this.title,
    this.onComplete,
  });

  final SortGame game;
  final int? seed;

  /// O sortare gata făcută (oprirea unei explorări), în loc de una generată pe nivel.
  final SortLevel? preset;
  final String? title;

  /// Dacă e dat, la final rezultatul se predă (explorarea își arată singură recompensa).
  final void Function(SortResult result)? onComplete;

  @override
  ConsumerState<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends ConsumerState<SortScreen> {
  late SortLevel _level;
  final _placed = <int, String>{}; // lucru → grupă
  final _wrong = <int, int>{}; // lucru → greșeli
  final _firstWrong = <int, String>{};
  final _placements = <SortPlacement>[];
  final _clock = Stopwatch();
  int? _selected;
  int _shake = 0;
  int? _shaking;
  int _burst = 0;
  int _reaction = 0;
  String? _hotBin;
  MascotMood _mood = MascotMood.idle;
  bool _ready = false;
  SortResult? _result;
  String? _sticker;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level =
        widget.preset ??
        widget.game.generate(ref.read(sortLevelProvider), seed: widget.seed);
    _placed.clear();
    _wrong.clear();
    _firstWrong.clear();
    _placements.clear();
    _selected = null;
    _result = null;
    _sticker = null;
    _mood = MascotMood.idle;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _clock
        ..reset()
        ..start();
      ref.read(voiceProvider).say([_level.instruction]);
    });
  }

  void _drop(int item, String binId) {
    if (_placed.containsKey(item) || _result != null) return;
    final it = _level.items[item];
    final sfx = ref.read(sfxProvider);
    if (it.binId == binId) {
      sfx.play(Sfx.correct);
      _placements.add(
        SortPlacement(
          it,
          wrongDrops: _wrong[item] ?? 0,
          firstWrongBin: _firstWrong[item],
          ms: _clock.elapsedMilliseconds,
        ),
      );
      _clock
        ..reset()
        ..start();
      setState(() {
        _placed[item] = binId;
        _selected = null;
        _burst++;
        _reaction++;
        _mood = MascotMood.happy;
      });
      if (_placed.length == _level.items.length) {
        _timer = Timer(const Duration(milliseconds: 800), _finish);
      }
    } else {
      _wrong[item] = (_wrong[item] ?? 0) + 1;
      _firstWrong[item] ??= binId;
      setState(() {
        _shaking = item;
        _shake++;
        _selected = null;
        _reaction++;
        _mood = MascotMood.encourage;
      });
      ref.read(voiceProvider).say(['Mai încearcă']);
    }
  }

  void _finish() {
    if (!mounted) return;
    final result = SortResult(_level, _placements);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.sortLevel(result));
    session.checkpoint();
    if (widget.onComplete case final done?) {
      done(result);
      return;
    }
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) {
      ref
          .read(sortLevelProvider.notifier)
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
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final result = _result;
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: widget.title ?? widget.game.name),
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
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          0,
                          16,
                          layout.compact ? 8 : 18,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: _board(motion, layout)),
                            if (motion.particles)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: StarBurst(trigger: _burst, count: 8),
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

  Widget _board(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final left = _level.items
          .where((i) => !_placed.containsKey(i.index))
          .toList();
      final binH = box.maxHeight * 0.46;
      final itemSide = math.min(
        layout.compact ? 64.0 : 104.0,
        (box.maxHeight - binH) * 0.62,
      );
      return Column(
        children: [
          // Lucrurile de sortat, pe „masă”.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (layout.twoPane)
                  Mascot(size: layout.mascot, mood: _mood, reaction: _reaction),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final it in left)
                          _DragItem(
                            key: ValueKey('sort-item-${it.index}'),
                            item: it,
                            size: itemSide,
                            selected: _selected == it.index,
                            shakeTick: _shaking == it.index ? _shake : 0,
                            motion: motion,
                            onTap: () => setState(
                              () => _selected = _selected == it.index
                                  ? null
                                  : it.index,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: layout.compact ? 6 : 12),
          // Cutiile grupelor.
          SizedBox(
            height: binH,
            child: Row(
              children: [
                for (final (bi, bin) in _level.bins.indexed) ...[
                  if (bi > 0) const SizedBox(width: 12),
                  Expanded(
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (d) {
                        setState(() => _hotBin = bin.id);
                        return true;
                      },
                      onLeave: (_) => setState(() => _hotBin = null),
                      onAcceptWithDetails: (d) {
                        setState(() => _hotBin = null);
                        _drop(d.data, bin.id);
                      },
                      builder: (context, _, _) => _Bin(
                        key: ValueKey('sort-bin-${bin.id}'),
                        bin: bin,
                        color: _binColor(bi),
                        hot: _hotBin == bin.id,
                        placed: [
                          for (final e in _placed.entries)
                            if (e.value == bin.id) _level.items[e.key].emoji,
                        ],
                        compact: layout.compact,
                        onTap: _selected == null
                            ? null
                            : () => _drop(_selected!, bin.id),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Un lucru de sortat: se trage cu degetul (sau se atinge, apoi se atinge cutia).
class _DragItem extends StatelessWidget {
  const _DragItem({
    super.key,
    required this.item,
    required this.size,
    required this.selected,
    required this.shakeTick,
    required this.motion,
    required this.onTap,
  });

  final SortItem item;
  final double size;
  final bool selected;
  final int shakeTick;
  final MotionPolicy motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget art(double s, {bool lifted = false}) => Container(
      width: s,
      height: s,
      padding: EdgeInsets.all(s * 0.1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Tokens.sun : const Color(0xFFEDE3D2),
          width: selected ? 4 : 2,
        ),
        boxShadow: lifted
            ? const [
                BoxShadow(
                  color: Color(0x402F3D3B),
                  blurRadius: 22,
                  offset: Offset(0, 14),
                ),
              ]
            : Tokens.shadow,
      ),
      child: StimulusArt(item.emoji, size: s * 0.8),
    );
    return Semantics(
      button: true,
      label: 'Lucru de pus în grupă',
      child: Draggable<int>(
        data: item.index,
        // Ridicat: puțin mai mare, cu umbră mai lungă (README §15.1, dragDrop).
        feedback: Material(
          type: MaterialType.transparency,
          child: art(size * 1.12, lifted: true),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: art(size)),
        child: GestureDetector(
          onTap: onTap,
          child: Juice(
            enabled: motion.movement,
            shakeTick: shakeTick,
            pulse: selected,
            child: art(size),
          ),
        ),
      ),
    );
  }
}

/// Cutia unei grupe: iconița și numele, apoi lucrurile puse deja în ea.
class _Bin extends StatelessWidget {
  const _Bin({
    super.key,
    required this.bin,
    required this.color,
    required this.hot,
    required this.placed,
    required this.compact,
    required this.onTap,
  });

  final SortBin bin;
  final Color color;
  final bool hot;
  final List<String> placed;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedScale(
      scale: hot ? 1.04 : 1,
      duration: const Duration(milliseconds: 150),
      child: CandyPressable(
        color: tint(color, hot ? 0.02 : 0.1),
        lipColor: shade(color, 0.06),
        radius: 26,
        lip: 8,
        border: hot ? Colors.white : null,
        borderWidth: hot ? 4 : 0,
        semanticLabel: bin.name,
        onTap: onTap,
        padding: EdgeInsets.all(compact ? 6 : 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StimulusArt(bin.emoji, size: compact ? 28 : 44),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    bin.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compact ? text.titleMedium : text.titleLarge)!
                        .copyWith(color: shade(color, 0.35)),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final s = math.min(
                      c.maxHeight * 0.8,
                      compact ? 34.0 : 52.0,
                    );
                    // Goală: umbra iconiței grupei, ca indiciu „aici intră fructele”.
                    if (placed.isEmpty) {
                      return Center(
                        child: Opacity(
                          opacity: 0.22,
                          child: StimulusArt(
                            bin.emoji,
                            size: math.min(c.maxHeight * 0.75, 96),
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final e in placed) StimulusArt(e, size: s),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
