import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final stopLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('stop'));

enum _Light { off, green, red }

/// Stop! (FEX2c): un felinar mare. Se aprinde **verde** → copilul îl atinge repede; uneori se face
/// **roșu** la scurt timp după → copilul se oprește (Licurici ridică mâna). Întârzierea roșului
/// urcă sau coboară după fiecare oprire (`StopStaircase`), deci jocul rămâne „pe muchie” pentru
/// fiecare copil. Nicio penalizare: o atingere la roșu primește doar „Data viitoare te oprești.”.
class StopScreen extends ConsumerStatefulWidget {
  const StopScreen({super.key, this.game = const StopSignalGame(), this.seed});

  final StopSignalGame game;
  final int? seed;

  @override
  ConsumerState<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends ConsumerState<StopScreen> {
  late StopLevel _level;
  late StopStaircase _stairs;
  final _trials = <StopTrial>[];
  final _clock = Stopwatch();
  int _index = 0;
  _Light _light = _Light.off;
  bool _tapped = false;
  bool _started = false;
  int? _rt;
  Timer? _timer;
  Timer? _redTimer;
  StopResult? _result;
  String? _sticker;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _cancel();
    _level = widget.game.generate(ref.read(stopLevelProvider), seed: widget.seed);
    _stairs = StopStaircase(_level.axes);
    _trials.clear();
    _index = 0;
    _light = _Light.off;
    _started = false;
    _result = null;
    _sticker = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say(['Atinge felinarul când e verde. Când se face roșu, oprește-te!']);
    });
  }

  void _cancel() {
    _timer?.cancel();
    _redTimer?.cancel();
  }

  /// Copilul pornește jocul (prima atingere a butonului „Gata”), ca să fie atent de la început.
  void _go() {
    setState(() => _started = true);
    _next();
  }

  void _next() {
    _timer = Timer(Duration(milliseconds: _level.gapsMs[_index]), _lightUp);
  }

  void _lightUp() {
    if (!mounted) return;
    final stop = _level.stops[_index];
    setState(() {
      _light = _Light.green;
      _tapped = false;
      _rt = null;
    });
    _clock
      ..reset()
      ..start();
    if (stop) {
      final ssd = _stairs.ssdMs;
      _redTimer = Timer(Duration(milliseconds: ssd), () {
        if (mounted && !_tapped) setState(() => _light = _Light.red);
      });
    }
    _timer = Timer(Duration(milliseconds: _level.axes.windowMs), _close);
  }

  void _tap() {
    if (_light == _Light.off || _tapped || _result != null) return;
    _tapped = true;
    _rt = _clock.elapsedMilliseconds;
    final stop = _level.stops[_index];
    if (!stop || _light == _Light.green) {
      ref.read(sfxProvider).play(Sfx.tap);
    }
    // La o încercare cu oprire, atingerea înainte de roșu închide încercarea (roșul nu mai vine).
    _redTimer?.cancel();
    _timer?.cancel();
    _close();
  }

  void _close() {
    if (!mounted) return;
    _redTimer?.cancel();
    final stop = _level.stops[_index];
    final trial = StopTrial(stop: stop, tapped: _tapped, rtMs: _rt, ssdMs: stop ? _stairs.ssdMs : null);
    _trials.add(trial);
    if (stop) {
      _stairs.update(stopped: !_tapped);
      ref.read(voiceProvider).say([_tapped ? 'Data viitoare te oprești.' : ref.read(cheerProvider).correct()]);
      if (!_tapped) ref.read(sfxProvider).play(Sfx.correct);
    }
    setState(() => _light = _Light.off);
    if (_index + 1 < _level.stops.length) {
      _index++;
      _next();
    } else {
      _finish();
    }
  }

  void _finish() {
    final result = StopResult(_level, _trials);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.stopLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(stopLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final compact = AppLayout.of(context).compact;
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
                    : !_started
                    ? Center(
                        child: CandyButton(
                          key: const ValueKey('stop-ready'),
                          label: 'Gata!',
                          icon: Icons.play_arrow_rounded,
                          color: Tokens.good,
                          onTap: _go,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) {
                          final side = (box.maxHeight * 0.82).clamp(120.0, compact ? 240.0 : 360.0);
                          return GestureDetector(
                            key: const ValueKey('stop-field'),
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => _tap(),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    label: switch (_light) {
                                      _Light.green => 'Felinarul verde: atinge!',
                                      _Light.red => 'Felinarul roșu: oprește-te',
                                      _Light.off => 'Felinarul stins',
                                    },
                                    button: true,
                                    child: _Lantern(key: const ValueKey('stop-lantern'), light: _light, size: side),
                                  ),
                                  SizedBox(width: side * 0.1),
                                  // Licurici ridică mâna când e roșu.
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    opacity: _light == _Light.red ? 1 : 0,
                                    child: StimulusArt('✋', size: side * 0.4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Felinarul: sticlă rotundă care se aprinde verde sau roșu, cu halou.
class _Lantern extends StatelessWidget {
  const _Lantern({super.key, required this.light, required this.size});

  final _Light light;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LanternPainter(light)),
  );
}

class _LanternPainter extends CustomPainter {
  _LanternPainter(this.light);

  final _Light light;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width * 0.36;
    final color = switch (light) {
      _Light.green => const Color(0xFF5FD38A),
      _Light.red => const Color(0xFFF07A6A),
      _Light.off => const Color(0xFFB9C4C8),
    };
    if (light != _Light.off) {
      canvas.drawCircle(c, r * 1.35, Paint()..shader = ui.Gradient.radial(c, r * 1.35, [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]));
    }
    // Rama de lemn și sticla.
    canvas.drawCircle(c, r * 1.08, Paint()..color = const Color(0xFF8A6A3A));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c - Offset(r * 0.3, r * 0.35), r * 1.2, [
          Color.lerp(color, Colors.white, 0.65)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ], const [0, 0.55, 1]),
    );
    canvas.drawOval(Rect.fromCenter(center: c - Offset(r * 0.35, r * 0.45), width: r * 0.55, height: r * 0.3), Paint()..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_LanternPainter old) => old.light != light;
}
