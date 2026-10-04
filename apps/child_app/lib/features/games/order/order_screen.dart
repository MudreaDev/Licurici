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

class OrderProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

final orderLevelProvider = NotifierProvider.family<OrderProgress, int, String>(
  (_) => OrderProgress(),
);

/// „Pune în ordine” (Pașii rutinei, Ce urmează?): sus, locurile numerotate; jos, pozele
/// amestecate. Copilul atinge poza care urmează și ea „zboară” la locul ei, cu propoziția ei
/// rostită. Greșeala doar clatină poza; după două greșeli la același loc, poza bună pulsează.
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key, required this.game, this.seed});

  final OrderGame game;
  final int? seed;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  late OrderLevel _level;
  final _attempts = <OrderAttempt>[];
  final _clock = Stopwatch();
  int _round = 0;

  /// Câți pași sunt deja puși (următorul de pus = indexul acesta).
  int _placed = 0;
  int _wrongTaps = 0;
  int _wrongHere = 0;
  String? _firstWrong, _expected;
  bool _hinted = false;
  int? _shaking;
  int _shake = 0;
  int _burst = 0;
  bool _ready = false;
  bool _roundDone = false;
  OrderResult? _result;
  String? _sticker;
  Timer? _timer;

  OrderRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(orderLevelProvider(widget.game.id)),
      seed: widget.seed,
    );
    _attempts.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    _resetRound();
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say([_level.instruction, _r.story.title]);
      _clock
        ..reset()
        ..start();
    });
  }

  void _resetRound() {
    _placed = 0;
    _wrongTaps = 0;
    _wrongHere = 0;
    _firstWrong = _expected = null;
    _hinted = false;
    _roundDone = false;
  }

  void _tap(int stepIndex) {
    if (_roundDone || _result != null || stepIndex < _placed) return;
    final voice = ref.read(voiceProvider);
    if (stepIndex == _placed) {
      ref.read(sfxProvider).play(Sfx.correct);
      voice.say([_r.steps[stepIndex].caption]);
      setState(() {
        _placed++;
        _wrongHere = 0;
        _burst++;
      });
      if (_placed == _r.steps.length) _completeRound();
    } else {
      _firstWrong ??= _r.steps[stepIndex].caption;
      _expected ??= _r.steps[_placed].caption;
      voice.say(['Mai încearcă']);
      setState(() {
        _wrongTaps++;
        _wrongHere++;
        if (_wrongHere >= 2) _hinted = true;
        _shaking = stepIndex;
        _shake++;
      });
    }
  }

  void _completeRound() {
    _roundDone = true;
    _attempts.add(
      OrderAttempt(
        _r,
        wrongTaps: _wrongTaps,
        firstWrong: _firstWrong,
        expected: _expected,
        hinted: _hinted,
        ms: _clock.elapsedMilliseconds,
      ),
    );
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_round + 1 < _level.rounds.length) {
        setState(() {
          _round++;
          _resetRound();
        });
        ref.read(voiceProvider).say([_r.story.title]);
        _clock
          ..reset()
          ..start();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = OrderResult(_level, _attempts);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.orderLevel(result));
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
          .read(orderLevelProvider(widget.game.id).notifier)
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
                        duration: motion.d(350),
                        child: KeyedSubtree(
                          key: ValueKey('order-round-$_round'),
                          child: _board(motion, layout),
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
      final n = _r.steps.length;
      const gap = 14.0;
      final arrow = layout.compact ? 18.0 : 28.0;
      // Locurile (sus) și pozele (jos) au aceeași mărime; încap pe lățime și pe jumătate din înălțime.
      final byWidth = (box.maxWidth - 32 - (n - 1) * (gap + arrow)) / n;
      final byHeight = (box.maxHeight - 60) / 2 - (layout.compact ? 34 : 48);
      final side = math.min(byWidth, byHeight).clamp(64.0, 200.0);
      final title = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          children: [
            OutlinedTitle(
              _r.story.title,
              style: layout.compact ? title.titleLarge : title.headlineMedium,
            ),
            const Spacer(),
            // Locurile, numerotate, cu săgeți între ele.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.only(top: side / 2 - arrow / 2),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: arrow,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x55000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  if (i > 0) const SizedBox(width: gap / 2),
                  _Slot(
                    key: ValueKey('order-slot-$i'),
                    number: i + 1,
                    side: side,
                    step: i < _placed ? _r.steps[i] : null,
                    next: i == _placed && !_roundDone,
                    compact: layout.compact,
                    burst: i == _placed - 1 ? _burst : 0,
                    motion: motion,
                  ),
                  if (i < n - 1) const SizedBox(width: gap / 2),
                ],
              ],
            ),
            const Spacer(),
            // Pozele încă nepuse, în ordinea amestecată.
            SizedBox(
              height: side + 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final i in _r.shuffled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: gap / 2),
                      child: AnimatedOpacity(
                        duration: motion.d(250),
                        opacity: i < _placed ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: i < _placed,
                          child: Juice(
                            enabled: motion.movement,
                            shakeTick: _shaking == i ? _shake : 0,
                            pulse: _hinted && i == _placed && !_roundDone,
                            child: CandyPressable(
                              key: ValueKey('order-card-$i'),
                              color: const Color(0xFFFFFDF8),
                              lipColor: const Color(0xFFE3D9C6),
                              border: _hinted && i == _placed
                                  ? Tokens.sun
                                  : null,
                              borderWidth: _hinted && i == _placed ? 4 : 0,
                              width: side,
                              height: side,
                              padding: const EdgeInsets.all(10),
                              semanticLabel: _r.steps[i].caption,
                              onTap: () => _tap(i),
                              child: Center(
                                child: StimulusArt(
                                  _r.steps[i].emoji,
                                  size: side * 0.68,
                                ),
                              ),
                            ),
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
    },
  );
}

