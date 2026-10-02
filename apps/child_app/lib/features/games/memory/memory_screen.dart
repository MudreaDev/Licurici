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
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

class MemoryProgress extends Notifier<int> {
  @override
  int build() => 1;
  void setLevel(int level) => state = level;
}

/// Nivelul curent la Perechi, pe durata aplicației (următorul joc pornește de unde a rămas).
final memoryLevelProvider = NotifierProvider<MemoryProgress, int>(
  MemoryProgress.new,
);

/// Perechi (FEX5): cărțile se întorc în 3D; o pereche găsită rămâne la vedere, luminată.
/// Fără timp, fără penalizări — o pereche greșită se întoarce la loc după o clipă.
class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key, this.game = const MemoryGame(), this.seed});

  final MemoryGame game;

  /// Doar pentru teste (nivel reproductibil).
  final int? seed;

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  late MemoryLevel _level;
  final _up = <int>{};
  final _matched = <int>{};
  final _moves = <MemoryMove>[];
  final _moveClock = Stopwatch();
  int? _first;
  bool _locked = false;
  bool _ready = false;
  MemoryResult? _result;
  String? _sticker;
  int _burst = 0;
  int _reaction = 0;
  MascotMood _mood = MascotMood.idle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(memoryLevelProvider),
      seed: widget.seed,
    );
    _up.clear();
    _matched.clear();
    _moves.clear();
    _first = null;
    _locked = false;
    _result = null;
    _sticker = null;
    _mood = MascotMood.idle;
    _ready = false;
    Future(
      () => mounted ? precacheStimuli(context, _level.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say([_level.instruction]);
    });
  }

  void _tap(int i) {
    if (_locked || _result != null || _matched.contains(i) || _up.contains(i)) {
      return;
    }
    ref.read(sfxProvider).play(Sfx.tap);
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
    final move = MemoryMove(first, i, ms: _moveClock.elapsedMilliseconds);
    _moves.add(move);
    final match = _level.cards[first] == _level.cards[i];
    setState(() {
      _up.add(i);
      _first = null;
      if (match) {
        _matched.addAll([first, i]);
        _burst++;
        _reaction++;
        _mood = MascotMood.happy;
      } else {
        _locked = true;
      }
    });
    if (match) {
      ref.read(sfxProvider).play(Sfx.correct);
      if (_matched.length == _level.cards.length) {
        _timer = Timer(const Duration(milliseconds: 900), _finish);
      }
    } else {
      // O clipă să le vadă pe amândouă, apoi se întorc la loc.
      _timer = Timer(const Duration(milliseconds: 1100), () {
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
    final result = MemoryResult(_level, _moves);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.memoryLevel(result));
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
          .read(memoryLevelProvider.notifier)
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
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          4,
                          16,
                          layout.compact ? 8 : 20,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (layout.twoPane)
                              Mascot(
                                size: layout.mascot,
                                mood: _mood,
                                reaction: _reaction,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _grid(motion)),
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

  Widget _grid(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final n = _level.cards.length;
      final cols = _level.axes.columns;
      final rows = (n / cols).ceil();
      const gap = 12.0;
      const ratio = 0.78; // lățime / înălțime
      final h = math.min(
        (box.maxHeight - gap * (rows - 1)) / rows,
        ((box.maxWidth - gap * (cols - 1)) / cols) / ratio,
      );
      final w = h * ratio;
      return Center(
        child: SizedBox(
          width: w * cols + gap * (cols - 1),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < n; i++)
                _MemoryCard(
                  key: ValueKey('memory-card-$i'),
                  face: _level.cards[i],
                  up: _up.contains(i),
                  matched: _matched.contains(i),
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

/// O carte: spatele (desenat din cod) sau fața (ilustrația), cu întoarcere 3D pe axa Y.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    super.key,
    required this.face,
    required this.up,
    required this.matched,
    required this.width,
    required this.height,
    required this.motion,
    required this.onTap,
  });

  final String face;
  final bool up;
  final bool matched;
  final double width;
  final double height;
  final MotionPolicy motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(math.min(22, width * 0.16));
    final front = DecoratedBox(
      decoration: BoxDecoration(
        color: matched ? Tokens.goodSoft : const Color(0xFFFFFDF8),
        borderRadius: radius,
        border: Border.all(
          color: matched ? Tokens.good : const Color(0xFFEDE3D2),
          width: matched ? 4 : 2,
        ),
        boxShadow: [
          if (matched)
            BoxShadow(
              color: Tokens.good.withValues(alpha: 0.45),
              blurRadius: 18,
            ),
          ...Tokens.shadow,
        ],
      ),
      child: Center(
        child: StimulusArt(face, size: math.min(width, height) * 0.74),
      ),
    );
    final back = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: shade(Tokens.lavender, 0.12),
            offset: const Offset(0, 5),
          ),
          ...Tokens.shadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        // Spatele pictat, dacă există; altfel cel desenat din cod.
        child: IllustrationIndex.has('sprites/card_back')
            ? Image(
                image: illustration('sprites/card_back'),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              )
            : CustomPaint(painter: _CardBackPainter()),
      ),
    );
    return Semantics(
      button: !up && !matched,
      label: up || matched ? 'Carte întoarsă' : 'Carte',
      child: GestureDetector(
        onTap: onTap,
        child: Juice(
          enabled: motion.movement,
          popTick: matched ? 1 : 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: up || matched ? 1 : 0),
            duration: motion.d(320),
            curve: Curves.easeInOutCubic,
            builder: (context, v, _) {
              final showFront = v >= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(math.pi * v),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: showFront
                      // Fața e rotită încă o jumătate de tură, ca să nu apară în oglindă.
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: front,
                        )
                      : back,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Spatele cărților: noapte de lavandă cu un licurici luminos în centru și câteva steluțe.
class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB9B3E0), Color(0xFF8F88C4)],
        ).createShader(rect),
    );
    // Chenar interior subțire, ca la cărțile de joc.
    final inset = size.shortestSide * 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(inset),
        Radius.circular(inset * 1.4),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x88FFFFFF),
    );
    final c = rect.center;
    final r = size.shortestSide * 0.22;
    canvas.drawCircle(
      c,
      r * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xCCFFF1B0), Color(0x00FFF1B0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.8)),
    );
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFFFFF4C2));
    final star = Paint()..color = const Color(0xCCFFFFFF);
    final rnd = math.Random(7);
    for (var i = 0; i < 6; i++) {
      final p = Offset(
        inset * 1.6 + rnd.nextDouble() * (size.width - inset * 3.2),
        inset * 1.6 + rnd.nextDouble() * (size.height - inset * 3.2),
      );
      if ((p - c).distance < r * 1.4) continue;
      canvas.drawCircle(p, size.shortestSide * 0.018, star);
    }
  }

  @override
  bool shouldRepaint(_CardBackPainter oldDelegate) => false;
}
