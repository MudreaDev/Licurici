import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/shared/fx/mesh_warp.dart';
import 'package:licurici/shared/mascot.dart';

void main() {
  group('deformări', () {
    test(
      'aripa: punctul de prindere nu se mișcă, vârful se rotește mai mult',
      () {
        const pivot = Offset(0.4, 0.5);
        final w = Warps.flap(pivot: pivot, angle: 0.4);
        expect(w(pivot), pivot);
        final near = w(const Offset(0.45, 0.5)) - const Offset(0.45, 0.5);
        final far = w(const Offset(0.95, 0.5)) - const Offset(0.95, 0.5);
        expect(far.distance, greaterThan(near.distance * 5));
      },
    );

    test('respirația păstrează picioarele pe loc', () {
      final w = Warps.squash(0.1, anchorY: 1);
      expect(w(const Offset(0.5, 1)), const Offset(0.5, 1));
      expect(w(const Offset(0.5, 0)).dy, lessThan(0)); // se lungește în sus
    });

    test('legănarea: baza fixă, vârful se mișcă', () {
      final w = Warps.sway(0.1);
      expect(w(const Offset(0.3, 1)), const Offset(0.3, 1));
      expect(w(const Offset(0.3, 0)).dx, closeTo(0.4, 1e-9));
    });
  });

  for (final off in [true, false]) {
    testWidgets(
      'mascota se construiește (animații ${off ? 'oprite' : 'pornite'})',
      (tester) async {
        for (final mood in MascotMood.values) {
          await tester.pumpWidget(
            ProviderScope(
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: off),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Center(child: Mascot(size: 120, mood: mood)),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(Mascot), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
