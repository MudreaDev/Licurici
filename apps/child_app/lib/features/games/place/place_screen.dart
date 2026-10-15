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
import '../../../shared/placement_art.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final placeLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('pune-ursul'));

/// Mărimea obiectului, ca parte din latura scenei.
const _obj = 0.26;

/// Centrul locului [r] față de [l], ca parte din latura scenei (reperul e la x 0.16…0.66, ca la
/// „Unde e ursulețul?”; locurile nu se suprapun).
Offset spotCenter(Relation r, Landmark l) {
  const cx = 0.41;
  final top = l == Landmark.cutie ? 0.52 : 0.56;
  return switch (r) {
    Relation.pe => Offset(cx, top - _obj / 2),
    Relation.sub => const Offset(cx, 0.8),
    Relation.inauntru => Offset(cx, top + 0.14),
    Relation.langa => const Offset(0.84, 0.95 - _obj / 2),
    Relation.deasupra => const Offset(cx, 0.12),
  };
}

/// Pune ursulețul (LRC6): „Pune ursulețul sub masă.” Copilul trage obiectul din tavă pe locul
/// spus sau atinge locul (pentru copiii cu dificultăți motorii). Locurile posibile sunt cercuri
/// punctate; un loc greșit trimite obiectul înapoi în tavă, clătinându-se. După două greșeli,
/// locul cerut pulsează. Cu două obiecte, copilul atinge întâi obiectul, apoi locul.
class PlaceScreen extends ConsumerStatefulWidget {
  const PlaceScreen({super.key, this.game = const PlaceGame(), this.seed});

  final PlaceGame game;
  final int? seed;

  @override
  ConsumerState<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends ConsumerState<PlaceScreen> {
  late PlaceLevel _level;
  final _answers = <PlaceAnswer>[];
  final _clock = Stopwatch();
  final _shake = <String, int>{};
  final _placed = <Relation, PlaceTask>{};
  int _index = 0;
  int _selected = 0;
  int _wrong = 0;
  Relation? _firstWrong;
  int _burst = 0;
  MascotMood _mood = MascotMood.idle;
  PlaceResult? _result;
  String? _sticker;
  Timer? _timer;

  PlaceRound get _r => _level.rounds[_index];

  List<PlaceTask> get _left => [for (final t in _r.tasks) if (!_placed.containsValue(t)) t];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(placeLevelProvider), seed: widget.seed);
    _answers.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _beginRound();
  }

  void _beginRound() {
    _placed.clear();
    _shake.clear();
    _selected = 0;
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

  void _put(PlaceTask task, Relation spot) {
    if (_result != null || _placed.containsKey(spot) || _placed.containsValue(task)) return;
    if (task.relation != spot) {
      _wrong++;
      _firstWrong ??= spot;
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() {
        _shake[task.word] = (_shake[task.word] ?? 0) + 1;
        _mood = MascotMood.encourage;
      });
      ref.read(voiceProvider).say([ref.read(cheerProvider).retry()]);
      return;
    }
    ref.read(sfxProvider).play(Sfx.bubble);
    setState(() {
      _placed[spot] = task;
      _selected = 0;
    });
    if (_left.isNotEmpty) return;
    _answers.add(PlaceAnswer(_r, wrong: _wrong, ms: _clock.elapsedMilliseconds, firstWrong: _firstWrong));
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
    final result = PlaceResult(_level, _answers);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.placeLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(placeLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
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
                        key: const ValueKey('place-repeat'),
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
      final s = math.min(box.maxHeight - 16, box.maxWidth * 0.58);
      final obj = s * _obj;
      final left = _left;
      final selected = left.isEmpty ? null : left[math.min(_selected, left.length - 1)];
      final hint = _wrong >= 2 ? selected?.relation : null;
      final landmark = _r.landmark;
      Widget at(Relation r, Widget child) {
        final c = spotCenter(r, landmark);
        return Positioned(left: c.dx * s - obj / 2, top: c.dy * s - obj / 2, width: obj, height: obj, child: child);
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Tava: obiectele de așezat și Licurici.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Mascot(size: math.min(110, box.maxHeight * 0.28), mood: _mood, reaction: _burst),
              const SizedBox(height: 8),
              CandyPanel(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: obj * 1.25,
                  height: math.max(1, _r.tasks.length) * obj * 1.15,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final t in left)
                        Juice(
                          key: ValueKey('place-${t.word}'),
                          enabled: motion.movement,
                          shakeTick: _shake[t.word] ?? 0,
                          child: Semantics(
                            button: true,
                            selected: t == selected,
                            label: t.word,
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selected = left.indexOf(t)),
                              child: Draggable<PlaceTask>(
                                data: t,
                                feedback: Material(type: MaterialType.transparency, child: StimulusArt(t.emoji, size: obj)),
                                childWhenDragging: SizedBox.square(dimension: obj),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: left.length > 1 && t == selected ? Tokens.primary : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                  child: StimulusArt(t.emoji, size: obj),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Scena: reperul, obiectele puse și locurile libere.
          Container(
            decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(32)),
            child: Juice(
              enabled: motion.feedback,
              popTick: _burst,
              child: SizedBox.square(
                key: const ValueKey('place-scene'),
                dimension: s,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: s * 0.95,
                      height: 3,
                      child: const ColoredBox(color: Color(0x33A9805F)),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: LandmarkPainter(landmark, left: 0.16, right: 0.66, top: landmark == Landmark.cutie ? 0.52 : 0.56, front: false)),
                      ),
                    ),
                    for (final MapEntry(key: r, value: t) in _placed.entries) at(r, StimulusArt(t.emoji, size: obj)),
                    if (landmark == Landmark.cutie)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: LandmarkPainter(landmark, left: 0.16, right: 0.66, top: 0.52, front: true)),
                        ),
                      ),
                    for (final r in _r.spots)
                      if (!_placed.containsKey(r))
                        at(
                          r,
                          Juice(
                            enabled: motion.movement,
                            pulse: r == hint,
                            child: DragTarget<PlaceTask>(
                              onAcceptWithDetails: (d) => _put(d.data, r),
                              builder: (context, candidates, _) => Semantics(
                                key: ValueKey('spot-${r.name}'),
                                button: true,
                                label: r.at(landmark),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (selected != null) _put(selected, r);
                                  },
                                  child: CustomPaint(painter: _SpotPainter(active: candidates.isNotEmpty || r == hint)),
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
        ],
      );
    },
  );
}

/// Un loc liber: un cerc punctat, mai aprins când obiectul tras e deasupra lui.
class _SpotPainter extends CustomPainter {
  _SpotPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    canvas.drawCircle(c, radius, Paint()..color = active ? const Color(0x55FFE08A) : const Color(0x22FFFFFF));
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = active ? const Color(0xFFE0A030) : const Color(0x998A7A9E);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius), a, math.pi / n, false, dash);
    }
  }

  @override
  bool shouldRepaint(_SpotPainter old) => old.active != active;
}
