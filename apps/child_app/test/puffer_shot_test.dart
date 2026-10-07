import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/fish_art.dart';
import 'package:licurici/features/aquarium/reef.dart';
import 'package:licurici/features/aquarium/tank_painter.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show shots;

void main() {
  testWidgets('peștele-balon umflat se desenează (rotund, cu țepi), fără erori', (tester) async {
    tester.view.physicalSize = const Size(900, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = fishSpeciesById('balon')!;
    final art = (await tester.runAsync(() async => buildFishImage(s, await paintGiftDrawing(s))))!;
    final sim = Aquarium(width: 1.8);
    for (final (i, puff) in [0.0, 1.0].indexed) {
      final f = SwimmingFish(id: 'b$i', species: 'balon', length: 0.4, cruise: 0.1, at: Point(0.5 + i * 0.8, 0.45))
        ..puff = puff;
      sim.fish.add(f);
    }
    final owned = {for (final f in sim.fish) f.id: OwnedFish(AquariumEntry(id: f.id, species: 'balon', created: DateTime(2026)), s, art)};
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
    if (shots) await expectLater(find.byType(Stack), matchesGoldenFile('shots/peste-balon-umflat.png'));
  });
}
