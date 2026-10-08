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
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

class TurnProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

final turnLevelProvider = NotifierProvider<TurnProgress, int>(TurnProgress.new);

enum _Who { child, licurici, pass, done }

/// Rândul meu, rândul tău (EMO7): un turn construit pe rând. În rândul copilului, cubul lui
/// sare în tava din stânga: îl atinge (sau îl trage) și cubul zboară pe turn. În rândul lui
/// Licurici, tava copilului e „în pauză” (✋); atingerile se numără, cubul doar se clatină
/// și Licurici spune o dată, blând, „Așteaptă rândul tău.”. De la nivelul 5 copilul dă
/// rândul cu butonul „Rândul tău, Licurici!”.
class TurnScreen extends ConsumerStatefulWidget {
  const TurnScreen({super.key, this.game = const TurnGame(), this.seed});

  final TurnGame game;
  final int? seed;

  @override
  ConsumerState<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends ConsumerState<TurnScreen> {
  late TurnLevel _level;
  final _cycles = <TurnCycle>[];
  final _timers = <Timer>[];
  final _clock = Stopwatch();
  int _tower = 0;
  int _placed = 0;
  _Who _who = _Who.child;
  int _early = 0;
  bool _warned = false;
  bool _passPrompted = false;
  int? _placeMs;
  int _shake = 0;
  int _burst = 0;
  bool _thinking = false;
  bool _flying = false;
  TurnResult? _result;
  String? _sticker;

  List<int> get _colors => _level.colors[_tower];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
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
    _level = widget.game.generate(ref.read(turnLevelProvider), seed: widget.seed);
    _cycles.clear();
    _tower = 0;
    _result = null;
    _sticker = null;
    ref.read(voiceProvider).say(['Construim un turn. Pe rând: o dată tu, o dată eu.']);
    _beginTower(first: true);
  }

  void _beginTower({bool first = false}) {
    _placed = 0;
    _early = 0;
    _warned = false;
    _passPrompted = false;
    _placeMs = null;
    _who = _Who.done; // nimeni, până începe
    _after(first ? 3200 : 900, _nextTurn);
  }

  void _nextTurn() {
    if (_placed >= _level.axes.blocks) return _towerDone();
    if (widget.game.childPlaces(_level, _placed)) {
      setState(() => _who = _Who.child);
      _clock
        ..reset()
        ..start();
      ref.read(voiceProvider).say(['Rândul tău.']);
    } else {
      _licuriciTurn();
    }
  }

  void _licuriciTurn() {
    setState(() {
      _who = _Who.licurici;
      _thinking = _level.axes.hesitate;
    });
    ref.read(voiceProvider).say(['Acum e rândul meu.']);
    final wait = _level.axes.waitMs;
    if (_level.axes.hesitate) _after((wait * 0.55).round(), () => setState(() => _thinking = false));
    _after(wait, () => _place(byChild: false));
  }

  /// Copilul își pune cubul (atingere sau tragere pe tavă).
  void _childPlace() {
    if (_flying) return;
    switch (_who) {
      case _Who.child:
        _placeMs = _clock.elapsedMilliseconds;
        _place(byChild: true);
      case _Who.licurici:
        // Nu e rândul lui: se numără, cubul se clatină, Licurici amintește o dată.
        _early++;
        if (!_warned) ref.read(voiceProvider).say(['Așteaptă rândul tău.']);
        setState(() {
          _warned = true;
          _shake++;
        });
      case _Who.pass || _Who.done:
        break;
    }
  }

  void _place({required bool byChild}) {
    setState(() => _flying = true);
    ref.read(sfxProvider).play(Sfx.tap);
    _after(450, () {
      setState(() {
        _flying = false;
        _placed++;
      });
      if (byChild) {
        if (_level.axes.passTurn && _placed < _level.axes.blocks) {
          setState(() => _who = _Who.pass);
          ref.read(voiceProvider).say(['Spune-mi când e rândul meu.']);
          _after(TurnLevel.passPromptMs, () {
            if (_who != _Who.pass) return;
            _passPrompted = true;
            ref.read(voiceProvider).say(['E rândul meu?']);
          });
        } else {
          _closeCycle();
          _after(500, _nextTurn);
        }
      } else {
        _after(400, _nextTurn);
      }
    });
  }

  /// Copilul dă rândul.
  void _pass() {
    if (_who != _Who.pass) return;
    _cancel();
    ref.read(sfxProvider).play(Sfx.tap);
    _closeCycle();
    _nextTurn();
  }

  /// Un ciclu se încheie după mutarea copilului (cu rândul lui Licurici dinainte, dacă a fost).
  void _closeCycle() {
    _cycles.add(TurnCycle(earlyTaps: _early, placeMs: _placeMs, passPrompted: _passPrompted));
    _early = 0;
    _warned = false;
    _passPrompted = false;
    _placeMs = null;
  }

