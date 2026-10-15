import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
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

final paintByEarLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('coloreaza-ce-auzi'));

/// Desenul necolorat: tonuri de gri deschise (conturul rămâne vizibil).
const _uncolored = ColorFilter.matrix([
  0.0957, 0.3218, 0.0325, 0, 140, //
  0.0957, 0.3218, 0.0325, 0, 140,
  0.0957, 0.3218, 0.0325, 0, 140,
  0, 0, 0, 1, 0,
]);

/// Primul pas al colorării: luminozitatea întărită (umplutura → aproape albă, conturul → negru),
/// apoi înmulțită cu culoarea aleasă — ca o pagină de colorat umplută cu o singură culoare.
const _brighten = ColorFilter.matrix([
  0.4677, 1.5734, 0.1588, 0, 0, //
  0.4677, 1.5734, 0.1588, 0, 0,
  0.4677, 1.5734, 0.1588, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Colorează ce auzi (LRC4): „Colorează balonul cu roșu.” Copilul atinge borcanul cu culoarea
/// (sau îl trage) și apoi obiectul. O colorare greșită nu se pune: obiectul se clatină și rămâne
/// gri. După două greșeli, borcanul și obiectul cerute pulsează.
class PaintByEarScreen extends ConsumerStatefulWidget {
  const PaintByEarScreen({super.key, this.game = const PaintGame(), this.seed});

  final PaintGame game;
  final int? seed;

  @override
  ConsumerState<PaintByEarScreen> createState() => _PaintByEarScreenState();
}

class _PaintByEarScreenState extends ConsumerState<PaintByEarScreen> {
  late PaintLevel _level;
  final _answers = <PaintAnswer>[];
  final _clock = Stopwatch();
  final _shake = <int, int>{};

  /// Obiectele colorate deja (index → culoare).
  final _painted = <int, PaintColor>{};
  PaintColor? _brush;
  int _index = 0;
  int _wrong = 0;
  String? _firstWrong;
  int _burst = 0;
  MascotMood _mood = MascotMood.idle;
  PaintResult? _result;
  String? _sticker;
  Timer? _timer;

  PaintRound get _r => _level.rounds[_index];

  PaintTask? get _next => _r.tasks.where((t) => !_painted.containsKey(t.slot)).firstOrNull;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(paintByEarLevelProvider), seed: widget.seed);
    _answers.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _beginRound();
  }

  void _beginRound() {
    _painted.clear();
    _shake.clear();
    _brush = null;
    _wrong = 0;
    _firstWrong = null;
    _mood = MascotMood.idle;
    _clock
      ..reset()
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  void _ask() {
    if (mounted && _result == null) ref.read(voiceProvider).say(_r.speak);
  }

  void _pickColor(PaintColor c) {
    if (_result != null) return;
    ref.read(sfxProvider).play(Sfx.tap);
    setState(() => _brush = c);
  }

  void _paint(int slot, PaintColor? color) {
    if (_result != null || color == null || _painted.containsKey(slot)) return;
    final ok = _r.tasks.any((t) => t.slot == slot && t.color == color);
    if (!ok) {
      _wrong++;
      _firstWrong ??= '${_r.slots[slot].name}:${color.word}';
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _shake[slot] = (_shake[slot] ?? 0) + 1;
        _mood = MascotMood.encourage;
      });
      ref.read(voiceProvider).say([ref.read(cheerProvider).retry()]);
      return;
    }
    ref.read(sfxProvider).play(Sfx.bubble);
    setState(() => _painted[slot] = color);
    if (_next != null) return;
    _answers.add(PaintAnswer(_r, wrong: _wrong, ms: _clock.elapsedMilliseconds, firstWrong: _firstWrong));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say([ref.read(cheerProvider).correct(firstTry: _wrong == 0)]);
    setState(() {
      _burst++;
      _mood = MascotMood.happy;
    });
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_index + 1 < _level.rounds.length) {
        setState(() {
          _index++;
          _beginRound();
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = PaintResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.paintLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(paintByEarLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
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
    final result = _result;
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, _level.level),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: widget.game.name,
                trailing: result == null
                    ? BarButton(
                        key: const ValueKey('paint-repeat'),
                        icon: Icons.record_voice_over_rounded,
                        color: Tokens.lavender,
                        label: 'Mai spune',
                        onTap: _ask,
                      )
                    : null,
              ),
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
                    : _board(motion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(MotionPolicy motion) => LayoutBuilder(
    builder: (context, box) {
      final hint = _wrong >= 2 ? _next : null;
      final n = _r.slots.length;
      final sheetW = box.maxWidth * 0.66;
      final art = math.min(box.maxHeight * 0.62, (sheetW - 60) / n - 24);
      final mascot = math.min(96.0, box.maxHeight * 0.24);
      final pot = math.min(64.0, (box.maxHeight - mascot - 36) / 3 - 14);
      return Row(
        children: [
          // Planșa cu obiectele de colorat.
          SizedBox(
            width: sheetW,
            child: Center(
              child: CandyPanel(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, slot) in _r.slots.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Juice(
                          key: ValueKey('paint-slot-$i'),
                          enabled: motion.movement,
                          shakeTick: _shake[i] ?? 0,
                          pulse: hint?.slot == i,
                          child: DragTarget<PaintColor>(
                            onAcceptWithDetails: (d) => _paint(i, d.data),
                            builder: (context, candidates, _) => Semantics(
                              button: true,
                              label: slot.name,
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _paint(i, _brush),
                                child: SizedBox.square(
                                  dimension: art,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: motion.d(400),
                                      child: _Colored(
                                        key: ValueKey('$_index-$i-${_painted[i]}'),
                                        emoji: slot.thing.emoji,
                                        size: art * (slot.big == false ? 0.55 : 1),
                                        color: _painted[i],
                                      ),
                                    ),
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
          ),
          // Licurici și borcanele cu culori.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascot(size: mascot, mood: _mood, reaction: _burst),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final c in _r.palette)
                        Juice(
                          enabled: motion.movement,
                          pulse: hint?.color == c && _brush != c,
                          child: Semantics(
                            button: true,
                            selected: _brush == c,
                            label: c.word,
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: ValueKey('pot-${c.name}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _pickColor(c),
                              child: Draggable<PaintColor>(
                                data: c,
                                onDragStarted: () => setState(() => _brush = c),
                                feedback: _Pot(color: c, size: pot * 0.8, selected: true),
                                child: _Pot(color: c, size: pot, selected: _brush == c),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Obiectul: gri cât e necolorat, umplut cu [color] după.
class _Colored extends StatelessWidget {
  const _Colored({super.key, required this.emoji, required this.size, this.color});

  final String emoji;
  final double size;
  final PaintColor? color;

  @override
  Widget build(BuildContext context) {
    final art = StimulusArt(emoji, size: size);
    final c = color;
    if (c == null) return ColorFiltered(colorFilter: _uncolored, child: art);
    return ColorFiltered(
      colorFilter: ColorFilter.mode(Color(c.argb), BlendMode.modulate),
      child: ColorFiltered(colorFilter: _brighten, child: art),
    );
  }
}

/// Un borcan cu vopsea: capacul deschis și vopseaua la gură; cel ales are pensula alături.
class _Pot extends StatelessWidget {
  const _Pot({required this.color, required this.size, required this.selected});

  final PaintColor color;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Color(color.argb);
    return AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.white : const Color(0x66FFFFFF), width: selected ? 5 : 3),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: selected ? 0.6 : 0.25),
              blurRadius: selected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.9,
            colors: [Color.lerp(c, Colors.white, 0.45)!, c, Color.lerp(c, Colors.black, 0.15)!],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: selected ? Icon(Icons.brush_rounded, color: Colors.white, size: size * 0.45) : null,
      ),
    );
  }
}
