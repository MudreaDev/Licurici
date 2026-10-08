import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/features/aquarium/aquarium_store.dart';
import 'package:licurici/features/aquarium/fish_art.dart';
import 'package:licurici/features/aquarium/reef.dart';
import 'package:licurici/features/aquarium/reef_life.dart';
import 'package:licurici/features/aquarium/tank_painter.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show shots;

/// Scena acvariului (recif + pești în spațiu), fără restul ecranului: se desenează fără
/// erori la mai multe dimensiuni și cu peștii în toate pozele (profil, întorși, din spate,
/// umflați). Cu `SHOTS=true` scrie capturi pentru inspecție.
void main() {
  for (final (name, size) in [('tableta', const Size(1280, 800)), ('telefon-mic', const Size(740, 360))]) {
    testWidgets('scena acvariului ($name)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(Caustics.load);
      final owned = <String, OwnedFish>{};
      final sim = Aquarium(width: size.width / size.height, seed: 3);
      final poses = [
        ('clovn', 0.55, 0.42, 0.05, 0.0, 0.0),
        ('inger', 1.15, 0.33, 0.45, pi, 0.0),
        ('chirurg', 0.9, 0.62, 0.75, 1.2, 1.6),
        ('balon', 0.35, 0.6, 0.3, 0.3, 0.0),
        ('clovn', 1.35, 0.55, 0.15, 2.4, -2.0),
      ];
      for (final (i, (sp, x, y, z, yaw, turn)) in poses.indexed) {
        final s = fishSpeciesById(sp)!;
        final art = (await tester.runAsync(() async => buildFishImage(s, await paintGiftDrawing(s, seed: i + 1))))!;
        final f = SwimmingFish(id: 'f$i', species: sp, length: 0.27, cruise: 0.12, at: Point(x * sim.width / 1.6, y), z: z, yaw: yaw)
          ..turnRate = turn
          ..thrust = 0.7
          ..phase = i * 1.3;
        sim.fish.add(f);
        owned[f.id] = OwnedFish(AquariumEntry(id: f.id, species: sp, created: DateTime(2026)), s, art);
      }
      final time = ValueNotifier(18.0);
      final chest = ReefChest()..openedAt = 11.6;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: ReefBackdropPainter()),
              CustomPaint(painter: ReefAmbiencePainter(time, chest: chest)),
              CustomPaint(
                painter: TankPainter(aquarium: sim, fish: owned, time: time, fx: const [], gather: ValueNotifier(null)),
              ),
              const CustomPaint(painter: ReefForegroundPainter()),
              CustomPaint(painter: ReefFrontPainter(time)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (shots) await expectLater(find.byType(Stack), matchesGoldenFile('shots/acvariu-scena-$name.png'));

      // Simularea merge mai departe cu peștii reali: niciun cadru nu aruncă erori.
      for (var k = 0; k < 30; k++) {
        sim.step(1 / 30);
        time.value += 1 / 30;
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
