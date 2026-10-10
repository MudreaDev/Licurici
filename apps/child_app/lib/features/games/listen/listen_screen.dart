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

final listenLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('asculta-si-fa'));

/// Ascultă și fă (LRC5): Licurici spune ce să atingă și în ce ordine; obiectele stau pe masă.
/// Fiecare atingere bună primește numărul ei (1, 2, 3). La prima greșeală Licurici repetă
/// (P2), la a doua apar pozele în ordine deasupra mesei (P3). Copilul poate cere oricând
/// „Mai spune o dată” (nu se socotește greșeală).
class ListenScreen extends ConsumerStatefulWidget {
  const ListenScreen({super.key, this.game = const InstructionGame(), this.seed});

  final InstructionGame game;
  final int? seed;

  @override
  ConsumerState<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends ConsumerState<ListenScreen> {
  late InstructionLevel _level;
  bool _blocked = false;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  final _attempts = <InstructionAttempt>[];
  final _taps = <int>[];
  final _timers = <Timer>[];
  final _clock = Stopwatch();
  final _shake = <int, int>{};
  int _index = 0;
  int _done = 0; // câți pași buni la rând
  int _errors = 0;
  bool _covered = false;
  bool _ready = false;
  bool _locked = false;
  int _burst = 0;
  InstructionResult? _result;
  String? _sticker;

  InstructionRound get _round => _level.rounds[_index];

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
    // Fără imaginile pe care copilul nu trebuie să le vadă (alese de adult, `avoidItems`).
    final avoid = avoidedOf(ref);
    final level = generateAvoiding(
      (seed) => widget.game.generate(ref.read(listenLevelProvider), seed: seed, avoid: avoid),
      (l) => l.art,
      avoid,
      seed: widget.seed,
    );
    _blocked = level == null;
    if (level == null) return;
    _level = level;
    _attempts.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    Future(() => mounted ? precacheStimuli(context, _level.art) : null).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Ascultă bine și atinge în aceeași ordine.']);
      _after(2400, _beginRound);
    });
  }

  void _beginRound() {
    _taps.clear();
    _shake.clear();
    _done = 0;
    _errors = 0;
    _locked = false;
    final hidden = _level.axes.hidden;
    setState(() => _covered = hidden);
    ref.read(voiceProvider).say(_round.speak);
    if (hidden) {
      _after(InstructionLevel.holdMs, () {
        setState(() => _covered = false);
        _clock
          ..reset()
          ..start();
      });
    } else {
      _clock
        ..reset()
        ..start();
    }
  }

  PromptLevel get _prompt => _errors == 0 ? PromptLevel.p0 : (_errors == 1 ? PromptLevel.p2 : PromptLevel.p3);

  void _tap(int k) {
    if (_locked || _covered || _result != null) return;
    final r = _round;
    if (_done < r.order.length && r.order[_done] == k) {
      _taps.add(k);
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() => _done++);
      if (_done == r.order.length) _roundDone();
      return;
    }
    if (_taps.contains(k)) return; // deja pus: nu se socotește
    _taps.add(k);
    _errors++;
    setState(() => _shake[k] = (_shake[k] ?? 0) + 1);
    if (_errors == 1) {
      ref.read(voiceProvider).say(['Mai ascultă o dată.', ...r.speak]);
    } else {
      ref.read(voiceProvider).say(['Uite, în ordinea asta.']);
    }
  }

  void _roundDone() {
    _locked = true;
    _attempts.add(InstructionAttempt(_round, taps: List.of(_taps), prompt: _prompt, ms: _clock.elapsedMilliseconds));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Bravo!']);
    setState(() => _burst++);
    _after(1500, () {
      if (_index + 1 < _total) {
        setState(() => _index++);
        _beginRound();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _cancel();
    final result = InstructionResult(_level, _attempts);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.instructionLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say(['Ai terminat! Bravo!']);
  }

  void _again({required bool next}) {
    if (next) ref.read(listenLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
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
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
                          FinishAction('Mai departe', Icons.arrow_forward_rounded, Tokens.good, () => _again(next: true)),
                        ],
                      )
                    : !_ready
                    ? const SizedBox.shrink()
                    : _table(motion, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _table(MotionPolicy motion, AppLayout layout) {
    final r = _round;
    final gap = layout.compact ? 8.0 : 14.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(gap, 0, gap, gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Licurici, cu „Mai spune o dată”.
          SizedBox(
            width: layout.compact ? 110 : 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Mascot(size: layout.compact ? 80 : 140, mood: _locked ? MascotMood.happy : MascotMood.idle, reaction: _burst),
                SizedBox(height: gap),
                CandyIconButton(
                  key: const ValueKey('listen-again'),
                  icon: Icons.volume_up_rounded,
                  label: 'Mai spune o dată',
                  color: Tokens.primary,
                  size: layout.compact ? 56 : 72,
                  onTap: () => ref.read(voiceProvider).say(r.speak),
                ),
                _Dots(total: _total, done: _attempts.length),
              ],
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                // Ajutorul P3: pozele în ordine.
                AnimatedSize(
                  duration: motion.d(250),
                  child: _errors >= 2
                      ? Padding(
                          padding: EdgeInsets.only(bottom: gap),
                          child: _OrderHint(round: r, size: layout.compact ? 44 : 64),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: CandyPanel(
                    padding: EdgeInsets.all(gap),
                    color: const Color(0xFFF6E7CF),
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, box) {
                            final n = r.table.length;
                            final cols = n <= 3 ? n : (n <= 4 ? 4 : (n <= 6 ? 3 : 4));
                            final rows = (n / cols).ceil();
                            final side = math.min((box.maxWidth - gap * (cols - 1)) / cols, (box.maxHeight - gap * (rows - 1)) / rows);
                            return Center(
                              child: Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final (k, o) in r.table.indexed)
                                    _Thing(
                                      key: ValueKey('listen-$k'),
                                      art: o.emoji,
                                      label: o.word,
                                      side: side,
                                      number: _numberOf(k),
                                      shake: _shake[k] ?? 0,
                                      motion: motion,
                                      onTap: () => _tap(k),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Obiectele acoperite cât se spune instrucțiunea (de ținut minte).
                        if (_covered)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFB98A5A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Icon(Icons.hearing_rounded, size: layout.compact ? 56 : 90, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                            ),
                          ),
                        if (motion.particles) Positioned.fill(child: IgnorePointer(child: StarBurst(trigger: _burst, count: 12))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Al câtelea a fost atins obiectul [k] (doar atingerile bune), sau null.
  int? _numberOf(int k) {
    final i = _round.order.indexOf(k);
    return i >= 0 && i < _done ? i + 1 : null;
  }
}

class _Thing extends StatelessWidget {
  const _Thing({
    super.key,
    required this.art,
    required this.label,
    required this.side,
    required this.number,
    required this.shake,
    required this.motion,
    required this.onTap,
  });

  final String art;
  final String label;
  final double side;
  final int? number;
  final int shake;
  final MotionPolicy motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Juice(
      enabled: motion.movement,
      shakeTick: shake,
      popTick: number ?? 0,
      child: CandyPressable(
        semanticLabel: label,
        color: Colors.white,
        radius: side * 0.18,
        lip: 5,
        width: side,
        height: side,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: StimulusArt(art, size: side * 0.72)),
            if (number != null)
              Positioned(
                right: -side * 0.04,
                top: -side * 0.04,
                child: Container(
                  width: side * 0.3,
                  height: side * 0.3,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Tokens.good, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: Text(
                    '$number',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white, fontSize: side * 0.16),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Pozele în ordinea cerută: 1 → 2 → 3 (ajutorul vizual după a doua greșeală).
class _OrderHint extends StatelessWidget {
  const _OrderHint({required this.round, required this.size});

  final InstructionRound round;
  final double size;

  @override
  Widget build(BuildContext context) => CandyPanel(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, k) in round.order.indexed) ...[
          if (i > 0) Icon(Icons.arrow_forward_rounded, color: Tokens.inkSoft, size: size * 0.5),
          StimulusArt(round.table[k].emoji, size: size),
        ],
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < done ? Tokens.good : Colors.white.withValues(alpha: 0.7)),
          ),
      ],
    ),
  );
}
