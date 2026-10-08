import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/fish_art.dart';
import 'package:licurici/features/aquarium/reef.dart';
import 'package:licurici/features/aquarium/tank_painter.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show shots;

/// Peștele în toate unghiurile: din profil, din trei sferturi, cu capul spre noi (vederea din
/// față, cu ambii ochi) și dinspre noi (coada). Fără erori; cu `SHOTS=true`, o planșă.
void main() {
  testWidgets('peștele se vede bine din orice unghi', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sim = Aquarium(width: 2);
    final owned = <String, OwnedFish>{};
    final yaws = [0.0, -0.8, -1.35, -pi / 2, pi / 2, 2.3];
    for (final (row, sp) in ['clovn', 'chirurg'].indexed) {
      final s = fishSpeciesById(sp)!;
      final art = (await tester.runAsync(() async => buildFishImage(s, await paintGiftDrawing(s))))!;
      for (final (i, yaw) in yaws.indexed) {
        final id = '$sp$i';
        sim.fish.add(
          SwimmingFish(id: id, species: sp, length: 0.26, cruise: 0.1, at: Point(0.2 + i * 0.32, 0.3 + row * 0.45), z: 0, yaw: yaw)
            ..thrust = 0.4
            ..phase = 1.0,
        );
        owned[id] = OwnedFish(AquariumEntry(id: id, species: sp, created: DateTime(2026)), s, art);
      }
    }
    final time = ValueNotifier(0.0);
    Widget scene() => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: ReefBackdropPainter()),
          CustomPaint(
            painter: TankPainter(aquarium: sim, fish: owned, time: time, fx: const [], gather: ValueNotifier(null)),
          ),
        ],
      ),
    );
    await tester.pumpWidget(scene());
    // Culoarea medie (pentru vederea din față) se calculează în fundal.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    time.value = 0.01; // un cadru nou, cu culoarea calculată
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (shots) await expectLater(find.byType(Stack), matchesGoldenFile('shots/peste-unghiuri.png'));
  });
}
