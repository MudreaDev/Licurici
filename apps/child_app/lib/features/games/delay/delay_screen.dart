import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/cheer.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/mascot.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/sfx.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';

final delayLevelProvider = NotifierProvider<GameLevel, int>(() => GameLevel('acum-sau-mai-mult'));

enum _Phase { choose, waiting, done }

/// Acum sau mai mult? (FEX1b): Licurici oferă o stea acum sau mai multe după o așteptare.
/// Alegerea „aștept” umple încet un borcan; „Iau steaua acum” rămâne mereu la îndemână (fără
/// reproș). Stelele câștigate intră în pușculița acvariului.
class DelayScreen extends ConsumerStatefulWidget {
  const DelayScreen({super.key, this.game = const DelayGame(), this.seed});

  final DelayGame game;
  final int? seed;

  @override
  ConsumerState<DelayScreen> createState() => _DelayScreenState();
}

class _DelayScreenState extends ConsumerState<DelayScreen> with SingleTickerProviderStateMixin {
  late DelayLevel _level;
  final _choices = <DelayChoice>[];
  final _clock = Stopwatch();
  /// Cât a așteptat (din ceasul animațiilor, deci și cu timp simulat în teste).
  int _waitedMs = 0;
  late final Ticker _ticker = createTicker((elapsed) {
    if (_phase != _Phase.waiting) return;
    _waitedMs = elapsed.inMilliseconds;
    final p = _waitedMs / _offer.waitMs;
    if (p >= 1) {
      _done(waited: true, completed: true);
    } else {
      setState(() => _progress = p);
    }
  });
  int _index = 0;
  double _progress = 0;
  _Phase _phase = _Phase.choose;
  int? _latency;
  Timer? _timer;
  DelayResult? _result;
  String? _sticker;

  DelayOffer get _offer => _level.offers[_index];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _level = widget.game.generate(ref.read(delayLevelProvider), seed: widget.seed);
    _choices.clear();
    _index = 0;
    _result = null;
    _sticker = null;
    _offerNext();
  }

  void _offerNext() {
    _phase = _Phase.choose;
    _progress = 0;
    _latency = null;
    _clock
      ..reset()
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say([_offer.later == 3 ? 'O stea acum sau trei stele dacă aștepți?' : 'O stea acum sau două stele dacă aștepți?']);
    });
    if (mounted) setState(() {});
  }

  void _now() {
    if (_phase == _Phase.choose) _latency = _clock.elapsedMilliseconds;
    _done(waited: _phase == _Phase.waiting, completed: false);
  }

  void _startWaiting() {
    _latency = _clock.elapsedMilliseconds;
    _waitedMs = 0;
    setState(() => _phase = _Phase.waiting);
    ref.read(voiceProvider).say(['Bine. Așteptăm împreună.']);
    if (!_ticker.isActive) _ticker.start();
  }

  void _done({required bool waited, required bool completed}) {
    if (_phase == _Phase.done) return;
    _ticker.stop();
    final choice = DelayChoice(_offer, waited: waited, completed: completed, waitedMs: _waitedMs, latencyMs: _latency);
    _choices.add(choice);
    ref.read(settingsProvider.notifier).addStars(choice.stars);
    ref.read(sfxProvider).play(Sfx.star);
    ref.read(voiceProvider).say([completed ? ref.read(cheerProvider).correct() : 'Poftim steaua ta!']);
    setState(() {
      _phase = _Phase.done;
      _progress = completed ? 1 : _progress;
    });
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_index + 1 < _level.offers.length) {
        _index++;
        _offerNext();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    final result = DelayResult(_level, _choices);
    final session = ref.read(sessionProvider.notifier);
    session.record((r) => r.delayLevel(result));
    session.checkpoint();
    setState(() {
      _result = result;
      _sticker = ref.read(settingsProvider.notifier).awardSticker();
    });
    ref.read(voiceProvider).say([ref.read(cheerProvider).finish()]);
  }

  void _again({required bool next}) {
    if (next) ref.read(delayLevelProvider.notifier).setLevel(_result!.suggestedNextLevel(_level.level));
    setState(_start);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        subtitle: 'Ai adunat ${result.starsWon} stele pentru acvariu.',
                        actions: [
                          FinishAction('Încă o dată', Icons.replay_rounded, Tokens.primary, () => _again(next: false)),
                          FinishAction('Mai departe', Icons.arrow_forward_rounded, Tokens.good, () => _again(next: true)),
                        ],
                      )
                    : _board(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board() {
    final compact = AppLayout.of(context).compact;
    final card = compact ? 150.0 : 230.0;
    final waiting = _phase == _Phase.waiting;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Acum: o stea.
              _OfferCard(
                key: const ValueKey('delay-now'),
                size: card,
                stars: 1,
                label: waiting ? 'Iau steaua acum' : 'Acum',
                color: const Color(0xFFF2A33A),
                onTap: _phase == _Phase.done ? null : _now,
              ),
              SizedBox(width: compact ? 16 : 32),
              Mascot(size: compact ? 90 : 140, mood: waiting ? MascotMood.sleep : MascotMood.think),
              SizedBox(width: compact ? 16 : 32),
              // Mai târziu: borcanul care se umple.
              _OfferCard(
                key: const ValueKey('delay-later'),
                size: card,
                stars: _offer.later,
                label: waiting ? 'Aștept…' : 'Aștept',
                color: Tokens.primary,
                progress: waiting || _phase == _Phase.done ? _progress : null,
                onTap: _phase == _Phase.choose ? _startWaiting : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O ofertă: stelele, eticheta și (la așteptare) inelul care se umple.
class _OfferCard extends StatelessWidget {
  const _OfferCard({super.key, required this.size, required this.stars, required this.label, required this.color, this.onTap, this.progress});

  final double size;
  final int stars;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null && progress == null ? 0.6 : 1,
    child: CandyPressable(
      color: const Color(0xFFFFF8EC),
      border: color,
      borderWidth: 4,
      radius: 28,
      width: size,
      height: size * 1.15,
      semanticLabel: '$label: $stars ${stars == 1 ? 'stea' : 'stele'}',
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox.square(
              dimension: size * 0.62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress case final p?)
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: p.clamp(0.0, 1.0),
                        strokeWidth: size * 0.05,
                        backgroundColor: color.withValues(alpha: 0.18),
                        color: color,
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    children: [
                      for (var i = 0; i < stars; i++)
                        Icon(Icons.star_rounded, color: const Color(0xFFF2C14E), size: size * (stars == 1 ? 0.42 : 0.26)),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Tokens.ink, fontSize: math.max(16, size * 0.1)),
            ),
          ],
        ),
      ),
    ),
  );
}
