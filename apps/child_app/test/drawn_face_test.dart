import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/shared/drawn_face.dart';
import 'package:licurici/shared/stimulus_art.dart';
import 'package:licurici_core/licurici_core.dart';

/// Planșa fețelor desenate: fiecare emoție pe identități diferite și la intensități diferite.
/// Fără erori de desen; cu `SHOTS=true` scrie planșa pentru inspecție (`test/shots/`).
const shots = bool.fromEnvironment('SHOTS');

void main() {
  testWidgets('planșa fețelor: emoții × identități × intensități', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = Random(4);
    final looks = [for (var i = 0; i < 5; i++) FaceLook.anyRandom(r)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFDF8),
          body: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: Column(
              children: [
                for (final e in FaceEmotion.values)
                  Row(
                    children: [
                      for (final l in looks) DrawnFace(FaceSpec(l, e), size: 120),
                      for (final t in const [0.25, 0.5, 0.75]) DrawnFace(FaceSpec(looks.first, e, t), size: 120),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DrawnFace), findsNWidgets(FaceEmotion.values.length * 8));
    if (shots) {
      await expectLater(find.byKey(const ValueKey('sheet')), matchesGoldenFile('shots/fete-desenate.png'));
    }
  });

  testWidgets('StimulusArt desenează o față din textul ei, cu etichetă', (tester) async {
    final face = FaceSpec(const FaceLook(skin: 2, hair: 1), FaceEmotion.trist);
    await tester.pumpWidget(MaterialApp(home: Center(child: StimulusArt(face.art, size: 100, semanticLabel: 'trist'))));
    expect(find.byType(DrawnFace), findsOneWidget);
    expect(find.bySemanticsLabel('trist'), findsOneWidget);
  });
}
