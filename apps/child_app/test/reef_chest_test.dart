import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/features/aquarium/reef_life.dart';

void main() {
  testWidgets('cufărul răspunde fără timp ambiental și fără bule în modul calm', (tester) async {
    final chest = ReefChest()..movement = false;
    addTearDown(chest.dispose);
    var repaints = 0;
    chest.addListener(() => repaints++);
    expect(chest.lid(12), 0); // Fără deschidere automată.
    chest.open(0);
    expect(chest.lid(0), 1);
    expect(chest.sinceOpen(0), greaterThan(3.2));
    expect(repaints, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(chest.lid(0), 1);
    chest.open(0); // O atingere nouă prelungește feedbackul.
    await tester.pump(const Duration(milliseconds: 300));
    expect(chest.lid(0), 1);
    await tester.pump(const Duration(milliseconds: 900));
    expect(chest.lid(0), 0);
    expect(repaints, 3);
  });

  testWidgets('schimbarea modului și ieșirea anulează închiderea programată', (tester) async {
    final chest = ReefChest()..movement = false;
    chest.open(0);
    chest.movement = true;
    chest.open(2);
    await tester.pump(const Duration(seconds: 2));
    expect(chest.lid(2.5), 1); // Cronometrul calm nu închide feedbackul normal.
    chest.movement = false;
    expect(chest.lid(2.5), 0);
    chest.open(0);
    chest.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('ținta cufărului are minimum 64 dp pe telefon și tabletă', () {
    for (final size in [const Size(640, 248), const Size(640, 360), const Size(740, 360), const Size(1280, 800)]) {
      final target = ReefChest.hitRect(size);
      expect(target.width, greaterThanOrEqualTo(64));
      expect(target.height, greaterThanOrEqualTo(64));
      expect(target.intersect(Offset.zero & size), target);
    }
  });
}
