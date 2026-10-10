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
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final imitationLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('fa-ca-licuriciul'),
);

enum _Phase { demo, turn, done }

/// Fă ca Licurici (IMI1–3): un licurici zboară la un obiect și îl face să sară (atingere)
/// sau îl duce în coș (tragere); apoi copilul repetă. Greșeala doar clatină obiectul; după
/// două greșeli la același pas, Licurici arată din nou acel pas (model, P4).
class ImitationScreen extends ConsumerStatefulWidget {
  const ImitationScreen({
    super.key,
    this.game = const ImitationGame(),
    this.seed,
  });

  final ImitationGame game;
  final int? seed;

  @override
  ConsumerState<ImitationScreen> createState() => _ImitationScreenState();
}

class _ImitationScreenState extends ConsumerState<ImitationScreen>
    with SingleTickerProviderStateMixin {
  late ImitationLevel _level;
  bool _blocked = false;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  late final _demo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _attempts = <ImitationAttempt>[];
  final _clock = Stopwatch();
  late ImitationCheck _check;
  int _round = 0;
  int _generation = 0;
  _Phase _phase = _Phase.demo;
  ImitationAction? _showing;

  /// Obiectele duse deja în coș în runda curentă (demonstrație sau copil).
  final _inBasket = <int>{};
  final _hop = <int, int>{};
  final _shake = <int, int>{};
  int? _dragging;
  Offset _dragOffset = Offset.zero;
  bool _modelRepeated = false;
  int? _startMs;
  int _burst = 0;
  int _reaction = 0;
  MascotMood _mood = MascotMood.idle;
  bool _ready = false;
  ImitationResult? _result;
  String? _sticker;
  Timer? _timer;

  ImitationRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _generation++;
    // Fără imaginile pe care copilul nu trebuie să le vadă (alese de adult, `avoidItems`).
    final avoid = avoidedOf(ref);
    final level = generateAvoiding(
      (seed) => widget.game.generate(ref.read(imitationLevelProvider), seed: seed),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _attempts.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    _resetRound();
    final generation = _generation;
    Future(
      () => mounted ? precacheStimuli(context, {..._level.art, '✨'}) : null,
    ).whenComplete(() {
      if (!mounted || generation != _generation) return;
      setState(() => _ready = true);
      _playDemo(_r.actions);
    });
  }

  void _resetRound() {
    _check = ImitationCheck(_r);
    _inBasket.clear();
    _modelRepeated = false;
    _startMs = null;
    _phase = _Phase.demo;
    _mood = MascotMood.idle;
  }

  /// Licurici arată acțiunile, apoi scena revine și e rândul copilului.
  Future<void> _playDemo(List<ImitationAction> actions) async {
    final generation = _generation;
    final round = _round;
    bool stale() => !mounted || generation != _generation || round != _round;
    setState(() => _phase = _Phase.demo);
    ref.read(voiceProvider).say(['Privește ce face Licurici.']);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Ce era deja făcut de copil rămâne; demonstrația pornește de la scena actuală.
    final before = {..._inBasket};
    for (final a in actions) {
      if (stale()) return;
      setState(() => _showing = a);
      await _demo.forward(from: 0).orCancel.catchError((_) {});
      if (stale()) return;
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        if (a.kind == ImitationKind.drag) {
          _inBasket.add(a.target);
        } else {
          _hop[a.target] = (_hop[a.target] ?? 0) + 1;
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (stale()) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (stale()) return;
    setState(() {
      _showing = null;
      _inBasket
        ..clear()
        ..addAll(before);
      _phase = _Phase.turn;
    });
    ref.read(voiceProvider).say(['Acum tu!']);
    _clock
      ..reset()
      ..start();
  }

  void _perform(ImitationAction action) {
    if (_phase != _Phase.turn) return;
    _startMs ??= _clock.elapsedMilliseconds;
    if (_check.perform(action)) {
      ref.read(sfxProvider).play(Sfx.correct);
      setState(() {
        if (action.kind == ImitationKind.drag) {
          _inBasket.add(action.target);
        } else {
          _hop[action.target] = (_hop[action.target] ?? 0) + 1;
        }
        _mood = MascotMood.happy;
        _reaction++;
      });
      if (_check.complete) _completeRound();
    } else {
      ref.read(voiceProvider).say(['Mai încearcă']);
      setState(() {
        _shake[action.target] = (_shake[action.target] ?? 0) + 1;
        _mood = MascotMood.encourage;
        _reaction++;
      });
      if (_check.wrongHere >= 2) {
        _modelRepeated = true;
        _timer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) _playDemo([_check.expected!]);
        });
      }
    }
  }

  void _completeRound() {
    _phase = _Phase.done;
    _attempts.add(
      ImitationAttempt(
        _r,
        wrong: _check.wrong,
        firstWrong: _check.firstWrong,
        modelRepeated: _modelRepeated,
        startMs: _startMs,
      ),
    );
    setState(() => _burst++);
    ref.read(voiceProvider).say(['Bravo']);
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_round + 1 < _total) {
        setState(() {
          _round++;
          _resetRound();
        });
        _playDemo(_r.actions);
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = ImitationResult(_level, _attempts);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.imitationLevel(result));
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
          .read(imitationLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _demo.dispose();
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
      final w = box.maxWidth, h = box.maxHeight;
      final n = _r.objects.length;
      final basket = _level.hasBasket;
      final span = basket ? w * 0.74 : w;
      final side = math
          .min(span / (n + 0.6) * 0.8, h * 0.34)
          .clamp(64.0, 190.0);
      Offset objCenter(int i) => Offset(span * (i + 1) / (n + 1), h * 0.42);
      final basketSide = side * 1.25;
      final basketCenter = Offset(w * 0.87, h * 0.62);
      final mascotSize = layout.compact ? 70.0 : 120.0;
      final mascotAt = Offset(mascotSize * 0.6, h - mascotSize * 0.6);
      final title = Theme.of(context).textTheme;

      Offset dragPos(int i) =>
          Offset.lerp(objCenter(i), basketCenter, _demoT(_demo.value)) ??
          objCenter(i);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Ce se întâmplă acum (Privește / Rândul tău).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: OutlinedTitle(
                _phase == _Phase.demo ? 'Privește' : 'Rândul tău',
                key: const ValueKey('imitation-phase'),
                style: layout.compact ? title.titleLarge : title.headlineMedium,
              ),
            ),
          ),
          if (basket)
            Positioned(
              left: basketCenter.dx - basketSide / 2,
              top: basketCenter.dy - basketSide / 2,
              width: basketSide,
              height: basketSide,
              child: IgnorePointer(
                child: Stack(
                  children: [
                    StimulusArt(
                      imitationBasket,
                      size: basketSide,
                      key: const ValueKey('imitation-basket'),
                    ),
                    // Ce e în coș se vede mic, deasupra.
                    for (final (k, i) in _inBasket.indexed)
                      Positioned(
                        left: basketSide * (0.12 + 0.22 * (k % 3)),
                        top: basketSide * 0.02,
                        child: StimulusArt(
                          _r.objects[i],
                          size: basketSide * 0.36,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < n; i++)
            if (!_inBasket.contains(i))
              AnimatedBuilder(
                animation: _demo,
                builder: (context, child) {
                  final demoDrag =
                      _showing?.target == i &&
                      _showing?.kind == ImitationKind.drag;
                  final c = demoDrag
                      ? dragPos(i)
                      : objCenter(i) +
                            (_dragging == i ? _dragOffset : Offset.zero);
                  return Positioned(
                    left: c.dx - side / 2,
                    top: c.dy - side / 2,
                    width: side,
                    height: side,
                    child: child!,
                  );
                },
                child: Juice(
                  enabled: motion.movement,
                  hopTick: _hop[i] ?? 0,
                  shakeTick: _shake[i] ?? 0,
                  child: Semantics(
                    button: true,
                    label: 'Obiectul ${i + 1}',
                    child: GestureDetector(
                      key: ValueKey('imitation-object-$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          _perform(ImitationAction(ImitationKind.tap, i)),
                      onPanStart: _phase != _Phase.turn
                          ? null
                          : (_) => setState(() {
                              _dragging = i;
                              _dragOffset = Offset.zero;
                            }),
                      onPanUpdate: _phase != _Phase.turn
                          ? null
                          : (d) => setState(() => _dragOffset += d.delta),
                      onPanEnd: _phase != _Phase.turn
                          ? null
                          : (_) {
                              final end = objCenter(i) + _dragOffset;
                              final moved = _dragOffset.distance;
                              setState(() {
                                _dragging = null;
                                _dragOffset = Offset.zero;
                              });
                              if (basket &&
                                  (end - basketCenter).distance <
                                      basketSide * 0.75) {
                                _perform(
                                  ImitationAction(ImitationKind.drag, i),
                                );
                              } else if (moved < 24) {
                                _perform(ImitationAction(ImitationKind.tap, i));
                              }
                            },
                      child: StimulusArt(_r.objects[i], size: side),
                    ),
                  ),
                ),
              ),
          // Licuriciul-model care zboară la obiect.
          if (_showing case final a?)
            AnimatedBuilder(
              animation: _demo,
              builder: (context, _) {
                final t = _demo.value;
                final target = objCenter(a.target);
                // 0…0.5: zboară la obiect (în arc); 0.5…1: pentru tragere, duce obiectul.
                final fly = Curves.easeInOut.transform((t / 0.5).clamp(0, 1));
                var p = Offset.lerp(
                  mascotAt,
                  target - Offset(0, side * 0.45),
                  fly,
                )!;
                p -= Offset(0, math.sin(fly * math.pi) * h * 0.15);
                if (a.kind == ImitationKind.drag && t > 0.5) {
                  p = dragPos(a.target) - Offset(0, side * 0.45);
                }
                final s = side * 0.55;
                return Positioned(
                  left: p.dx - s / 2,
                  top: p.dy - s / 2,
                  width: s,
                  height: s,
                  child: IgnorePointer(child: StimulusArt('✨', size: s)),
                );
              },
            ),
          Positioned(
            left: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Mascot(size: mascotSize, mood: _mood, reaction: _reaction),
            ),
          ),
          if (motion.particles)
            Positioned.fill(
              child: IgnorePointer(
                child: StarBurst(trigger: _burst, count: 10),
              ),
            ),
          Positioned(
            right: 8,
            top: 4,
            child: _RoundDots(total: _total, index: _round),
          ),
        ],
      );
    },
  );

  /// Partea de tragere a demonstrației (a doua jumătate a animației), 0…1.
  static double _demoT(double t) =>
      Curves.easeInOut.transform(((t - 0.5) / 0.5).clamp(0, 1));
}

class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 5),
          decoration: BoxDecoration(
            color: i < index
                ? Tokens.sun
                : (i == index ? Colors.white : Colors.white54),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE3D2B4), width: 2),
          ),
        ),
    ],
  );
}
