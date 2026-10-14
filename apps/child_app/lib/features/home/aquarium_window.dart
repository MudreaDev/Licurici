import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../shared/illustration.dart';
import '../../shared/motion.dart';
import '../../shared/ui/candy.dart';
import '../aquarium/aquarium_store.dart';
import '../aquarium/tank_painter.dart';

/// Fereastra acvariului de pe ecranul principal: o mică scenă pictată
/// (`scenes/aquarium_mini`) în care înoată chiar peștii colorați de copil, cu aceeași
/// fizică și același desen ca în acvariul mare. O atingere deschide acvariul.
///
/// Cu „reduce motion” peștii stau pe loc (o singură imagine); în rest înoată mereu, încet.
class AquariumWindow extends ConsumerStatefulWidget {
  const AquariumWindow({super.key, required this.height});

  /// Înălțimea ferestrei (lățimea e 3:2, ca imaginea).
  final double height;

  /// Câți pești încap în fereastră (cei mai noi).
  static const maxFish = 6;

  @override
  ConsumerState<AquariumWindow> createState() => _AquariumWindowState();
}

class _AquariumWindowState extends ConsumerState<AquariumWindow> with SingleTickerProviderStateMixin {
  static const _aspect = 1.5;
  final _time = ValueNotifier<double>(0);
  final _noFinger = ValueNotifier<math.Point<double>?>(null);
  final _sim = Aquarium(width: _aspect, seed: 11);
  late final Ticker _ticker = createTicker(_tick);
  var _owned = <String, OwnedFish>{};
  Duration _last = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _noFinger.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _sim.step(dt);
    _sim.drainEvents();
    _time.value += dt;
  }

  /// Ține peștii ferestrei la zi cu cei din acvariu.
  void _sync(List<OwnedFish> all) {
    final fish = all.length > AquariumWindow.maxFish ? all.sublist(all.length - AquariumWindow.maxFish) : all;
    final ids = {for (final f in fish) f.entry.id};
    for (final f in List.of(_sim.fish)) {
      if (!ids.contains(f.id)) _sim.remove(f.id);
    }
    final rnd = math.Random(_sim.fish.length + 3);
    for (final o in fish) {
      if (_sim.fish.any((f) => f.id == o.entry.id)) continue;
      _sim.add(
        SwimmingFish(
          id: o.entry.id,
          species: o.species.id,
          length: 0.36 + rnd.nextDouble() * 0.05,
          cruise: 0.09 + rnd.nextDouble() * 0.03,
          liveliness: o.species.swim,
          at: math.Point(0.3 + rnd.nextDouble() * (_aspect - 0.6), Aquarium.top + 0.12 + rnd.nextDouble() * 0.4),
          z: 0.1 + rnd.nextDouble() * 0.5,
          yaw: rnd.nextBool() ? 0 : math.pi,
        ),
      );
    }
    _owned = {for (final f in fish) f.entry.id: f};
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final list = ref.watch(aquariumProvider).value;
    if (list != null) _sync(list);
    if (motion.movement && !_ticker.isActive) {
      _ticker.start();
    } else if (!motion.movement && _ticker.isActive) {
      _ticker.stop();
    }
    if (!motion.movement && _time.value == 0) {
      // Fără mișcare: peștii se așază o dată, apoi rămân pe loc.
      for (var i = 0; i < 60; i++) {
        _sim.step(1 / 30);
      }
      _time.value = 2;
    }

    final h = widget.height, w = h * _aspect;
    final frame = h * 0.05;
    return CandyPressable(
      key: const ValueKey('aquarium'),
      semanticLabel: 'Acvariul meu',
      color: const Color(0xFFFFF8EC),
      lipColor: const Color(0xFFD9C6A5),
      radius: h * 0.16,
      onTap: () => context.go('/acvariu'),
      child: SizedBox(
        width: w,
        height: h,
        child: Padding(
          padding: EdgeInsets.all(frame),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(h * 0.12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: illustration('scenes/aquarium_mini'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF8ED8E6), Color(0xFF3E9DC0), Color(0xFFE9D9B4)],
                        stops: [0, 0.78, 0.8],
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: TankPainter(aquarium: _sim, fish: _owned, time: _time, fx: const [], gather: _noFinger),
                  ),
                ),
                // Sticla: o lucire în colțul de sus și margini puțin mai întunecate.
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment(0.2, 0.1),
                        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
                // Eticheta, ca pe un acvariu adevărat.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: h * 0.04,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: h * 0.07, vertical: h * 0.015),
                      decoration: BoxDecoration(
                        color: const Color(0xEEFFF8EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Acvariul meu',
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: Tokens.ink,
                          fontSize: (h * 0.1).clamp(12.0, 20.0),
                          fontWeight: FontWeight.w800,
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
    );
  }
}
