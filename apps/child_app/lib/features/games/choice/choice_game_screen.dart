import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../shared/art_cache.dart';
import '../../../shared/celebration.dart';
import '../../../shared/emoji_art.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/pressable.dart';
import '../../../shared/role_fx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../../therapy/trial_log.dart';
import 'visuals.dart';

/// Mecanica „alege răspunsul” (port din `engine.js`), cu învățare fără eroare, ierarhia de
/// ajutor P0–P4 (plan §3.3), înregistrarea încercărilor și straturile de animație din §15.1.
class ChoiceGameScreen extends ConsumerStatefulWidget {
  const ChoiceGameScreen({super.key, required this.game});

  final GameSpec game;

  @override
  ConsumerState<ChoiceGameScreen> createState() => _ChoiceGameScreenState();
}

class _ChoiceGameScreenState extends ConsumerState<ChoiceGameScreen> {
  late Lesson _lesson;
  late String _sessionId;
  int _index = 0;
  int _attempts = 0;
  int _firstTry = 0;
  bool _solved = false;
  bool _finished = false;

  /// Ilustrațiile lecției sunt pre-încărcate (vezi [_start]).
  bool _ready = false;
  final Set<int> _wrong = {};

  MascotMood _mood = MascotMood.idle;
  int _reaction = 0;
  String _bubble = '';
  int _burst = 0;
  Timer? _advanceTimer;

  // Ierarhia de ajutor (plan §3.3): strategia și planul rundei, nivelul curent și cel maxim.
  PromptStrategy _strategy = const PromptStrategy();
  PromptPlan _plan = const PromptPlan();
  PromptLevel _level = PromptLevel.p0;
  PromptLevel _maxLevel = PromptLevel.p0;
  bool _hintSpoken = false;

  /// Ceasul injectabil (`package:clock`): în teste merge pe timpul simulat.
  final Stopwatch _watch = clock.stopwatch();
  int? _latencyMs;
  Timer? _promptTimer;

  ChoiceRound get _round => _lesson.rounds[_index];

  /// Treapta rundei (jocurile vechi, fără treaptă, se înregistrează pe id-ul jocului).
  String get _stepId => _round.tag?.stepId ?? widget.game.id;

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
    _sessionId = newSessionId();
    _index = 0;
    _firstTry = 0;
    _finished = false;
    _ready = false;
    // Pre-încărcăm ilustrațiile ÎNAINTE de prima rundă: animațiile de intrare pornesc cu
    // imaginile deja în memorie (durează de obicei sub 100 ms).
    precacheArt(_lesson.art).whenComplete(() {
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
    _mood = MascotMood.idle;
    _bubble = _lesson.instruction ?? '';
    _hintSpoken = false;
    _latencyMs = null;

    // Treptele noi pornesc cu ajutor mult, care se estompează; jocul liber fără treaptă pornește
    // fără ajutor și îl crește doar la greșeli sau pauze.
    final history = ref.read(trialLogProvider).forStep(_stepId);
    _strategy = _round.tag?.stepId == null
        ? const PromptStrategy()
        : PromptStrategy.defaultFor(history);
    _plan = _strategy.planFor(history);
    _maxLevel = PromptLevel.p0;
    _applyLevel(_strategy.levelAt(_plan, elapsed: Duration.zero));
    _watch
      ..reset()
      ..start();
    _promptTimer?.cancel();
    _promptTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tickPrompt(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(_round.speak);
    });
  }

  /// Recalculează ajutorul după timp și greșeli; reconstruiește doar când se schimbă nivelul.
  void _tickPrompt() {
    if (!mounted || _solved) return;
    final level = _strategy.levelAt(
      _plan,
      elapsed: _watch.elapsed,
      errors: _attempts,
    );
    if (level != _level) setState(() => _applyLevel(level));
  }

