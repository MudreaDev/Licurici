import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';
import 'rig/cutout_rig.dart';
import 'rig/rig_data.dart';
import 'rig/rig_pose.dart';

export 'rig/rig_pose.dart' show MascotMood;

/// Straturile lui Licurici (`assets/mascot/licurici/`), încărcate o dată (la pornire, în boot).
final mascotRigProvider = FutureProvider<LoadedRig>(
  (ref) => LoadedRig.load('licurici'),
);

/// Licurici, mascota: ilustrația decupată pe straturi și animată din cod ([CutoutRig], ADR-028).
///
/// Stări: `idle` (respiră, plutește, bate din aripi, clipește), `happy` (sare, ridică bagheta
/// cu scântei, lanterna se aprinde), `encourage` (înclinare blândă, privire caldă), `sleep`.
/// Schimbă [reaction] (ex. un contor) ca să redeclanșezi aceeași stare.
class Mascot extends ConsumerWidget {
  const Mascot({
    super.key,
    this.size = 120,
    this.mood = MascotMood.idle,
    this.reaction = 0,
  });

  final double size;
  final MascotMood mood;
  final int reaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final rig = ref.watch(mascotRigProvider).value;
    return RepaintBoundary(
      child: Semantics(
        label: 'Licurici',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: rig == null
              ? const _Glow()
              : CutoutRig(
                  rig: rig,
                  motion: motion,
                  mood: mood,
                  reaction: reaction,
                ),
        ),
      ),
    );
  }
}

/// Până se încarcă straturile (câteva zeci de ms la pornire): doar lumina licuriciului.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [Color(0xFFFFF6C2), Color(0x00F6DF84)],
        radius: 0.35,
      ),
    ),
  );
}
