import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/illustration.dart';
import 'reef.dart';
import 'reef_life.dart';

/// Recifului îi trebuie doar stratul din mijloc ([child]: peștii, mâncarea, efectele);
/// restul straturilor (apa, depărtarea, fundul, colțurile, razele) le pune scena.
/// Folosit de acvariu și de jocurile din apă.
class ReefScene extends StatelessWidget {
  const ReefScene({super.key, required this.ambient, required this.chest, required this.child});

  /// Timpul fundalului (stă pe loc în modul calm).
  final ValueListenable<double> ambient;
  final ReefChest chest;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
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
      RepaintBoundary(child: CustomPaint(painter: ReefAmbiencePainter(ambient, chest: chest))),
      child,
      IgnorePointer(
        child: RepaintBoundary(
          child: Image(
            image: illustration('scenes/aquarium_front'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const CustomPaint(painter: ReefForegroundPainter()),
          ),
        ),
      ),
      IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: ReefFrontPainter(ambient)))),
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
    ],
  );
}
