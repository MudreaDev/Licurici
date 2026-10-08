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
import '../../../shared/illustration.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final waitLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('semaforul'));

enum _Light { off, flicker, green }

/// Semaforul (FEX1): un felinar mare, stins. Copilul atinge doar când se face verde. Atingerea
/// mai devreme doar clatină felinarul („Așteaptă verde.”) și se numără; verdele care nu e
/// atins se stinge singur, fără reproș.
class WaitScreen extends ConsumerStatefulWidget {
  const WaitScreen({super.key, this.game = const WaitGame(), this.seed});

  final WaitGame game;
  final int? seed;

  @override
  ConsumerState<WaitScreen> createState() => _WaitScreenState();
}

class _WaitScreenState extends ConsumerState<WaitScreen>
    with WidgetsBindingObserver {
  late WaitLevel _level;
  final _responses = <WaitResponse>[];
  final _timers = <Timer>[];
  final _rt = Stopwatch();
  int _index = 0;
  int _anticipations = 0;
  bool _warned = false;
  _Light _light = _Light.off;
  bool _caught = false;
  int _shake = 0;
  int _burst = 0;
  bool _ready = false;
  WaitResult? _result;
  String? _sticker;

  WaitTrial get _trial => _level.trials[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _after(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  void _start() {
    _cancel();
    _level = widget.game.generate(
      ref.read(waitLevelProvider),
      seed: widget.seed,
    );
    _responses.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    _light = _Light.off;
    Future<void>(() async {
      if (!mounted) return;
      await Future.wait([
        precacheImage(illustration('sprites/lantern_green'), context),
        precacheImage(illustration('sprites/lantern_yellow'), context),
      ]).catchError((_) => <void>[]);
    }).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say([
        'Atinge felinarul doar când se face verde.',
      ]);
      _after(2600, _beginTrial);
    });
  }

  void _beginTrial() {
    _cancel();
    setState(() {
      _light = _Light.off;
      _anticipations = 0;
      _warned = false;
      _caught = false;
    });
    for (final f in _trial.flickersAtMs) {
      _after(f, () => setState(() => _light = _Light.flicker));
      _after(
        f + WaitLevel.flickerMs,
        () => setState(() => _light = _Light.off),
      );
    }
    _after(_trial.waitMs, _green);
  }

  void _green() {
    setState(() => _light = _Light.green);
    _rt
      ..reset()
      ..start();
    _after(WaitLevel.greenMs, () => _endTrial(rtMs: null));
  }

  void _tap() {
    if (!_ready || _result != null || _caught) return;
    if (_light == _Light.green) {
      final rt = _rt.elapsedMilliseconds;
      ref.read(sfxProvider).play(Sfx.correct);
      ref.read(voiceProvider).say(['Bravo']);
      setState(() {
        _caught = true;
        _burst++;
      });
      _cancel();
      _after(900, () => _endTrial(rtMs: rt));
    } else {
      // Prea devreme: se numără, felinarul se clatină; vocea o singură dată pe încercare.
      if (!_warned) ref.read(voiceProvider).say(['Așteaptă verde.']);
      setState(() {
        _anticipations++;
        _warned = true;
        _shake++;
      });
    }
  }

  void _endTrial({required int? rtMs}) {
    _rt.stop();
    _responses.add(
      WaitResponse(_trial, anticipations: _anticipations, rtMs: rtMs),
    );
    if (_index + 1 < _level.trials.length) {
      setState(() {
        _index++;
        _light = _Light.off;
      });
      _after(900, _beginTrial);
    } else {
      _finish();
    }
  }

  void _finish() {
    _cancel();
    final result = WaitResult(_level, _responses);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.waitLevel(result));
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
          .read(waitLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // În fundal nu se măsoară nimic: încercarea curentă reîncepe la revenire.
    if (state != AppLifecycleState.resumed) {
      _cancel();
    } else if (_ready && _result == null) {
      _after(600, _beginTrial);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
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
      final side = math.min(box.maxHeight * 0.7, box.maxWidth * 0.4);
      final green = _light == _Light.green;
      final text = Theme.of(context).textTheme;
      return GestureDetector(
        key: const ValueKey('wait-field'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Juice(
                  enabled: motion.movement,
                  shakeTick: _shake,
                  popTick: _burst,
                  child: _Lantern(
                    key: const ValueKey('wait-lantern'),
                    light: _light,
                    side: side,
                    motion: motion,
                  ),
                ),
                SizedBox(height: layout.compact ? 4 : 12),
                AnimatedSwitcher(
                  duration: motion.d(200),
                  child: OutlinedTitle(
                    green ? 'Acum!' : 'Așteaptă…',
                    key: ValueKey(green),
                    color: green ? shade(Tokens.good, 0.2) : Tokens.ink,
                    style: layout.compact
                        ? text.headlineSmall
                        : text.headlineMedium,
                  ),
                ),
              ],
            ),
            if (motion.particles)
              Positioned.fill(
                child: IgnorePointer(
                  child: StarBurst(trigger: _burst, count: 12),
                ),
              ),
            Positioned(
              right: 12,
              top: 4,
              child: Row(
                children: [
                  for (var i = 0; i < _level.trials.length; i++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _index
                            ? Tokens.good
                            : Colors.white.withValues(alpha: 0.6),
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

/// Felinarul: stins (întunecat), licărire galbenă, verde aprins cu halou.
class _Lantern extends StatelessWidget {
  const _Lantern({
    super.key,
    required this.light,
    required this.side,
    required this.motion,
  });

  final _Light light;
  final double side;
  final MotionPolicy motion;

  @override
  Widget build(BuildContext context) {
    final on = light != _Light.off;
    final halo = light == _Light.green
        ? const Color(0xFF8FE3A8)
        : const Color(0xFFFFE08A);
    final image = Image(
      image: illustration(
        light == _Light.flicker
            ? 'sprites/lantern_yellow'
            : 'sprites/lantern_green',
      ),
      width: side,
      height: side,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? halo : const Color(0xFF7A8296),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: light == _Light.green ? 'Felinarul e verde' : 'Felinarul e stins',
      child: SizedBox.square(
        dimension: side,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: motion.d(150),
              child: Container(
                width: side * 1.5,
                height: side * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      halo.withValues(alpha: 0.85),
                      halo.withValues(alpha: 0.3),
                      halo.withValues(alpha: 0),
                    ],
                    stops: const [0.15, 0.5, 1],
                  ),
                ),
              ),
            ),
            // Stins: gri-albăstrui, ca un felinar seara; aprins: culoarea lui.
            ColorFiltered(
              colorFilter: on
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.25, 0.35, 0.1, 0, 10, //
                      0.25, 0.35, 0.1, 0, 14,
                      0.3, 0.35, 0.15, 0, 30,
                      0, 0, 0, 1, 0,
                    ]),
              child: image,
            ),
          ],
        ),
      ),
    );
  }
}
