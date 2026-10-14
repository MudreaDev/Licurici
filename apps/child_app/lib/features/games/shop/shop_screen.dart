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
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../../../shared/cheer.dart';

final shopLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('la-magazin'),
);

/// La magazin (AUT5): lista cu poze în stânga (bifă la ce s-a cumpărat), rafturile în dreapta,
/// coșul jos. Atingi un produs de pe listă → intră în coș. Un produs care nu e pe listă doar se
/// clatină („Asta nu e pe listă.”) și se numără.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.game = const ShopGame(), this.seed});

  final ShopGame game;
  final int? seed;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  late ShopLevel _level;
  bool _blocked = false;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  final _trips = <ShopTrip>[];
  final _bought = <String>{};
  final _shake = <String, int>{};
  final _clock = Stopwatch();
  int _round = 0;
  int _extra = 0;
  int _burst = 0;
  bool _ready = false;
  ShopResult? _result;
  String? _sticker;
  Timer? _timer;

  ShopRound get _r => _level.rounds[_round];

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
      (seed) => widget.game.generate(ref.read(shopLevelProvider), seed: seed, avoid: avoid),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _trips.clear();
    _round = 0;
    _bought.clear();
    _extra = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Cumpără ce e pe listă.']);
      _clock
        ..reset()
        ..start();
    });
  }

  void _pick(ObjectWord o) {
    if (_result != null || _bought.length == _r.list.length) return;
    if (_r.list.contains(o) && !_bought.contains(o.emoji)) {
      ref.read(sfxProvider).play(Sfx.tap);
      ref.read(voiceProvider).say([o.word]);
      setState(() {
        _bought.add(o.emoji);
        _burst++;
      });
      if (_bought.length == _r.list.length) _complete();
    } else if (!_bought.contains(o.emoji)) {
      ref.read(voiceProvider).say(['Asta nu e pe listă.']);
      setState(() {
        _extra++;
        _shake[o.emoji] = (_shake[o.emoji] ?? 0) + 1;
      });
    }
  }

  void _complete() {
    _trips.add(ShopTrip(_r, extra: _extra, ms: _clock.elapsedMilliseconds));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Ai cumpărat tot!']);
    _timer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      if (_round + 1 < _total) {
        setState(() {
          _round++;
          _bought.clear();
          _shake.clear();
          _extra = 0;
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
    final result = ShopResult(_level, _trips);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.shopLevel(result));
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
          .read(shopLevelProvider.notifier)
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

  Widget _board(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final listW = layout.compact ? 88.0 : 150.0;
      final item = math
          .min((box.maxHeight - 40) / _r.list.length - 10, listW - 30)
          .clamp(34.0, 100.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lista cu poze (ca un bilețel).
            Container(
              key: const ValueKey('shop-list'),
              width: listW,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
                boxShadow: Tokens.shadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final o in _r.list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedOpacity(
                            opacity: _bought.contains(o.emoji) ? 0.4 : 1,
                            duration: motion.d(250),
                            child: StimulusArt(o.emoji, size: item),
                          ),
                          if (_bought.contains(o.emoji))
                            Positioned(
                              right: -6,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Tokens.good,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _shelves(motion, layout)),
          ],
        ),
      );
    },
  );

  Widget _shelves(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final rows = _r.shelf.length <= 8 ? 2 : 3;
      final cols = (_r.shelf.length / rows).ceil();
      final basketH = layout.compact ? 56.0 : 90.0;
      final rowH = (box.maxHeight - basketH - 8) / rows;
      final colW = box.maxWidth / cols;
      final side = (math.min(rowH, colW) * 0.72).clamp(32.0, 120.0);
      return Stack(
        children: [
          for (var r = 0; r < rows; r++)
            // Raftul: o scândură sub fiecare rând.
            Positioned(
              left: 0,
              right: 0,
              top: (r + 1) * rowH - 10,
              height: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFC8935F),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: Tokens.shadow,
                ),
              ),
            ),
          for (final (i, o) in _r.shelf.indexed)
            if (!_bought.contains(o.emoji))
              Positioned(
                left: (i % cols) * colW + (colW - side) / 2,
                top: (i ~/ cols) * rowH + rowH - 10 - side,
                width: side,
                height: side,
                child: Juice(
                  enabled: motion.movement,
                  shakeTick: _shake[o.emoji] ?? 0,
                  child: Semantics(
                    button: true,
                    label: o.word,
                    child: GestureDetector(
                      key: ValueKey('shop-item-${o.emoji}'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _pick(o),
                      child: StimulusArt(
                        o.emoji,
                        size: side,
                        semanticLabel: o.word,
                      ),
                    ),
                  ),
                ),
              ),
          // Coșul, cu ce s-a cumpărat.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: basketH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Juice(
                  enabled: motion.movement,
                  popTick: _burst,
                  child: StimulusArt('🧺', size: basketH),
                ),
                const SizedBox(width: 8),
                for (final e in _bought)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: StimulusArt(e, size: basketH * 0.55),
                  ),
              ],
            ),
          ),
          if (motion.particles)
            Positioned.fill(
              child: IgnorePointer(child: StarBurst(trigger: _burst, count: 8)),
            ),
        ],
      );
    },
  );
}
