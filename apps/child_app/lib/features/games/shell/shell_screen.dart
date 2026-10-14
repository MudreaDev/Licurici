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
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../../../shared/cheer.dart';

final shellLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('cucu-bau'));

enum _Phase { show, swapping, ask, reveal, finished }

/// Cucu-bau (COG2): obiectul se ascunde sub un pahar, paharele se mută în arc, copilul
/// arată unde e. Paharele sunt identice (altfel copilul ar urmări culoarea, nu paharul).
/// Greșeala nu se pedepsește: se ridică și paharul bun, ca să vadă unde era.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, this.game = const ShellGame(), this.seed});

  final ShellGame game;
  final int? seed;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with SingleTickerProviderStateMixin {
  late ShellLevel _level;
  bool _blocked = false;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  late final _move = AnimationController(vsync: this);
  int _round = 0;
  _Phase _phase = _Phase.show;

  /// Locul fiecărui pahar (id = locul de la începutul rundei).
  late List<int> _slotOf;
  (int, int)? _swap; // paharele care se mută acum (id-uri) și încotro
  final _lifted = <int>{};
  final _picks = <ShellPick>[];
  final _clock = Stopwatch();
  int? _picked;
  int _burst = 0;
  int _reaction = 0;
  MascotMood _mood = MascotMood.idle;
  ShellResult? _result;
  String? _sticker;
  Timer? _timer;
  bool _ready = false;

  ShellRound get _r => _level.rounds[_round];
  int get _cups => _level.axes.cups;

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
      (seed) => widget.game.generate(ref.read(shellLevelProvider), seed: seed),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _round = 0;
    _picks.clear();
    _result = null;
    _sticker = null;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      _enterRound();
    });
  }

  void _enterRound() {
    _slotOf = List.generate(_cups, (i) => i);
    _swap = null;
    _picked = null;
    _mood = MascotMood.idle;
    // Paharul cu obiectul e ridicat: copilul vede ce se ascunde și unde.
    setState(() {
      _phase = _Phase.show;
      _lifted
        ..clear()
        ..add(_r.start);
    });
    ref.read(voiceProvider).say(['Privește']);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _lifted.clear());
      _timer = Timer(const Duration(milliseconds: 600), () => _swapNext(0));
    });
  }

  /// Mutarea [k]: paharele de pe cele două locuri își schimbă locurile, în arc.
  Future<void> _swapNext(int k) async {
    if (!mounted) return;
    if (k >= _r.swaps.length) {
      setState(() {
        _phase = _Phase.ask;
        _swap = null;
      });
      _clock
        ..reset()
        ..start();
      ref.read(voiceProvider).say([_r.thing.question]);
      return;
    }
    final (a, b) = _r.swaps[k];
    final cupA = _slotOf.indexOf(a);
    final cupB = _slotOf.indexOf(b);
    setState(() {
      _phase = _Phase.swapping;
      _swap = (cupA, cupB);
    });
    _move.duration = Duration(milliseconds: _level.axes.swapMs);
    await _move.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _slotOf[cupA] = b;
      _slotOf[cupB] = a;
      _swap = null;
    });
    _timer = Timer(const Duration(milliseconds: 120), () => _swapNext(k + 1));
  }

  void _pick(int cup) {
    if (_phase != _Phase.ask) return;
    final slot = _slotOf[cup];
    final pick = ShellPick(_round, slot, ms: _clock.elapsedMilliseconds);
    _picks.add(pick);
    final correct = slot == _r.answer;
    final hidden = _r.start; // id-ul paharului cu obiectul
    setState(() {
      _phase = _Phase.reveal;
      _picked = cup;
      _lifted.add(cup);
      _reaction++;
      _mood = correct ? MascotMood.happy : MascotMood.encourage;
      if (correct) _burst++;
    });
    ref.read(sfxProvider).play(correct ? Sfx.correct : Sfx.tap);
    final cheer = ref.read(cheerProvider);
    _praise = correct ? cheer.correct() : cheer.retry();
    ref.read(voiceProvider).say([_praise]);
    // Greșit: după o clipă se ridică și paharul bun (învățare fără eroare).
    if (!correct) {
      _timer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _lifted.add(hidden));
      });
    }
    Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      if (_round + 1 < _total) {
        _round++;
        _enterRound();
      } else {
        _finish();
      }
    });
  }

  /// Ce a spus Licurici la ultima alegere (scris și în balon).
  String _praise = '';

  void _finish() {
    final result = ShellResult(_level, _picks);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.shellLevel(result));
    session.checkpoint();
    setState(() {
      _phase = _Phase.finished;
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) {
      ref
          .read(shellLevelProvider.notifier)
          .setLevel(_result!.suggestedNextLevel(_level.level));
    }
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return const NothingToShow();
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final result = _result;
    final message = switch (_phase) {
      _Phase.show => 'Privește!',
      _Phase.swapping => 'Privește!',
      _Phase.ask => _r.thing.question,
      _Phase.reveal =>
        _picked != null && _slotOf[_picked!] == _r.answer
            ? _praise
            : 'Aici era!',
      _Phase.finished => '',
    };
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
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          0,
                          16,
                          layout.compact ? 8 : 20,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (layout.twoPane)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SpeechBubble(
                                    tail: BubbleTail.bottom,
                                    child: Text(
                                      message,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Mascot(
                                    size: layout.mascot,
                                    mood: _mood,
                                    reaction: _reaction,
                                  ),
                                ],
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _table(motion)),
                                  if (motion.particles)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: StarBurst(
                                          trigger: _burst,
                                          count: 8,
                                        ),
                                      ),
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

  /// Masa cu paharele. Locurile sunt egal distanțate; paharul care trece prin față e mai jos
  /// și puțin mai mare, cel din spate mai sus și mai mic — ca pe o masă adevărată.
  Widget _table(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      // Destul de mari ca să fie ușor de atins, cu loc deasupra pentru ridicare și arc.
      final cupW = math.min(
        math.min(box.maxWidth / (_cups + 1.4), box.maxHeight * 0.42),
        220.0,
      );
      final cupH = cupW * 1.05;
      // Locurile stau grupate la mijloc, nu împrăștiate pe toată lățimea.
      final span = math.min(box.maxWidth, cupW * 1.5 * _cups);
      final left0 = (box.maxWidth - span) / 2;
      final step = span / _cups;
      double slotX(int slot) => left0 + step * (slot + 0.5) - cupW / 2;
      final baseY = box.maxHeight * 0.62 - cupH / 2;
      return AnimatedBuilder(
        animation: _move,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_move.value);
          final cups = <Widget>[];
          // Ordinea de desenare: paharul care trece prin spate primul.
          final order = List.generate(_cups, (i) => i)
            ..sort((a, b) {
              final s = _swap;
              if (s == null) return 0;
              if (a == s.$2) return -1;
              if (b == s.$2) return 1;
              return 0;
            });
          for (final cup in order) {
            var x = slotX(_slotOf[cup]);
            var y = baseY;
            var scale = 1.0;
            final s = _swap;
            if (s != null && (cup == s.$1 || cup == s.$2)) {
              final front = cup == s.$1;
              final from = _slotOf[cup];
              final to = front ? _slotOf[s.$2] : _slotOf[s.$1];
              x = slotX(from) + (slotX(to) - slotX(from)) * t;
              final arc = math.sin(math.pi * t) * cupH * 0.28;
              y = baseY + (front ? arc * 0.6 : -arc);
              scale = front
                  ? 1 + 0.06 * math.sin(math.pi * t)
                  : 1 - 0.08 * math.sin(math.pi * t);
            }
            final lifted = _lifted.contains(cup);
            final hasThing = cup == _r.start;
            cups.add(
              Positioned(
                left: x,
                top: y,
                width: cupW,
                height: cupH * 1.6,
                child: Transform.scale(
                  scale: scale,
                  child: _CupWithThing(
                    key: ValueKey('cup-$cup'),
                    width: cupW,
                    height: cupH,
                    lifted: lifted,
                    thing: hasThing ? _r.thing.emoji : null,
                    highlight: _phase == _Phase.reveal && hasThing && lifted,
                    motion: motion,
                    onTap: _phase == _Phase.ask ? () => _pick(cup) : null,
                  ),
                ),
              ),
            );
          }
          return Stack(clipBehavior: Clip.none, children: cups);
        },
      );
    },
  );
}