/// Un loc din șir: gol (cu numărul lui, cel următor luminat) sau cu poza pusă + propoziția.
class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.number,
    required this.side,
    required this.step,
    required this.next,
    required this.compact,
    required this.burst,
    required this.motion,
  });

  final int number;
  final double side;
  final OrderStep? step;
  final bool next;
  final bool compact;
  final int burst;
  final MotionPolicy motion;

  @override
  Widget build(BuildContext context) {
    final filled = step != null;
    return SizedBox(
      width: side,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: motion.d(250),
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: filled
                      ? Tokens.goodSoft
                      : Colors.white.withValues(alpha: next ? 0.85 : 0.55),
                  borderRadius: BorderRadius.circular(Tokens.radius),
                  border: Border.all(
                    color: filled
                        ? Tokens.good
                        : (next ? Tokens.sun : const Color(0xFFE3D9C6)),
                    width: next || filled ? 4 : 3,
                  ),
                ),
                child: Center(
                  child: filled
                      ? StimulusArt(
                          step!.emoji,
                          size: side * 0.68,
                        ).land(key: ValueKey(step!.emoji))
                      : Text(
                          '$number',
                          style: Theme.of(context).textTheme.displaySmall!
                              .copyWith(
                                color: next
                                    ? shade(Tokens.sun, 0.25)
                                    : const Color(0xFFC9B48E),
                              ),
                        ),
                ),
              ),
              if (motion.particles && filled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: StarBurst(trigger: burst, count: 8),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: compact ? 30 : 44,
            child: filled
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xEEFFFBF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          step!.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              (compact
                                      ? Theme.of(context).textTheme.labelSmall
                                      : Theme.of(context).textTheme.labelLarge)!
                                  .copyWith(color: Tokens.ink, height: 1.1),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  /// Poza „aterizează” în loc (mică apropiere).
  Widget land({required Key key}) => TweenAnimationBuilder<double>(
    key: key,
    tween: Tween(begin: 0.6, end: 1),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutBack,
    builder: (context, s, child) => Transform.scale(scale: s, child: child),
    child: this,
  );
}
