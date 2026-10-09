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
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final puzzleLevelProvider = NotifierProvider<GameLevel, int>(
  () => GameLevel('puzzle'),
);

/// Puzzle (POT7): piesele unei ilustrații pictate, amestecate în stânga; rama în dreapta, cu
/// modelul estompat (la nivelurile mici). Piesa se trage la locul ei — sau se atinge piesa,
/// apoi locul (pentru copiii cărora tragerea le e grea). Piesa pusă greșit se întoarce.
class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key, this.game = const PuzzleGame(), this.seed});

  final PuzzleGame game;
  final int? seed;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  late PuzzleLevel _level;

  /// Câte runde are tura: cât dă nivelul, sau mai puține dacă așa a ales specialistul.
  int get _total => cappedRounds(_level.rounds.length, ref.read(settingsProvider).rounds[widget.game.id]);
  final _solves = <PuzzleSolve>[];
  final _placed = <int>{};
  final _clock = Stopwatch();
  final _shake = <int, int>{};
  int _round = 0;
  int _wrong = 0;
  int? _selected;
  bool _done = false;
  int _burst = 0;
  bool _ready = false;
  PuzzleResult? _result;
  String? _sticker;
  Timer? _timer;

  PuzzleRound get _r => _level.rounds[_round];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(
      ref.read(puzzleLevelProvider),
      seed: widget.seed,
    );
    _solves.clear();
    _round = 0;
    _result = null;
    _sticker = null;
    _ready = false;
    _resetRound();
    Future(() async {
      if (!mounted) return;
      await Future.wait([
        for (final r in _level.rounds)
          precacheImage(illustration('domains/${r.image}'), context),
      ]).catchError((_) => <void>[]);
    }).whenComplete(() {
      if (!mounted) return;
      setState(() => _ready = true);
      ref.read(voiceProvider).say(['Pune piesele la locul lor.']);
      _clock
        ..reset()
        ..start();
    });
  }

  void _resetRound() {
    _placed.clear();
    _shake.clear();
    _wrong = 0;
    _selected = null;
    _done = false;
  }

  void _put(int piece, int slot) {
    if (_done || _placed.contains(piece)) return;
    if (piece == slot) {
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _placed.add(piece);
        _selected = null;
      });
      if (_placed.length == _r.pieces) _complete();
    } else {
      setState(() {
        _wrong++;
        _shake[piece] = (_shake[piece] ?? 0) + 1;
        _selected = null;
      });
    }
  }

  void _complete() {
    _solves.add(
      PuzzleSolve(_r, wrongMoves: _wrong, ms: _clock.elapsedMilliseconds),
    );
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Bravo']);
    setState(() {
      _done = true;
      _burst++;
    });
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_round + 1 < _total) {
        setState(() {
          _round++;
          _resetRound();
        });
        _clock
          ..reset()
          ..start();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = PuzzleResult(_level, _solves);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.puzzleLevel(result));
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
          .read(puzzleLevelProvider.notifier)
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
      const gap = 16.0;
      // Rama (4:3) cât mai mare în dreapta; tava ia restul.
      // Pe telefon rama e puțin mai mică, ca piesele din tavă să rămână mari.
      final share = layout.compact ? 0.5 : 0.58;
      final frameH = math.min(
        box.maxHeight - 16,
        (box.maxWidth * share) * 3 / 4,
      );
      final frameW = frameH * 4 / 3;
      final pw = frameW / _r.cols, ph = frameH / _r.rows;
      final image = illustration('domains/${_r.image}');
      final left = _r.tray.where((p) => !_placed.contains(p.index)).toList();
      // − rama (chenar 12) − spațiu − marginile ecranului (24).
      final trayW = box.maxWidth - frameW - 12 - gap - 24;
      // Piesele din tavă: așezarea (coloane × rânduri) care le dă mărimea cea mai mare.
      var scale = 0.0;
      for (var c = 1; c <= math.max(1, left.length); c++) {
        final r = math.max(1, (left.length / c).ceil());
        scale = math.max(
          scale,
          math.min(
            (trayW - 10 * (c - 1)) / (c * pw),
            (frameH - 10 * (r - 1)) / (r * ph),
          ),
        );
      }
      scale = scale.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: trayW,
              child: Center(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in left)
                      Juice(
                        key: ValueKey('puzzle-piece-${p.index}'),
                        enabled: motion.movement,
                        shakeTick: _shake[p.index] ?? 0,
                        child: Draggable<int>(
                          data: p.index,
                          feedback: Material(
                            type: MaterialType.transparency,
                            child: _Piece(
                              image: image,
                              piece: p,
                              round: _r,
                              w: pw,
                              h: ph,
                              lifted: true,
                            ),
                          ),
                          childWhenDragging: SizedBox(
                            width: pw * scale,
                            height: ph * scale,
                          ),
                          child: Semantics(
                            button: true,
                            label: 'Piesa ${p.index + 1}',
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _selected = _selected == p.index
                                    ? null
                                    : p.index,
                              ),
                              child: _Piece(
                                image: image,
                                piece: p,
                                round: _r,
                                w: pw * scale,
                                h: ph * scale,
                                selected: _selected == p.index,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: gap),
            Juice(
              enabled: motion.movement,
              popTick: _done ? 1 : 0,
              child: Container(
                key: const ValueKey('puzzle-frame'),
                width: frameW + 12,
                height: frameH + 12,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
                  boxShadow: Tokens.shadow,
                ),
                child: Stack(
                  children: [
                    // Modelul estompat (la nivelurile mici).
                    if (_level.axes.model)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.22,
                          child: Image(image: image, fit: BoxFit.fill),
                        ),
                      ),
                    for (final p in _r.tray)
                      Positioned(
                        left: p.col * pw,
                        top: p.row * ph,
                        width: pw,
                        height: ph,
                        child: DragTarget<int>(
                          onAcceptWithDetails: (d) => _put(d.data, p.index),
                          builder: (context, hover, _) => Semantics(
                            button: true,
                            label: 'Locul ${p.index + 1}',
                            child: GestureDetector(
                              key: ValueKey('puzzle-slot-${p.index}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _selected == null
                                  ? null
                                  : () => _put(_selected!, p.index),
                              child: _placed.contains(p.index)
                                  ? _Piece(
                                      image: image,
                                      piece: p,
                                      round: _r,
                                      w: pw,
                                      h: ph,
                                      flat: _done,
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: hover.isNotEmpty
                                            ? Tokens.sun.withValues(alpha: 0.3)
                                            : null,
                                        border: Border.all(
                                          color: const Color(0x66A9A3D1),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    if (motion.particles)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: StarBurst(trigger: _burst, count: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// O piesă: bucata (col, rând) din ilustrație, decupată din cod.
class _Piece extends StatelessWidget {
  const _Piece({
    required this.image,
    required this.piece,
    required this.round,
    required this.w,
    required this.h,
    this.selected = false,
    this.lifted = false,
    this.flat = false,
  });

  final ImageProvider image;
  final PuzzlePiece piece;
  final PuzzleRound round;
  final double w;
  final double h;
  final bool selected;
  final bool lifted;

  /// Puzzle-ul gata: fără margini, imaginea întreagă.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final full = Size(w * round.cols, h * round.rows);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: flat
            ? null
            : Border.all(
                color: selected ? Tokens.sun : Colors.white,
                width: selected ? 4 : 2,
              ),
        boxShadow: lifted || selected ? Tokens.shadow : null,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: full.width,
          maxWidth: full.width,
          minHeight: full.height,
          maxHeight: full.height,
          child: Transform.translate(
            offset: Offset(-piece.col * w, -piece.row * h),
            child: Image(
              image: image,
              width: full.width,
              height: full.height,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
