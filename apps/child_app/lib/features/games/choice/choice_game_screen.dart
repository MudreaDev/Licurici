import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../shared/celebration.dart';
import '../../../shared/emoji_art.dart';
import '../../../shared/juice.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/pressable.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import 'visuals.dart';

/// Mecanica „alege răspunsul” (port din `engine.js`), cu învățare fără eroare și
/// straturile de animație din README §15.1.
class ChoiceGameScreen extends ConsumerStatefulWidget {
  const ChoiceGameScreen({super.key, required this.game});

  final GameSpec game;

  @override
  ConsumerState<ChoiceGameScreen> createState() => _ChoiceGameScreenState();
}

class _ChoiceGameScreenState extends ConsumerState<ChoiceGameScreen> {
  late Lesson _lesson;
  int _index = 0;
  int _attempts = 0;
  int _firstTry = 0;
  bool _solved = false;
  bool _finished = false;
  final Set<int> _wrong = {};
  int? _lastWrong;
  int _wrongTick = 0;

  MascotMood _mood = MascotMood.idle;
  int _reaction = 0;
  String _bubble = '';
  int _burst = 0;
  bool _guide = false;
  Timer? _guideTimer;
  Timer? _advanceTimer;

  ChoiceRound get _round => _lesson.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final s = ref.read(settingsProvider);
    _lesson = widget.game.build(GameContext(
      difficulty: Difficulty.freePlay(s.grade, s.level),
      grade: s.grade,
    ));
    _index = 0;
    _firstTry = 0;
    _finished = false;
    _enterRound();
  }

  void _enterRound() {
    _attempts = 0;
    _solved = false;
    _wrong.clear();
    _lastWrong = null;
    _mood = MascotMood.idle;
    _bubble = _lesson.instruction ?? '';
    _armGuide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(_round.speak);
    });
  }

  /// Stratul 3: după 5 s fără răspuns, ținta corectă pulsează ușor.
  void _armGuide() {
    _guide = false;
    _guideTimer?.cancel();
    _guideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_solved) setState(() => _guide = true);
    });
  }

  void _pick(int i) {
    if (_solved || _wrong.contains(i)) return;
    final choice = _round.choices[i];
    final voice = ref.read(voiceProvider);
    if (choice.correct) {
      if (_attempts == 0) _firstTry++;
      setState(() {
        _solved = true;
        _mood = MascotMood.happy;
        _reaction++;
        _burst++;
        _bubble = 'Bravo!';
        _guide = false;
      });
      _guideTimer?.cancel();
      voice.say([if (choice.spoken != null) choice.spoken!, 'Bravo']);
      _advanceTimer = Timer(const Duration(milliseconds: 1400), _next);
    } else {
      _attempts++;
      setState(() {
        _wrong.add(i);
        _lastWrong = i;
        _wrongTick++;
        _mood = MascotMood.encourage;
        _reaction++;
        // Învățare fără eroare: după a doua greșeală arătăm indiciul și ghidăm spre corect.
        _bubble = _attempts >= 2 && _round.hint != null ? _round.hint! : 'Mai încearcă';
        _guide = _attempts >= 2;
      });
      voice.say([if (choice.spoken != null) choice.spoken!, 'Mai încearcă']);
      if (_attempts < 2) _armGuide();
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      if (_index + 1 >= _lesson.rounds.length) {
        _finished = true;
        _mood = MascotMood.happy;
        _reaction++;
        ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
      } else {
        _index++;
        _enterRound();
      }
    });
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: widget.game.name,
              trailing: BarButton(
                emoji: '🔁',
                label: 'Ascultă din nou',
                onTap: _finished ? null : () => ref.read(voiceProvider).say(_round.speak),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: motion.d(420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: motion.movement
                      ? SlideTransition(
                          position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(anim),
                          child: child,
                        )
                      : child,
                ),
                child: _finished
                    ? _FinishView(
                        key: const ValueKey('finish'),
                        stars: _stars,
                        onAgain: () => setState(_start),
                        onHome: () => context.go('/'),
                      )
                    : _RoundView(
                        key: ValueKey('round-$_index'),
                        round: _round,
                        state: this,
                      ),
              ),
            ),
            _BottomBar(
              total: _lesson.rounds.length,
              index: _finished ? _lesson.rounds.length : _index,
              mood: _mood,
              reaction: _reaction,
              bubble: _finished ? 'Ai terminat! Bravo!' : _bubble,
            ),
          ],
        ),
      ),
    );
  }

  /// Stele: răsplătim și efortul — minimum o stea.
  int get _stars {
    final ratio = _firstTry / _lesson.rounds.length;
    return ratio >= 0.8 ? 3 : (ratio >= 0.5 ? 2 : 1);
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.round, required this.state});

  final ChoiceRound round;
  final _ChoiceGameScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 720;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(round.prompt, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  PromptVisuals(visuals: round.visuals, solved: state._solved),
                  Positioned.fill(child: StarBurst(trigger: state._burst, enabled: motion.particles)),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final (i, c) in round.choices.indexed)
                    _ChoiceCard(
                      key: ValueKey('choice-$i'),
                      choice: c,
                      width: wide ? 180 : 150,
                      faded: state._wrong.contains(i) || (state._solved && !c.correct),
                      solved: state._solved && c.correct,
                      guide: state._guide && c.correct,
                      shakeTick: state._lastWrong == i ? state._wrongTick : 0,
                      onTap: () => state._pick(i),
                    )
                        .animate(delay: motion.d(60 * i))
                        .fadeIn(duration: motion.d(280))
                        .slideY(begin: motion.movement ? 0.25 : 0, end: 0, curve: Curves.easeOutBack),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// O variantă de răspuns. Stări animate: estompată (greșită/eliminată), rezolvată (sare, verde),
