import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/fish_art.dart';
import 'package:licurici/features/aquarium/reef.dart';
import 'package:licurici/features/aquarium/tank_painter.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show shots;

/// Toate modelele de pești: fișa (desenul de colorat) și peștele colorat de Licurici, care
/// înoată din profil. Fără erori; cu `SHOTS=true` scrie o planșă pentru inspecție.
void main() {
  testWidgets('toate modelele se desenează (fișă + pește colorat)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sim = Aquarium(width: 1400 / 900);
    final owned = <String, OwnedFish>{};
    for (final (i, s) in fishSpecies.indexed) {
      final art = (await tester.runAsync(() async => buildFishImage(s, await paintGiftDrawing(s))))!;
      final f = SwimmingFish(
        id: s.id,
        species: s.id,
        length: 0.3,
        cruise: 0.1,
        at: Point(0.25 + (i % 4) * 0.36, 0.25 + (i ~/ 4) * 0.36),
        z: 0,
      )..thrust = 0.3;
      sim.fish.add(f);
      owned[s.id] = OwnedFish(AquariumEntry(id: s.id, species: s.id, created: DateTime(2026)), s, art);
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: ReefBackdropPainter()),
            CustomPaint(
              painter: TankPainter(
                aquarium: sim,
                fish: owned,
                time: ValueNotifier(0),
                fx: const [],
                gather: ValueNotifier(null),
              ),
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    if (shots) await expectLater(find.byType(Stack), matchesGoldenFile('shots/pesti-modele.png'));
  });
}
