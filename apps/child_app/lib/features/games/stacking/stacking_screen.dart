import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final stackingLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('turnul'));

/// Culorile inelelor (calde și reci alternate; o singură culoare la nivelurile mari).
const ringColors = [
  Color(0xFFF08A6A),
  Color(0xFFF2C14E),
  Color(0xFF7FC0A3),
  Color(0xFF5B9BB5),
  Color(0xFFA9A3D1),
  Color(0xFFE79BC0),
];

/// Turnul (COG4): piramida cu inele. Inelele stau în tavă; copilul atinge inelul care urmează
/// (cel mai mare rămas) și acesta coboară pe țăruș. Un inel prea mic se clatină și rămâne în tavă
/// — alegerea se numără, fără niciun semn de greșeală.
class StackingScreen extends ConsumerStatefulWidget {
  const StackingScreen({super.key, this.game = const StackingGame(), this.seed});

  final StackingGame game;
  final int? seed;

  @override
  ConsumerState<StackingScreen> createState() => _StackingScreenState();
}

class _StackingScreenState extends ConsumerState<StackingScreen> {
  late StackingLevel _level;
  final _builds = <StackBuild>[];
  final _clock = Stopwatch();
  final _shake = <int, int>{};
  int _tower = 0;
  int _placed = 0;
  int _wrong = 0;
  int _burst = 0;
  StackingResult? _result;
  String? _sticker;
  Timer? _timer;

  StackTower get _t => _level.towers[_tower];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(stackingLevelProvider), seed: widget.seed);
    _builds.clear();
    _tower = 0;
    _result = null;
    _sticker = null;
    _beginTower();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(['Pune inelele pe rând: întâi cel mai mare.']);
    });
  }

  void _beginTower() {
    _placed = 0;
    _wrong = 0;
    _shake.clear();
    _clock
      ..reset()
      ..start();
  }

  void _pick(StackRing ring) {
    if (_result != null || ring.rank < _placed) return;
    if (ring.rank != _placed) {
      _wrong++;
      ref.read(sfxProvider).play(Sfx.tap);
      setState(() => _shake[ring.rank] = (_shake[ring.rank] ?? 0) + 1);
      // După două alegeri greșite, Licurici spune din nou regula (ajutor, nu reproș).
      if (_wrong == 2) ref.read(voiceProvider).say(['Caută cel mai mare inel.']);
      return;
    }
    ref.read(sfxProvider).note(_placed);
    setState(() => _placed++);
    if (_placed == _t.size) _towerDone();
  }

  void _towerDone() {
    _builds.add(StackBuild(_t, wrong: _wrong, ms: _clock.elapsedMilliseconds));
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say([ref.read(cheerProvider).correct(firstTry: _wrong == 0)]);
    setState(() => _burst++);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_tower + 1 < _level.towers.length) {
        setState(() {
          _tower++;
          _beginTower();
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = StackingResult(_level, _builds);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.stackingLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(stackingLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
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
      final n = _t.size;
      // Grosimea unui inel: turnul întreg încape pe înălțime.
      final ringH = math.min(56.0, (box.maxHeight - 60) / (n + 1.2));
      final maxW = math.min(box.maxWidth * 0.36, ringH * 5.2);
      final stacked = [for (final r in _t.tray) if (r.rank < _placed) r]..sort((a, b) => a.rank.compareTo(b.rank));
      final tray = [for (final r in _t.tray) if (r.rank >= _placed) r];
      Color color(StackRing r) => ringColors[r.color % ringColors.length];
      return Row(
        children: [
          // Tava: inelele rămase, amestecate.
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 12, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xB3FFF8EC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE8D9BC), width: 3),
              ),
              alignment: Alignment.center,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 10,
                children: [
                  for (final r in tray)
                    Juice(
                      key: ValueKey('ring-${r.rank}'),
                      enabled: motion.movement,
                      shakeTick: _shake[r.rank] ?? 0,
                      child: Semantics(
                        button: true,
                        label: 'Inel ${r.rank + 1}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _pick(r),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CustomPaint(size: Size(maxW * r.width, ringH), painter: _RingPainter(color(r))),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Țărușul cu inelele puse.
          Container(
            margin: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(28)),
            alignment: Alignment.bottomCenter,
            width: maxW + 64,
            child: Juice(
              enabled: motion.feedback,
              popTick: _burst,
              child: CustomPaint(
                key: const ValueKey('stacking-pole'),
                size: Size(maxW + 40, ringH * (n + 1.2)),
                painter: _PolePainter(
                  rings: [for (final r in stacked) (r.width, color(r))],
                  maxWidth: maxW,
                  ringHeight: ringH,
                  total: n,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      );
    },
  );
}

/// Un inel văzut din lateral: o „gogoașă” lucioasă cu gaura din mijloc sugerată.
class _RingPainter extends CustomPainter {
  _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintRing(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

void paintRing(Canvas canvas, Rect r, Color color) {
  final rr = RRect.fromRectAndRadius(r.deflate(2), Radius.circular(r.height / 2));
  canvas.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = const Color(0x22000000));
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
        Color.lerp(color, Colors.white, 0.35)!,
        color,
        Color.lerp(color, Colors.black, 0.2)!,
      ], const [0, 0.5, 1]),
  );
  // Luciul de sus.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * 0.15, r.top + r.height * 0.18, r.width * 0.5, r.height * 0.18), Radius.circular(r.height)),
    Paint()..color = Colors.white.withValues(alpha: 0.45),
  );
}

class _PolePainter extends CustomPainter {
  _PolePainter({required this.rings, required this.maxWidth, required this.ringHeight, required this.total});

  final List<(double, Color)> rings;
  final double maxWidth, ringHeight;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseH = ringHeight * 0.5;
    final bottom = size.height;
    // Baza de lemn și țărușul.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, bottom - baseH / 2), width: maxWidth + 30, height: baseH), Radius.circular(baseH / 2)),
      Paint()..color = const Color(0xFFC8955A),
    );
    final poleTop = bottom - baseH - ringHeight * (total + 0.6);
    final half = ringHeight * 0.22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(cx - half, poleTop, cx + half, bottom - baseH), Radius.circular(half)),
      Paint()
        ..shader = ui.Gradient.linear(Offset(cx - half, 0), Offset(cx + half, 0), const [Color(0xFFE8BE84), Color(0xFFC8955A)]),
    );
    // Bila din vârf.
    canvas.drawCircle(
      Offset(cx, poleTop),
      half * 1.5,
      Paint()..shader = ui.Gradient.radial(Offset(cx - half * 0.5, poleTop - half * 0.5), half * 2, const [Color(0xFFF6D9A8), Color(0xFFC8955A)]),
    );
    for (final (i, (w, color)) in rings.indexed) {
      final top = bottom - baseH - ringHeight * (i + 1);
      final width = maxWidth * w;
      paintRing(canvas, Rect.fromLTWH(cx - width / 2, top, width, ringHeight), color);
    }
  }

  @override
  bool shouldRepaint(_PolePainter old) => old.rings.length != rings.length || old.total != total || old.maxWidth != maxWidth;
}
