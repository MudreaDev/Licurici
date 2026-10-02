import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../data/session.dart';
import '../../../app/theme.dart';
import '../../../shared/celebration.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/juice.dart';
import '../../../shared/mascot.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/sfx.dart';
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

  /// Abțibildul primit la final.
  String? _sticker;

  /// Ilustrațiile lecției sunt pre-încărcate (vezi [_start]).
  bool _ready = false;
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

  // Măsurătorile încercării (plan §4.1): latența până la primul răspuns, prima variantă
  // greșită aleasă (confuzii) și dacă a apărut ghidajul vizual (ajutor P3).
  final _roundClock = Stopwatch();
  int? _latencyMs;
  String? _firstWrongKey;
  bool _guideShown = false;

  ChoiceRound get _round => _lesson.rounds[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final s = ref.read(settingsProvider);
    _lesson = widget.game.build(
      GameContext(
        difficulty: Difficulty.freePlay(s.grade, s.level),
        grade: s.grade,
      ),
    );
    _index = 0;
    _firstTry = 0;
    _finished = false;
    _ready = false;
    // Pre-încărcăm ilustrațiile ÎNAINTE de prima rundă: animațiile de intrare pornesc cu
    // imaginile deja în memorie (durează de obicei sub 100 ms).
    // (după montare: ilustrațiile pictate au nevoie de context)
    Future(
      () => mounted ? precacheStimuli(context, _lesson.art) : null,
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _enterRound();
      });
    });
  }

  void _enterRound() {
    _attempts = 0;
    _solved = false;
    _wrong.clear();
    _lastWrong = null;
    _latencyMs = null;
    _firstWrongKey = null;
    _guideShown = false;
    _roundClock
      ..reset()
      ..start();
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
      if (mounted && !_solved) {
        setState(() => _guide = _guideShown = true);
      }
    });
  }

  void _pick(int i) {
    if (_solved || _wrong.contains(i)) return;
    final choice = _round.choices[i];
    final voice = ref.read(voiceProvider);
    _latencyMs ??= _roundClock.elapsedMilliseconds;
    if (choice.correct) {
      ref.read(sfxProvider).play(Sfx.correct);
      if (_attempts == 0) _firstTry++;
      final round = _round;
      ref
          .read(sessionProvider.notifier)
          .record(
            (r) => r.choiceRound(
              gameId: widget.game.id,
              round: round,
              wrongAttempts: _attempts,
              guideShown: _guideShown,
              latencyMs: _latencyMs!,
              chosenKey: _firstWrongKey,
            ),
          );
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
      _firstWrongKey ??= choice.key;
      setState(() {
        _wrong.add(i);
        _lastWrong = i;
        _wrongTick++;
        _mood = MascotMood.encourage;
        _reaction++;
        // Învățare fără eroare: după a doua greșeală arătăm indiciul și ghidăm spre corect.
        _bubble = _attempts >= 2 && _round.hint != null
            ? _round.hint!
            : 'Mai încearcă';
        _guide = _attempts >= 2;
        _guideShown |= _guide;
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
        _sticker = ref.read(settingsProvider.notifier).awardSticker();
        ref.read(sessionProvider.notifier).checkpoint();
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
    final layout = AppLayout.of(context);
    // Spațiul rezervat colțului cu mascota (strat fix, care nu se schimbă între runde).
    final corner = layout.mascot + 12;
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, 1),
        kind: SceneKind.meadow,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: widget.game.name,
                trailing: BarButton(
                  icon: Icons.replay_rounded,
                  color: Tokens.mint,
                  label: 'Ascultă din nou',
                  onTap: _finished || !_ready
                      ? null
                      : () => ref.read(voiceProvider).say(_round.speak),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: motion.d(420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: motion.movement
                              ? SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0.12, 0),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                )
                              : child,
                        ),
                        child: !_ready
                            ? const SizedBox.shrink(key: ValueKey('loading'))
                            : _finished
                            ? RewardFinish(
                                key: const ValueKey('finish'),
                                stars: _stars,
                                sticker: _sticker,
                                actions: [
                                  FinishAction(
                                    'Încă o dată',
                                    Icons.replay_rounded,
                                    Tokens.primary,
                                    () => setState(_start),
                                  ),
                                  FinishAction(
                                    'Acasă',
                                    Icons.home_rounded,
                                    Tokens.good,
                                    () => context.go('/'),
                                  ),
                                ],
                              )
                            : _RoundView(
                                key: ValueKey('round-$_index'),
                                round: _round,
                                state: this,
                                reserveBottom: corner,
                              ),
                      ),
                    ),
                    if (!_finished)
                      Positioned(
                        left: 12,
                        bottom: 6,
                        // Cu două panouri, colțul rămâne sub panoul din stânga.
                        width: layout.twoPane ? layout.size.width * 0.5 : null,
                        right: layout.twoPane ? null : 12,
                        child: _MascotCorner(
                          size: layout.mascot,
                          total: _lesson.rounds.length,
                          index: _finished ? _lesson.rounds.length : _index,
                          mood: _mood,
                          reaction: _reaction,
                          bubble: _finished
                              ? 'Ai terminat! Bravo!'
                              : (_ready ? _bubble : ''),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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

/// O rundă. Landscape (implicit): stimulul în stânga, variantele în dreapta; stimulul se
/// micșorează ca să încapă pe telefon. Pe ecrane înalte (fereastră îngustă): coloană.
class _RoundView extends ConsumerWidget {
  const _RoundView({
    super.key,
    required this.round,
    required this.state,
    required this.reserveBottom,
  });

  final ChoiceRound round;
  final _ChoiceGameScreenState state;
  final double reserveBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final text = Theme.of(context).textTheme;
    final stageColor = switch (catalogEntry(state.widget.game.id)) {
      final e? => domainColor(e.domain),
      null => Tokens.mint,
    };
    final prompt = OutlinedTitle(
      round.prompt,
      style: layout.compact ? text.headlineMedium : text.displaySmall,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
    final visuals = Stack(
      alignment: Alignment.center,
      children: [
        PromptVisuals(visuals: round.visuals, solved: state._solved),
        Positioned.fill(
          child: StarBurst(trigger: state._burst, enabled: motion.particles),
        ),
      ],
    );

    Widget choices(double maxWidth) {
      final n = round.choices.length;
      final columns = layout.twoPane ? (n <= 1 ? 1 : 2) : n;
      const gap = 12.0;
      final width = ((maxWidth - gap * (columns - 1)) / columns).clamp(
        96.0,
        layout.compact ? 200.0 : 260.0,
      );
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (i, c) in round.choices.indexed)
            _ChoiceCard(
                  key: ValueKey('choice-$i'),
                  choice: c,
                  width: width,
                  compact: layout.compact,
                  faded:
                      state._wrong.contains(i) || (state._solved && !c.correct),
                  solved: state._solved && c.correct,
                  guide: state._guide && c.correct,
                  shakeTick: state._lastWrong == i ? state._wrongTick : 0,
                  onTap: () => state._pick(i),
                )
                .animate(delay: motion.d(60 * i))
                .fadeIn(duration: motion.d(280))
                .slideX(
                  begin: motion.movement ? 0.2 : 0,
                  end: 0,
                  curve: Curves.easeOutBack,
                ),
        ],
      );
    }

    if (layout.twoPane) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: EdgeInsets.only(bottom: reserveBottom),
                child: Column(
                  children: [
                    prompt,
                    SizedBox(height: layout.compact ? 4 : 12),
                    Expanded(
                      // „Scena” stimulului: un panou cald, ca o pagină de carte.
                      child: CandyPanel(
                        padding: EdgeInsets.all(layout.compact ? 8 : 16),
                        // O nuanță foarte ușoară a ariei jocului, ca pagina să aibă „culoarea” lui.
                        color: Color.lerp(
                          const Color(0xFFFFFBF4),
                          stageColor,
                          0.12,
                        )!,
                        opacity: 0.92,
                        child: LayoutBuilder(
                          // Scara după înălțimea rămasă: ~280 dp = 1×; tabletă până la 1,5×.
                          // FittedBox rămâne plasa de siguranță dacă tot nu încape.
                          builder: (context, box) => VisualScale(
                            scale: (box.maxHeight / 280).clamp(0.6, 1.5),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: visuals,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 9,
              child: LayoutBuilder(
                builder: (context, box) => Center(
                  child: SingleChildScrollView(child: choices(box.maxWidth)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, reserveBottom + 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight - reserveBottom - 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              prompt,
              const SizedBox(height: 16),
              visuals,
              const SizedBox(height: 28),
              choices(box.maxWidth - 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// O variantă de răspuns. Stări animate: estompată (greșită/eliminată), rezolvată (sare, verde),
/// ghidaj (pulsează), clătinare blândă la greșeală.
class _ChoiceCard extends ConsumerWidget {
  const _ChoiceCard({
    super.key,
    required this.choice,
    required this.width,
    required this.compact,
    required this.faded,
    required this.solved,
    required this.guide,
    required this.shakeTick,
    required this.onTap,
  });

  final Choice choice;
  final double width;
  final bool compact;
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
        if (choice.art != null)
          StimulusArt(choice.art!, size: compact ? 52 : 84),
        if (choice.objects case final g?)
          // Grupă de obiecte (ex. „Comparăm”): rânduri de câte 5, ca pe o numărătoare.
          SizedBox(
            width: width - 28,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 3,
              children: [
                for (var i = 0; i < g.count; i++)
                  StimulusArt(
                    g.emoji,
                    size: ((width - 28) / 5.6).clamp(
                      14.0,
                      compact ? 26.0 : 36.0,
                    ),
                  ),
              ],
            ),
          ),
        if (hasColor)
          Container(
            width: width - 56,
            height: compact ? 44 : 72,
            decoration: BoxDecoration(
              color: Color(choice.color!),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        if (choice.label != null) ...[
          if (choice.art != null || choice.objects != null)
            const SizedBox(height: 6),
          Text(
            choice.label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: RegExp(r'^\d+$').hasMatch(choice.label!)
                  ? (compact ? 34 : 44)
                  : (compact ? 22 : 28),
            ),
          ),
        ],
      ],
    );

    final border = solved ? Tokens.good : (guide ? Tokens.sun : null);
    Widget card = CandyPressable(
      color: solved ? Tokens.goodSoft : const Color(0xFFFFFDF8),
      lipColor: solved
          ? shade(Tokens.good, 0.05)
          : (guide ? shade(Tokens.sun, 0.05) : const Color(0xFFE3D9C6)),
      radius: Tokens.radius,
      lip: compact ? 5 : 7,
      border: border,
      borderWidth: border == null ? 0 : 4,
      semanticLabel: choice.spoken ?? choice.label,
      onTap: faded ? null : onTap,
      width: width,
      padding: EdgeInsets.all(compact ? 8 : 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 56 : 112),
        child: Center(child: content),
      ),
    );

    card = AnimatedOpacity(
      opacity: faded ? 0.35 : 1,
      duration: motion.d(300),
      child: card,
    );

    return Juice(
      enabled: motion.movement,
      popTick: solved ? 1 : 0,
      shakeTick: shakeTick,
      pulse: guide,
      child: card,
    );
  }
}

/// Colțul fix cu mascota, balonul de text și bulinele de progres. Stă peste runde (nu se
/// reconstruiește la fiecare rundă), ca reacțiile mascotei să nu fie întrerupte.
class _MascotCorner extends StatelessWidget {
  const _MascotCorner({
    required this.size,
    required this.total,
    required this.index,
    required this.mood,
    required this.reaction,
    required this.bubble,
  });

  final double size;
  final int total;
  final int index;
  final MascotMood mood;
  final int reaction;
  final String bubble;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Mascot(size: size, mood: mood, reaction: reaction),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bubble.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ...previous.map((p) => Opacity(opacity: 0, child: p)),
                      ?current,
                    ],
                  ),
                  child: SpeechBubble(
                    key: ValueKey(bubble),
                    tail: BubbleTail.left,
                    child: Text(
                      bubble,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ProgressDots(total: total, index: index),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Progresul (stratul 6): câte o steluță pe rundă, într-o pastilă. Cele făcute se aprind
/// aurii, cea curentă e mai mare și albastră, restul sunt pale.
class ProgressDots extends ConsumerWidget {
  const ProgressDots({super.key, required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    final base = compact ? 20.0 : 26.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFDF8),
        borderRadius: BorderRadius.circular(999),
        boxShadow: Tokens.shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedScale(
              scale: i == index ? 1.3 : 1,
              duration: motion.d(300),
              curve: Curves.easeOutBack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.star_rounded,
                  size: base,
                  color: i < index
                      ? const Color(0xFFF2C14E)
                      : (i == index ? Tokens.primary : const Color(0xFFDCD5C8)),
                  shadows: i < index
                      ? const [Shadow(color: Color(0x66F2C14E), blurRadius: 8)]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Unghi mic aleator stabil pentru un index (folosit la dispunerea „jucăușă” a obiectelor).
double wobble(int i) => math.sin(i * 12.9898) * 0.08;