  void _applyLevel(PromptLevel level) {
    _level = level;
    _maxLevel = PromptLevel.max(_maxLevel, level);
    // P1: indiciul neutru, afișat și rostit o singură dată pe rundă.
    if (level >= PromptLevel.p1 && _round.hint != null) {
      _bubble = _round.hint!;
      if (!_hintSpoken) {
        _hintSpoken = true;
        final hint = _round.hint!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(voiceProvider).say([hint]);
        });
      }
    }
  }

  /// Distractorul care rămâne activ la P2 (reducerea variantelor): primul încă neatins.
  int? get _keptDistractor {
    for (final (i, c) in _round.choices.indexed) {
      if (!c.correct && !_wrong.contains(i)) return i;
    }
    return null;
  }

  /// Rolul fiecărei variante (efectele vin din rol, ADR-028; ajutorul P2–P4 tot prin rol).
  FxRole _roleOf(int i) {
    final correct = _round.choices[i].correct;
    if (_wrong.contains(i)) return FxRole.rejected;
    if (_solved) return correct ? FxRole.correct : FxRole.faded;
    if (correct) {
      if (_level >= PromptLevel.p4) return FxRole.modeled;
      if (_level >= PromptLevel.p3) return FxRole.hinted;
      return FxRole.target;
    }
    return _level >= PromptLevel.p2 && i != _keptDistractor
        ? FxRole.faded
        : FxRole.target;
  }

  void _pick(int i) {
    if (_solved || _wrong.contains(i)) return;
    _latencyMs ??= _watch.elapsedMilliseconds;
    final choice = _round.choices[i];
    final voice = ref.read(voiceProvider);
    if (choice.correct) {
      if (_attempts == 0) _firstTry++;
      _record();
      _watch.stop();
      _promptTimer?.cancel();
      setState(() {
        _solved = true;
        _mood = MascotMood.happy;
        _reaction++;
        _burst++;
        _bubble = 'Bravo!';
      });
      voice.say([if (choice.spoken != null) choice.spoken!, 'Bravo']);
      _advanceTimer = Timer(const Duration(milliseconds: 1400), _next);
    } else {
      _attempts++;
      setState(() {
        _wrong.add(i);
        _mood = MascotMood.encourage;
        _reaction++;
        _bubble = 'Mai încearcă';
        // Învățare fără eroare: fiecare greșeală urcă ajutorul un nivel (indiciu → mai puține
        // variante → indicare → mâna care arată), până la plafonul strategiei.
        _applyLevel(
          _strategy.levelAt(_plan, elapsed: _watch.elapsed, errors: _attempts),
        );
      });
      voice.say([if (choice.spoken != null) choice.spoken!, 'Mai încearcă']);
    }
  }

  /// Încercarea (plan §4.1), cu nivelul exact al rundei (seed, axe) dacă e generată procedural.
  void _record() {
    final tag = _round.tag;
    final log = ref.read(trialLogProvider.notifier);
    log.add(
      Trial(
        sessionId: _sessionId,
        stepId: _stepId,
        gameId: widget.game.id,
        correct: _attempts == 0,
        attempts: _attempts + 1,
        promptLevel: _maxLevel,
        latencyMs: _latencyMs,
        seed: tag?.seed,
        config: tag?.config ?? const {},
        axes: {
          for (final MapEntry(:key, :value) in (tag?.axes ?? const {}).entries)
            key: value.toDouble(),
        },
        rating: tag?.difficulty == null
            ? null
            : ref.read(trialLogProvider).ratingOf(_stepId).value,
        stimulusId: tag?.stimulusId,
        stimulusSet: tag?.stimulusSet,
        mode: TrialMode.liber,
        at: clock.now(),
      ),
      difficulty: tag?.difficulty,
    );
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
    _promptTimer?.cancel();
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
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: widget.game.name,
              trailing: BarButton(
                emoji: '🔁',
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
                              reserveBottom: corner,
                            ),
                    ),
                  ),
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
    final prompt = Text(
      round.prompt,
      style: layout.compact ? text.headlineMedium : text.displaySmall,
      textAlign: TextAlign.center,
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
              index: i,
              choice: c,
              width: width,
              compact: layout.compact,
              role: state._roleOf(i),
              onTap: () => state._pick(i),
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
    required this.index,
    required this.choice,
    required this.width,
    required this.compact,
    required this.role,
    required this.onTap,
  });

  final int index;
  final Choice choice;
  final double width;
  final bool compact;
  final FxRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final solved = role == FxRole.correct;
    final guide = role == FxRole.hinted || role == FxRole.modeled;
    final faded = role == FxRole.rejected || role == FxRole.faded;
    final hasColor = choice.color != null;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (choice.art != null) EmojiArt(choice.art!, size: compact ? 44 : 64),
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
                  EmojiArt(
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
                  : (compact ? 20 : 24),
            ),
          ),
        ],
      ],
    );

    final Widget card = AnimatedContainer(
      duration: motion.d(260),
      width: width,
      constraints: BoxConstraints(minHeight: compact ? 68 : 130),
      padding: EdgeInsets.all(compact ? 8 : 14),
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

    // Animația vine din rol (apăsare, pop, tremur, pulsare, estompare, intrare eșalonată).
    return RoleFx(
      role: role,
      index: index,
      semanticLabel: choice.spoken ?? choice.label,
      onTap: onTap,
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
                  child: Container(
                    key: ValueKey(bubble),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.surface,
                      borderRadius: BorderRadius.circular(Tokens.radiusS),
                      boxShadow: Tokens.shadow,
                    ),
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
              color: i < index
                  ? Tokens.good
                  : (i == index ? Tokens.primary : Tokens.line),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

/// Finalul (stratul 7): stelele zboară una câte una, mascota se bucură.
class _FinishView extends ConsumerWidget {
  const _FinishView({
    super.key,
    required this.stars,
    required this.onAgain,
    required this.onHome,
  });

  final int stars;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ai terminat! Bravo!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            SizedBox(height: compact ? 10 : 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Opacity(
                      opacity: i < stars ? 1 : 0.25,
                      child: RoleFx(
                        role: FxRole.reward,
                        index: i,
                        child: EmojiArt('⭐', size: compact ? 64 : 96),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 16 : 36),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _BigButton(
                  emoji: '🔁',
                  label: 'Încă o dată',
                  color: Tokens.primary,
                  onTap: onAgain,
                ),
                _BigButton(
                  emoji: '🏠',
                  label: 'Acasă',
                  color: Tokens.mint,
                  onTap: onHome,
                ),
              ],
            ).animate(delay: motion.d(1300)).fadeIn(duration: motion.d(300)),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge!.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// Unghi mic aleator stabil pentru un index (folosit la dispunerea „jucăușă” a obiectelor).
double wobble(int i) => math.sin(i * 12.9898) * 0.08;