/// Un pahar (desenat din cod) și, dedesubt, obiectul ascuns — vizibil doar când paharul e
/// ridicat. Zona de atingere e tot paharul.
class _CupWithThing extends StatelessWidget {
  const _CupWithThing({
    super.key,
    required this.width,
    required this.height,
    required this.lifted,
    required this.thing,
    required this.highlight,
    required this.motion,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool lifted;
  final String? thing;
  final bool highlight;
  final MotionPolicy motion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lift = lifted ? height * 0.55 : 0.0;
    return Semantics(
      button: onTap != null,
      label: 'Pahar',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Umbra paharului pe masă.
            Positioned(
              left: width * 0.08,
              right: width * 0.08,
              top: height * 0.93,
              height: height * 0.14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  color: const Color(0x332F3D3B),
                ),
              ),
            ),
            // Obiectul stă în întregime în conturul paharului: când paharul e jos, îl
            // acoperă complet (pictat după el); se vede doar când paharul e ridicat.
            if (thing != null)
              Positioned(
                left: width * 0.24,
                width: width * 0.52,
                top: height * 0.86 - width * 0.52,
                height: width * 0.52,
                child: DecoratedBox(
                  decoration: highlight
                      ? const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x99F2CF6B), blurRadius: 24),
                          ],
                        )
                      : const BoxDecoration(),
                  child: StimulusArt(thing!, size: width * 0.52),
                ),
              ),
            AnimatedPositioned(
              duration: motion.d(320),
              curve: Curves.easeOutBack,
              left: 0,
              width: width,
              top: -lift,
              height: height,
              child: CustomPaint(painter: _CupPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paharul răsturnat: corp ușor conic, buză rotunjită jos, dungi și o lumină pe margine.
class _CupPainter extends CustomPainter {
  static const _color = Color(0xFFE79B86);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * 0.2, h * 0.06)
      ..quadraticBezierTo(w * 0.5, -h * 0.02, w * 0.8, h * 0.06)
      ..lineTo(w * 0.95, h * 0.86)
      ..quadraticBezierTo(w * 0.5, h * 1.0, w * 0.05, h * 0.86)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [shade(_color, 0.08), tint(_color, 0.1), shade(_color, 0.12)],
          stops: const [0, 0.4, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipPath(body);
    final stripe = Paint()..color = const Color(0x55FFFFFF);
    for (final y in [0.3, 0.55]) {
      canvas.drawRect(Rect.fromLTWH(0, h * y, w, h * 0.07), stripe);
    }
    canvas.restore();
    // Buza paharului (jos).
    canvas.drawOval(
      Rect.fromLTRB(w * 0.03, h * 0.8, w * 0.97, h * 0.96),
      Paint()..color = shade(_color, 0.18),
    );
    // Lumină pe margine.
    canvas.drawLine(
      Offset(w * 0.3, h * 0.12),
      Offset(w * 0.22, h * 0.72),
      Paint()
        ..color = const Color(0x77FFFFFF)
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CupPainter oldDelegate) => false;
}
