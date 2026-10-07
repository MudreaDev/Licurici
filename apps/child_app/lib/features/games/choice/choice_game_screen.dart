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
import '../../../shared/placement_art.dart';
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

  /// Strategia de ajutor (plan §3.3): pe o treaptă nouă răspunsul corect e arătat de la
  /// început, iar întârzierea crește cu fiecare reușită din prima (0 s → 2 s → 4 s);
  /// pe o treaptă cunoscută, indiciul vine doar după 5 s fără răspuns.
  PromptStrategy _strategy = PromptStrategy.leastToMost;
  static const _newStep = PromptLadder(strategy: PromptStrategy.mostToLeast);

  /// Runde reușite la rând din prima încercare (pentru întârzierea progresivă).
  int _errorFree = 0;

  /// Steluța care zboară de la răspunsul corect în bara de progres.
  final _stackKey = GlobalKey();
  final _progressKey = GlobalKey();
  final _cardKeys = List.generate(6, (_) => GlobalKey());
  ({Offset from, Offset to, int tick})? _flight;
  int _flights = 0;

  /// Mânuța care arată răspunsul (P4).
  bool _hand = false;
  bool _handShown = false;
  Timer? _handTimer;
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
    _errorFree = 0;
    _finished = false;
    _ready = false;
    // Treaptă nouă sau cunoscută: din sesiunile salvate + sesiunea în curs.
    final current = ref.read(sessionProvider);
    final history = ref.read(sessionStoreProvider).all().then((saved) {
      if (!mounted) return;
      _strategy = promptStrategyFor(widget.game.id, [
        ...saved,
        if (current != null)
          SessionRecord(
            id: current.id,
            childId: current.childId,
            start: current.start,
            end: DateTime.now(),
            trials: current.trials,
            events: const [],
          ),
      ]);
    }, onError: (_) {});
    // Pre-încărcăm ilustrațiile ÎNAINTE de prima rundă: animațiile de intrare pornesc cu
    // imaginile deja în memorie (durează de obicei sub 100 ms).
    // (după montare: ilustrațiile pictate au nevoie de context)
    Future.wait([
      Future(() => mounted ? precacheStimuli(context, _lesson.art) : null),
      history,
    ]).whenComplete(() {
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
    _hand = _handShown = false;
    _handTimer?.cancel();
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

  /// Stratul 3: ținta corectă pulsează ușor — după 5 s fără răspuns pe o treaptă cunoscută,
  /// sau după întârzierea progresivă (0 s → 2 s → 4 s) pe o treaptă nouă.
  void _armGuide() {
    _guide = false;
    _guideTimer?.cancel();
    final delay = _strategy == PromptStrategy.mostToLeast
        ? Duration(milliseconds: _newStep.delayMs(independentStreak: _errorFree))
        : const Duration(seconds: 5);
    _guideTimer = Timer(delay, () {
      if (mounted && !_solved) {
        setState(() => _guide = _guideShown = true);
        _armHand();
      }
    });
  }

  /// Ultima treaptă de ajutor (P4, model complet): dacă nici pulsarea nu ajunge, o mânuță
  /// arată răspunsul după încă 5 s. Ajutorul crește treptat, ca în învățarea fără eroare.
  void _armHand([Duration after = const Duration(seconds: 5)]) {
    _handTimer?.cancel();
    _handTimer = Timer(after, () {
      if (mounted && !_solved) setState(() => _hand = _handShown = true);
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
      _errorFree = _attempts == 0 ? _errorFree + 1 : 0;
      final round = _round;
      ref
          .read(sessionProvider.notifier)
          .record(
            (r) => r.choiceRound(
              gameId: widget.game.id,
              round: round,
              wrongAttempts: _attempts,
              guideShown: _guideShown,
              handShown: _handShown,
              latencyMs: _latencyMs!,
              chosenKey: _firstWrongKey,
            ),
          );
      _launchStar(i);
      setState(() {
        _solved = true;
        _mood = MascotMood.happy;
        _reaction++;
        _burst++;
        _bubble = 'Bravo!';
        _guide = false;
        _hand = false;
      });
      _guideTimer?.cancel();
      _handTimer?.cancel();
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
        // A treia greșeală: mânuța apare imediat.
        if (_attempts >= 3) _hand = _handShown = true;
      });
      voice.say([if (choice.spoken != null) choice.spoken!, 'Mai încearcă']);
      if (_attempts < 2) {
        _armGuide();
      } else if (!_hand) {
        _armHand();
      }
    }
  }

  /// Pornește zborul steluței (centrele, în coordonatele stivei ecranului).
  void _launchStar(int card) {
    final motion = MotionPolicy.of(context, ref);
    if (!motion.movement) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    Offset? centerOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || stack == null || !box.hasSize) return null;
      return box.localToGlobal(box.size.center(Offset.zero), ancestor: stack);
    }

    final from = card < _cardKeys.length ? centerOf(_cardKeys[card]) : null;
    final to = centerOf(_progressKey);
    if (from == null || to == null) return;
    _flight = (from: from, to: to, tick: ++_flights);
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
    _handTimer?.cancel();
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
                  key: _stackKey,
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
                        // Cu două panouri, colțul stă sub panoul din stânga; pe telefon (scund) stă
                        // sub variante, ca stimulul să aibă toată înălțimea.
                        left: layout.twoPane && layout.compact ? layout.size.width * 0.56 : 12,
                        bottom: 6,
                        width: layout.twoPane ? layout.size.width * (layout.compact ? 0.42 : 0.5) : null,
                        right: layout.twoPane ? null : 12,
                        child: _MascotCorner(
                          size: layout.mascot,
                          total: _lesson.rounds.length,
                          index: _finished ? _lesson.rounds.length : _index,
                          mood: _mood,
                          reaction: _reaction,
                          // Pe telefon balonul n-are loc lângă variante; vocea spune oricum
                          // instrucțiunea.
                          bubble: _finished
                              ? 'Ai terminat! Bravo!'
                              : (_ready && !(layout.twoPane && layout.compact) ? _bubble : ''),
                          progressKey: _progressKey,
                        ),
                      ),
                    if (_flight case final f? when !_finished)
                      _FlyingStar(
                        key: ValueKey('flight-${f.tick}'),
                        from: f.from,
                        to: f.to,
                        onDone: () => setState(() => _flight = null),
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

    // Variantele care sunt doar o imagine (ex. „Arată mingea”) au imaginea cât mai mare:
    // cât permite celula, nu o mărime fixă.
    final artOnly = round.choices.every(
      (c) =>
          (c.art != null || c.placement != null) &&
          c.label == null &&
          c.objects == null,
    );

    Widget choices(double maxWidth, {double? maxHeight, int? fixedColumns}) {
      final n = round.choices.length;
      final columns = fixedColumns ?? (layout.twoPane ? (n <= 1 ? 1 : 2) : n);
      const gap = 12.0;
      final width = ((maxWidth - gap * (columns - 1)) / columns).clamp(
        96.0,
        layout.compact ? 200.0 : 260.0,
      );
      double? artSize;
      if (artOnly) {
        final rows = (n / columns).ceil();
        final pad = layout.compact ? 16.0 : 28.0;
        final cellHeight = maxHeight == null
            ? double.infinity
            : (maxHeight - gap * (rows - 1)) / rows - pad - 10;
        artSize = math
            .min(width - pad, cellHeight)
            .clamp(
              layout.compact ? 52.0 : 84.0,
              layout.compact ? 120.0 : 190.0,
            );
      }
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (i, c) in round.choices.indexed)
            KeyedSubtree(
              key: i < state._cardKeys.length ? state._cardKeys[i] : null,
              child:
                  _ChoiceCard(
                        key: ValueKey('choice-$i'),
                        choice: c,
                        width: width,
                        artSize: artSize,
                        compact: layout.compact,
                        faded:
                            state._wrong.contains(i) ||
                            (state._solved && !c.correct),
                        solved: state._solved && c.correct,
                        guide: state._guide && c.correct,
                        hand: state._hand && c.correct,
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
            ),
        ],
      );
    }

    // Fără stimul (ex. „Intrusul”: chiar variantele sunt întrebarea) — fără panou gol:
    // variantele ocupă toată scena, pe un rând sau două.
    if (layout.twoPane && round.visuals.isEmpty) {
      final n = round.choices.length;
      return Padding(
        // Variantele trec pe toată lățimea, deci și peste colțul mascotei: lăsăm loc și
        // pentru balonul de text (pe telefon are două rânduri).
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          8 + reserveBottom + (layout.compact ? 44 : 24),
        ),
        child: Column(
          children: [
            prompt,
            SizedBox(height: layout.compact ? 4 : 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Center(
                  child: SingleChildScrollView(
                    child: choices(
                      math.min(box.maxWidth, n <= 4 ? 4 * 230.0 : 3 * 230.0),
                      maxHeight: box.maxHeight,
                      fixedColumns: n <= 4 ? n : (n / 2).ceil(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                // Pe telefon, balonul mascotei are adesea două rânduri: îi lăsăm loc.
                padding: EdgeInsets.only(
                  bottom: layout.compact ? 4 : reserveBottom,
                ),
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
                            scale: (box.maxHeight / 240).clamp(0.75, 1.5),
                            box: box.biggest,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                // Lățimea panoului rămâne limita: grupurile de obiecte trec pe
                                // rândul următor în loc să se micșoreze toate pe un singur rând.
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: box.maxWidth,
                                  ),
                                  child: visuals,
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
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 9,
              child: Padding(
                // Pe telefon, Licurici și balonul lui stau sub variante.
                padding: EdgeInsets.only(bottom: layout.compact ? reserveBottom - 8 : 0),
                child: LayoutBuilder(
                  builder: (context, box) => Center(
                    child: SingleChildScrollView(
                      child: choices(box.maxWidth, maxHeight: box.maxHeight),
                    ),
                  ),
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
    this.artSize,
    required this.compact,
    required this.faded,
    required this.solved,
    required this.guide,
    required this.hand,
    required this.shakeTick,
    required this.onTap,
  });

  final Choice choice;
  final double width;

  /// Mărimea imaginii când varianta e doar o imagine (altfel mărimea implicită).
  final double? artSize;
  final bool compact;
  final bool faded;
  final bool solved;
  final bool guide;
  final bool hand;
  final int shakeTick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final hasColor = choice.color != null;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (choice.art case final art?)
          // Locul imaginii rămâne cât una întreagă: „mic” se vede mic în aceeași cartelă.
          SizedBox.square(
            dimension: artSize ?? (compact ? 52 : 84),
            child: Center(
              child: choice.silhouette && !solved
                  ? Silhouette(
                      child: StimulusArt(
                        art,
                        size: (artSize ?? (compact ? 52 : 84)) * choice.scale,
                      ),
                    )
                  : StimulusArt(
                      art,
                      size: (artSize ?? (compact ? 52 : 84)) * choice.scale,
                    ),
            ),
          ),
        if (choice.placement case final p?)
          PlacementArt(p, size: (artSize ?? (compact ? 84 : 130)) * 1.1),
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
          _FitLabel(
            choice.label!,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: RegExp(r'^(\d+|[<>=])$').hasMatch(choice.label!)
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

    // Răspunsul corect primește o bifă verde care „sare” în colț (semn clar, fără text).
    card = Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: -8,
          top: -8,
          child: AnimatedScale(
            scale: solved ? 1 : 0,
            duration: motion.d(350),
            curve: Curves.elasticOut,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Tokens.good,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: Tokens.shadow,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: compact ? 22 : 30,
              ),
            ),
          ),
        ),
        if (hand)
          Positioned(
            right: -10,
            bottom: -14,
            child: IgnorePointer(child: PointingHand(size: compact ? 52 : 72)),
          ),
      ],
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
    this.progressKey,
  });

  final Key? progressKey;

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
              ProgressDots(key: progressKey, total: total, index: index),
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

/// Mânuța care „apasă” pe răspunsul corect (P4): coboară și urcă încet, ca un deget care
/// arată. Ilustrația pictată (`sprites/hand`) dacă există, altfel iconița.
class PointingHand extends ConsumerWidget {
  const PointingHand({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final sprite = spriteFor('👆');
    Widget hand = sprite != null
        ? SizedBox.square(
            dimension: size,
            child: Image(image: sprite, fit: BoxFit.contain),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Tokens.sun, width: 3),
              boxShadow: Tokens.shadow,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: size * 0.62,
              color: Tokens.primaryDark,
            ),
          );
    hand = Semantics(label: 'Aici', child: hand);
    if (!motion.feedback) return hand;
    return hand
        .animate()
        .fadeIn(duration: motion.d(250))
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .move(
          begin: Offset.zero,
          end: motion.movement ? const Offset(-8, -10) : Offset.zero,
          duration: 700.ms,
          curve: Curves.easeInOut,
        )
        .scaleXY(begin: 1, end: 0.92, duration: 700.ms);
  }
}

/// Steluța aurie care zboară în arc de la răspunsul corect până în bara de progres.
class _FlyingStar extends StatelessWidget {
  const _FlyingStar({
    super.key,
    required this.from,
    required this.to,
    required this.onDone,
  });

  final Offset from;
  final Offset to;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 750),
    curve: Curves.easeInOutCubic,
    onEnd: onDone,
    builder: (context, t, _) {
      // Arc: punctul de control e deasupra mijlocului drumului.
      final mid = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 120);
      final p = Offset.lerp(
        Offset.lerp(from, mid, t)!,
        Offset.lerp(mid, to, t)!,
        t,
      )!;
      final size = 64 - 34 * t;
      return Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: t * math.pi,
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: const Color(0xFFF2C14E),
              shadows: const [Shadow(color: Color(0x99F2C14E), blurRadius: 14)],
            ),
          ),
        ),
      );
    },
  );
}

/// Eticheta unei variante: se poate rupe între cuvinte, niciodată în mijlocul unui cuvânt —
/// dacă cel mai lung cuvânt nu încape, litera se micșorează.
class _FitLabel extends StatelessWidget {
  const _FitLabel(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      var size = style.fontSize ?? 22;
      final longest = text.split(RegExp(r'\s+')).reduce((a, b) => a.length >= b.length ? a : b);
      double widthAt(double s) => (TextPainter(
        text: TextSpan(text: longest, style: style.copyWith(fontSize: s)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout()).width;
      while (c.maxWidth.isFinite && size > 12 && widthAt(size) > c.maxWidth) {
        size -= 1;
      }
      return Text(text, textAlign: TextAlign.center, style: style.copyWith(fontSize: size));
    },
  );
}