  void _towerDone() {
    setState(() {
      _who = _Who.done;
      _burst++;
    });
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Am construit împreună!']);
    _after(2200, () {
      if (_tower + 1 < _level.axes.towers) {
        setState(() => _tower++);
        _beginTower();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _cancel();
    final result = TurnResult(_level, _cycles);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.turnLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) ref.read(turnLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
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
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
                          FinishAction(
                            'Mai departe',
                            Icons.arrow_forward_rounded,
                            Tokens.good,
                            () => _again(next: true),
                          ),
                        ],
                      )
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
      final block = math.min(box.maxHeight * 0.8 / (_level.axes.blocks + 1.2), box.maxWidth * 0.12).clamp(24.0, 90.0);
      final side = math.min(box.maxWidth * 0.26, box.maxHeight * 0.75);
      final childTurn = _who == _Who.child;
      final nextColor = _placed < _colors.length ? Color(_colors[_placed]) : Tokens.sun;
      return Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tava copilului.
              SizedBox(
                width: side,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(active: childTurn || _who == _Who.pass, label: 'Tu', icon: Icons.back_hand_rounded),
                    SizedBox(height: layout.compact ? 6 : 14),
                    Semantics(
                      button: true,
                      label: childTurn ? 'Cubul tău. Pune-l pe turn.' : 'Cubul tău. Așteaptă rândul tău.',
                      child: GestureDetector(
                        key: const ValueKey('turn-tray'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _childPlace,
                        onPanEnd: (_) => _childPlace(),
                        child: Juice(
                          enabled: motion.movement,
                          shakeTick: _shake,
                          child: SizedBox.square(
                            dimension: side * 0.7,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CandyPanel(
                                  padding: EdgeInsets.zero,
                                  radius: side * 0.12,
                                  child: const SizedBox.expand(),
                                ),
                                AnimatedOpacity(
                                  opacity: childTurn && !_flying ? 1 : (_who == _Who.licurici ? 0.35 : 0),
                                  duration: motion.d(200),
                                  child: _Pulse(
                                    enabled: motion.movement && childTurn,
                                    child: _Block(color: nextColor, size: side * 0.22, mine: true),
                                  ),
                                ),
                                if (_who == _Who.licurici)
                                  Icon(Icons.front_hand_rounded, size: side * 0.3, color: const Color(0xCC8A9BB0)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Turnul.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = _placed - 1; i >= 0; i--)
                      _Block(
                        key: ValueKey('turn-block-$_tower-$i'),
                        color: Color(_colors[i]),
                        size: block,
                        drop: motion.movement,
                        mine: widget.game.childPlaces(_level, i),
                      ),
                    Container(
                      width: block * 2.6,
                      height: block * 0.35,
                      margin: EdgeInsets.only(bottom: layout.compact ? 6 : 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9A6634),
                        borderRadius: BorderRadius.circular(block * 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              // Licurici.
              SizedBox(
                width: side,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(active: _who == _Who.licurici, label: 'Licurici', icon: Icons.auto_awesome_rounded),
                    SizedBox(height: layout.compact ? 4 : 10),
                    Mascot(
                      size: side * 0.62,
                      mood: _who == _Who.done && _placed > 0
                          ? MascotMood.celebrate
                          : (_who == _Who.licurici
                                ? (_thinking ? MascotMood.think : MascotMood.happy)
                                : MascotMood.idle),
                    ),
                    AnimatedOpacity(
                      opacity: _who == _Who.licurici && !_flying ? 1 : 0,
                      duration: motion.d(200),
                      child: _Block(color: nextColor, size: side * 0.22, mine: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // „Rândul tău, Licurici!” — copilul dă rândul.
          if (_who == _Who.pass)
            Positioned(
              left: 0,
              right: 0,
              bottom: layout.compact ? 6 : 18,
              child: Center(
                child: CandyButton(
                  key: const ValueKey('turn-pass'),
                  label: 'Rândul tău, Licurici!',
                  icon: Icons.arrow_forward_rounded,
                  color: Tokens.primary,
                  minWidth: 260,
                  onTap: _pass,
                ),
              ),
            ),
          if (motion.particles)
            Positioned.fill(
              child: IgnorePointer(child: StarBurst(trigger: _burst, count: 18)),
            ),
        ],
      );
    },
  );
}

/// Insigna „al cui e rândul”: aprinsă (mare, colorată) sau stinsă.
class _Badge extends StatelessWidget {
  const _Badge({required this.active, required this.label, required this.icon});

  final bool active;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: active ? 1.08 : 0.9,
    duration: const Duration(milliseconds: 250),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Tokens.sun : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? shade(Tokens.sun, 0.3) : Colors.transparent, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Tokens.ink, size: 22),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.ink)),
        ],
      ),
    ),
  );
}

/// Un cub de jucărie: fața colorată, muchia de sus luminată, umbra jos.
class _Block extends StatelessWidget {
  const _Block({super.key, required this.color, required this.size, required this.mine, this.drop = false});

  final Color color;
  final double size;
  final bool drop;

  /// Cubul copilului (steluță) sau al lui Licurici (lună): în turn se vede cine l-a pus.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final cube = Container(
      width: size * 1.6,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.3)!, color, shade(color, 0.2)],
          stops: const [0, 0.35, 1],
        ),
        border: Border.all(color: shade(color, 0.3), width: 2),
      ),
      child: Center(
        child: Icon(
          mine ? Icons.star_rounded : Icons.nightlight_round,
          size: size * 0.6,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
    if (!drop) return cube;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.bounceOut,
      builder: (context, k, child) => Transform.translate(offset: Offset(0, -(1 - k) * size * 2.5), child: child),
      child: cube,
    );
  }
}

/// Pulsează ușor (cubul care așteaptă să fie pus).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