/// ghidaj (pulsează), clătinare blândă la greșeală.
class _ChoiceCard extends ConsumerWidget {
  const _ChoiceCard({
    super.key,
    required this.choice,
    required this.width,
    required this.faded,
    required this.solved,
    required this.guide,
    required this.shakeTick,
    required this.onTap,
  });

  final Choice choice;
  final double width;
  final bool faded;
  final bool solved;
  final bool guide;
  final int shakeTick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final hasColor = choice.color != null;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (choice.art != null) EmojiArt(choice.art!, size: 64),
        if (hasColor)
          Container(
            width: width - 56,
            height: 72,
            decoration: BoxDecoration(color: Color(choice.color!), borderRadius: BorderRadius.circular(14)),
          ),
        if (choice.label != null) ...[
          if (choice.art != null) const SizedBox(height: 6),
          Text(
            choice.label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontSize: RegExp(r'^\d+$').hasMatch(choice.label!) ? 44 : 24,
                ),
          ),
        ],
      ],
    );

    Widget card = AnimatedContainer(
      duration: motion.d(260),
      width: width,
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solved ? Tokens.goodSoft : Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(
          color: solved ? Tokens.good : (guide ? Tokens.sun : Tokens.line),
          width: solved || guide ? 4 : 2,
        ),
        boxShadow: faded ? null : Tokens.shadow,
      ),
      child: content,
    );

    card = AnimatedOpacity(opacity: faded ? 0.35 : 1, duration: motion.d(300), child: card);

    return Pressable(
      semanticLabel: choice.spoken ?? choice.label,
      onTap: faded ? null : onTap,
      child: Juice(
        enabled: motion.movement,
        popTick: solved ? 1 : 0,
        shakeTick: shakeTick,
        pulse: guide,
        child: card,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.index,
    required this.mood,
    required this.reaction,
    required this.bubble,
  });

  final int total;
  final int index;
  final MascotMood mood;
  final int reaction;
  final String bubble;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Mascot(size: 96, mood: mood, reaction: reaction),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bubble.isNotEmpty)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous.map((p) => Opacity(opacity: 0, child: p)), ?current],
                      ),
                      child: Container(
                        key: ValueKey(bubble),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Tokens.surface,
                          borderRadius: BorderRadius.circular(Tokens.radiusS),
                          boxShadow: Tokens.shadow,
                        ),
                        child: Text(bubble, style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ProgressDots(total: total, index: index),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Bulinele de progres (stratul 6): cea curentă e mai mare, cele făcute se umplu animat.
class ProgressDots extends ConsumerWidget {
  const ProgressDots({super.key, required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: motion.d(300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.only(right: 8),
            width: i == index ? 26 : 16,
            height: 16,
            decoration: BoxDecoration(
              color: i < index ? Tokens.good : (i == index ? Tokens.primary : Tokens.line),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

/// Finalul (stratul 7): stelele zboară una câte una, mascota se bucură.
class _FinishView extends ConsumerWidget {
  const _FinishView({super.key, required this.stars, required this.onAgain, required this.onHome});

  final int stars;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ai terminat! Bravo!', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Opacity(
                      opacity: i < stars ? 1 : 0.25,
                      child: const EmojiArt('⭐', size: 96)
                          .animate(delay: motion.d(250 + 350 * i))
                          .fadeIn(duration: motion.d(200))
                          .scaleXY(
                            begin: motion.movement ? 0.2 : 1,
                            end: 1,
                            duration: motion.d(500),
                            curve: Curves.elasticOut,
                          )
                          .rotate(begin: motion.movement ? -0.15 : 0, end: 0),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _BigButton(emoji: '🔁', label: 'Încă o dată', color: Tokens.primary, onTap: onAgain),
                _BigButton(emoji: '🏠', label: 'Acasă', color: Tokens.mint, onTap: onHome),
              ],
            ).animate(delay: motion.d(1300)).fadeIn(duration: motion.d(300)),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.emoji, required this.label, required this.color, required this.onTap});

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        semanticLabel: label,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Tokens.tap, minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Tokens.radius),
            boxShadow: Tokens.shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiArt(emoji, size: 40),
              const SizedBox(width: 12),
              Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Colors.white)),
            ],
          ),
        ),
      );
}

/// Unghi mic aleator stabil pentru un index (folosit la dispunerea „jucăușă” a obiectelor).
double wobble(int i) => math.sin(i * 12.9898) * 0.08;
