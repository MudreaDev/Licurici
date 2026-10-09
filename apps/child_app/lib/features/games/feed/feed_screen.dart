import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final feedLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('hraneste-pestii'));

/// Hrănește peștii (MOT4): mâncarea stă pe o frunză în colț; copilul o trage la peștele
/// flămând (cel cu balonul deasupra). Peștii înoată (timpul vine dintr-un `Ticker`, deci și
/// testele îl pot simula). Mâncarea scăpată în apă se întoarce pe frunză; peștele sătul doar
/// dă din cap.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.game = const FeedGame(), this.seed});

  final FeedGame game;
  final int? seed;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late FeedLevel _level;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  late final Ticker _ticker = createTicker(_tick);
  final _feeds = <FeedAttempt>[];
  Duration _elapsed = Duration.zero;
  Duration _roundStart = Duration.zero;
  int _round = 0;
  int _misses = 0;
  int _wrongFish = 0;
  Offset? _drag;
  bool _fed = false;
  final _shake = <int, int>{};
  int _burst = 0;
  bool _ready = false;
  FeedResult? _result;
  String? _sticker;
  Timer? _timer;

  FeedRound get _r => _level.rounds[_round];
  double get _t => (_elapsed - _roundStart).inMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    // Doar când peștii chiar se mișcă (altfel nu redesenăm degeaba).
    if (_level.axes.speed > 0 && !_fed && mounted) setState(() {});
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(feedLevelProvider),
      seed: widget.seed,
    );
    _feeds.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      if (!_ticker.isActive) _ticker.start();
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Du mâncarea la peștele flămând.']);
      _beginRound();
    });
  }

  void _beginRound() {
    _roundStart = _elapsed;
    _misses = 0;
    _wrongFish = 0;
    _fed = false;
    _drag = null;
    _shake.clear();
  }

  void _drop(Size field, double fishSide) {
    final at = _drag;
    setState(() => _drag = null);
    if (at == null || _fed) return;
    final radius = fishSide / 2;
    // Cel mai apropiat pește, în momentul lăsării.
    var best = -1;
    var bestDist = double.infinity;
    for (final (i, f) in _r.fish.indexed) {
      final p = f.at(_t, _level.axes.speed);
      final d = (Offset(p.x * field.width, p.y * field.height) - at).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    // Generos: toată silueta peștelui + puțin (copiii mici, ținte în mișcare).
    if (bestDist > radius * 1.15) {
      _misses++;
      return;
    }
    if (best != _r.hungry) {
      _wrongFish++;
      setState(() => _shake[best] = (_shake[best] ?? 0) + 1);
      return;
    }
    _feeds.add(
      FeedAttempt(
        _r,
        precision: (bestDist / radius).clamp(0.0, 1.0),
        misses: _misses,
        wrongFish: _wrongFish,
        ms: (_t * 1000).round(),
      ),
    );
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Mmm, mulțumesc!']);
    setState(() {
      _fed = true;
      _burst++;
    });
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_round + 1 < _total) {
        setState(() {
          _round++;
          _beginRound();
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _ticker.stop();
    final result = FeedResult(_level, _feeds);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.feedLevel(result));
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
          .read(feedLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
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
        kind: SceneKind.water,
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
                    : _pond(motion, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pond(MotionPolicy motion, AppLayout layout) => LayoutBuilder(
    builder: (context, box) {
      final field = Size(box.maxWidth, box.maxHeight);
      final fishSide = math.max(64.0, _level.axes.size * field.height);
      final food = math.max(56.0, fishSide * 0.55);
      // Frunza cu mâncare, în colțul din stânga-jos.
      final home = Offset(food * 0.9, field.height - food * 0.9);
      final speed = motion.movement ? _level.axes.speed : 0.0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, f) in _r.fish.indexed)
            Builder(
              builder: (context) {
                final p = f.at(_t, speed);
                final hungry = i == _r.hungry;
                return Positioned(
                  left: p.x * field.width - fishSide / 2,
                  top: p.y * field.height - fishSide / 2,
                  width: fishSide,
                  height: fishSide,
                  child: IgnorePointer(
                    child: Juice(
                      enabled: motion.movement,
                      shakeTick: _shake[i] ?? 0,
                      popTick: hungry && _fed ? 1 : 0,
                      child: Stack(
                        key: ValueKey('feed-fish-$i'),
                        clipBehavior: Clip.none,
                        children: [
                          // Peștele flămând strălucește (auriu) — indiciul principal.
                          if (hungry && !_fed)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Tokens.sun.withValues(alpha: 0.7),
                                      Tokens.sun.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          StimulusArt(
                            f.art,
                            size: fishSide,
                            flip: f.heading(_t, speed) < 0,
                          ),
                          // Balonul peștelui flămând: o firimitură deasupra.
                          if (hungry && !_fed)
                            Positioned(
                              right: -fishSide * 0.22,
                              top: -fishSide * 0.22,
                              child: _HungryBubble(
                                key: const ValueKey('feed-hungry'),
                                size: math.max(34, fishSide * 0.45),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          // Frunza (locul mâncării).
          Positioned(
            left: home.dx - food * 0.75,
            top: home.dy - food * 0.5,
            child: IgnorePointer(
              child: Container(
                width: food * 1.5,
                height: food,
                decoration: BoxDecoration(
                  color: const Color(0xCC7FC0A3),
                  borderRadius: BorderRadius.circular(food),
                ),
              ),
            ),
          ),
          if (!_fed)
            Positioned(
              left: (_drag ?? home).dx - food / 2,
              top: (_drag ?? home).dy - food / 2,
              width: food,
              height: food,
              child: GestureDetector(
                key: const ValueKey('feed-food'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(
                  () => _drag =
                      home + d.localPosition - Offset(food / 2, food / 2),
                ),
                onPanUpdate: (d) =>
                    setState(() => _drag = (_drag ?? home) + d.delta),
                onPanEnd: (_) => _drop(field, fishSide),
                onPanCancel: () => setState(() => _drag = null),
                child: AnimatedScale(
                  scale: _drag == null ? 1 : 1.15,
                  duration: motion.d(120),
                  child: StimulusArt(feedFood, size: food),
                ),
              ),
            ),
          if (motion.particles)
            Builder(
              builder: (context) {
                final p = _r.fish[_r.hungry].at(_t, speed);
                return Positioned(
                  left: p.x * field.width - fishSide,
                  top: p.y * field.height - fishSide,
                  width: fishSide * 2,
                  height: fishSide * 2,
                  child: IgnorePointer(
                    child: StarBurst(trigger: _burst, count: 10),
                  ),
                );
              },
            ),
          Positioned(
            right: 12,
            top: 4,
            child: Row(
              children: [
                for (var i = 0; i < _total; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _round || (i == _round && _fed)
                          ? Tokens.sun
                          : Colors.white.withValues(alpha: 0.6),
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

/// Balonul de gând al peștelui flămând, cu o firimitură înăuntru.
class _HungryBubble extends StatelessWidget {
  const _HungryBubble({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      shape: BoxShape.circle,
      border: Border.all(color: Tokens.sun, width: 3),
    ),
    child: StimulusArt(feedFood, size: size * 0.6),
  );
}
