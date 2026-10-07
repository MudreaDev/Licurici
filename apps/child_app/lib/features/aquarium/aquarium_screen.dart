import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/illustration.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/sfx.dart';
import '../../shared/top_bar.dart';
import '../../shared/ui/candy.dart';
import '../../shared/voice.dart';
import '../settings/settings.dart';
import 'aquarium_store.dart';
import 'reef.dart';
import 'tank_painter.dart';

/// Acvariul copilului (`/acvariu`, README §2): peștii colorați de el înoată liber.
/// Acvariul nu se mișcă; copilul doar se joacă cu peștii:
/// - **atinge** apa → peștii din apropiere fug de deget;
/// - **ține apăsat** → peștii vin încet și se adună în jurul degetului;
/// - **Mâncare** → fulgi care cad; peștii vin și îi mănâncă.
class AquariumScreen extends ConsumerStatefulWidget {
  const AquariumScreen({super.key, this.newFishId});

  /// Peștele abia colorat: intră în apă de sus, cu bule.
  final String? newFishId;

  @override
  ConsumerState<AquariumScreen> createState() => _AquariumScreenState();
}

class _AquariumScreenState extends ConsumerState<AquariumScreen> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  final _ambient = ValueNotifier<double>(0);
  final _gather = ValueNotifier<math.Point<double>?>(null);
  final _fx = <TankFx>[];
  late final Ticker _ticker = createTicker(_tick);
  Aquarium? _sim;
  var _owned = <String, OwnedFish>{};
  Duration _last = Duration.zero;
  double _height = 1;
  bool _greeted = false;
  int _broke = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _ambient.dispose();
    _gather.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final sim = _sim;
    if (sim == null) return;
    final g = _gather.value;
    if (g != null) sim.gather(g);
    sim.step(dt);
    for (final e in sim.drainEvents()) {
      if (e is FishAte) {
        _fx.add(TankFx(e.at, TankFxKind.ate, _time.value));
        ref.read(sfxProvider).play(Sfx.tap);
      }
    }
    _fx.removeWhere((e) => _time.value - e.born > 1.6);
    _time.value += dt;
    // În modul calm fundalul stă; peștii înoată mai departe.
    if (MotionPolicy.of(context, ref).ambient) _ambient.value += dt;
  }

  /// Ține simularea la zi cu peștii salvați (unul nou intră de sus).
  void _sync(List<OwnedFish> fish, double width) {
    final sim = _sim ??= Aquarium(width: width, seed: 42);
    sim.width = width;
    final ids = {for (final f in fish) f.entry.id};
    for (final f in List.of(sim.fish)) {
      if (!ids.contains(f.id)) sim.remove(f.id);
    }
    final rnd = math.Random(sim.fish.length + 7);
    for (final o in fish) {
      if (sim.fish.any((f) => f.id == o.entry.id)) continue;
      final dive = o.entry.id == widget.newFishId;
      sim.add(
        SwimmingFish(
          id: o.entry.id,
          species: o.species.id,
          length: 0.2 + rnd.nextDouble() * 0.05 - (o.species.id == 'balon' ? 0.03 : 0),
          cruise: 0.09 + rnd.nextDouble() * 0.04,
          liveliness: o.species.swim,
          at: math.Point(0.2 + rnd.nextDouble() * (width - 0.4), Aquarium.top + 0.1 + rnd.nextDouble() * 0.45),
        ),
        diveIn: dive,
      );
      if (dive) _fx.add(TankFx(math.Point(sim.fish.last.pos.x, Aquarium.top), TankFxKind.ate, _time.value));
    }
    _owned = {for (final f in fish) f.entry.id: f};
  }

  math.Point<double> _toTank(Offset local) => math.Point(local.dx / _height, local.dy / _height);

  /// Mâncarea costă o stea (stelele se câștigă în jocuri). Fără stele, Licurici spune de
  /// unde se iau — fără reproș.
  void _feed() {
    final sim = _sim;
    if (sim == null || sim.food.length > 24) return;
    if (!ref.read(settingsProvider.notifier).spendStars(foodPrice)) {
      ref.read(voiceProvider).say(['Joacă un joc și câștigi stele pentru mâncare.']);
      setState(() => _broke++);
      return;
    }
    final rnd = math.Random();
    sim.feed(sim.width * (0.25 + rnd.nextDouble() * 0.5));
    ref.read(sfxProvider).play(Sfx.tap);
  }

  void _greet(List<OwnedFish> fish) {
    if (_greeted) return;
    _greeted = true;
    final voice = ref.read(voiceProvider);
    if (widget.newFishId != null) {
      voice.say(['Uite! Peștele tău înoată în acvariu!']);
    } else if (fish.length == 1 && fish.first.entry.gift) {
      voice.say(['Ți-am adus un pește!', 'Colorează și tu unul.']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fish = ref.watch(aquariumProvider);
    final layout = AppLayout.of(context);
    final list = fish.value;
    if (list != null) WidgetsBinding.instance.addPostFrameCallback((_) => _greet(list));
    final gift = list != null && list.length == 1 && list.first.entry.gift;
    final stars = ref.watch(settingsProvider.select((s) => s.stars));

    return Scaffold(
      backgroundColor: const Color(0xFF1C6F9C),
      body: LayoutBuilder(
        builder: (context, c) {
          _height = c.maxHeight;
          if (list != null) _sync(list, c.maxWidth / c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fundalul pictat (când există) sau recif desenat din cod.
              RepaintBoundary(
                child: Image(
                  image: illustration('scenes/aquarium_back'),
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const CustomPaint(painter: ReefBackdropPainter()),
                ),
              ),
              RepaintBoundary(child: CustomPaint(painter: ReefAmbiencePainter(_ambient))),
              if (_sim != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final p = _toTank(d.localPosition);
                    _sim!.tap(p);
                    _fx.add(TankFx(p, TankFxKind.tap, _time.value));
                  },
                  onLongPressStart: (d) => _gather.value = _toTank(d.localPosition),
                  onLongPressMoveUpdate: (d) => _gather.value = _toTank(d.localPosition),
                  onLongPressEnd: (_) {
                    _gather.value = null;
                    _sim!.release();
                  },
                  onLongPressCancel: () {
                    _gather.value = null;
                    _sim?.release();
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: TankPainter(aquarium: _sim!, fish: _owned, time: _time, fx: _fx, gather: _gather),
                      size: Size.infinite,
                    ),
                  ),
                ),
              IgnorePointer(
                child: RepaintBoundary(
                  child: Image(
                    image: illustration('scenes/aquarium_front'),
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => CustomPaint(painter: ReefFrontPainter(_ambient)),
                  ),
                ),
              ),
              // Sticla acvariului: margini puțin mai întunecate.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.15,
                      colors: [Color(0x00000000), Color(0x00000000), Color(0x33062A40)],
                      stops: [0, 0.7, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    TopBar(
                      title: 'Acvariul meu',
                      trailing: _StarPurse(stars: stars, shake: _broke),
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, layout.compact ? 10 : 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: gift
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomLeft,
                                    child: _GiftHint(compact: layout.compact),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          CandyButton(
                            key: const ValueKey('feed'),
                            label: 'Mâncare',
                            icon: Icons.grain_rounded,
                            color: const Color(0xFFF2A33A),
                            minWidth: layout.compact ? 120 : 160,
                            onTap: _feed,
                          ),
                          const SizedBox(width: 12),
                          CandyButton(
                            key: const ValueKey('color-fish'),
                            label: layout.compact ? 'Colorez' : 'Colorez un pește',
                            icon: Icons.brush_rounded,
                            color: Tokens.primary,
                            minWidth: layout.compact ? 120 : 200,
                            onTap: () => context.go('/acvariu/coloreaza'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (fish.isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          );
        },
      ),
    );
  }
}

/// Licurici, la prima vizită: „Ți-am adus un pește!”.
class _GiftHint extends StatelessWidget {
  const _GiftHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Mascot(size: compact ? 80 : 120, mood: MascotMood.wave),
      Padding(
        padding: EdgeInsets.only(bottom: compact ? 40 : 70),
        child: SpeechBubble(
          tail: BubbleTail.left,
          child: Text(
            'Ți-am adus un pește!\nColorează și tu unul.',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.ink),
          ),
        ),
      ),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
}

/// Câte stele de mâncare costă o mână de fulgi.
const foodPrice = 1;

/// Pușculița: stelele copilului. Clatină ușor când nu ajung pentru mâncare.
class _StarPurse extends StatelessWidget {
  const _StarPurse({required this.stars, required this.shake});

  final int stars;
  final int shake;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return CandyPanel(
      key: const ValueKey('stars'),
      radius: 999,
      lip: 4,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: const Color(0xFFF2C14E), size: compact ? 30 : 40),
          const SizedBox(width: 6),
          Text(
            '$stars',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Tokens.ink, fontSize: compact ? 22 : 28),
          ),
        ],
      ),
    ).animate(key: ValueKey(shake), target: shake == 0 ? 0 : 1).shake(hz: 4, rotation: 0.04, duration: 450.ms);
  }
}
