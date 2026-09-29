import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/shared/motion.dart';
import 'package:licurici/shared/role_fx.dart';

const full = MotionPolicy(MotionLevel.full);
const gentle = MotionPolicy(MotionLevel.gentle);
const off = MotionPolicy(MotionLevel.off);

Widget host(Widget child, {bool reduce = false}) => ProviderScope(
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  ),
);

Widget box(FxRole role, {VoidCallback? onTap}) => RoleFx(
  key: const ValueKey('fx'),
  role: role,
  onTap: onTap,
  child: const SizedBox.square(
    dimension: 80,
    child: ColoredBox(color: Colors.amber),
  ),
);

void main() {
  group('RoleStyle', () {
    test('doar țintele (și obiectul tras) se pot atinge', () {
      for (final m in [full, gentle, off]) {
        expect(
          {
            for (final r in FxRole.values)
              if (RoleStyle.of(r, m).tappable) r,
          },
          {FxRole.target, FxRole.hinted, FxRole.modeled, FxRole.dragged},
        );
      }
    });

    test('estomparea rămâne în toate modurile (e feedback, nu mișcare)', () {
      for (final m in [full, gentle, off]) {
        expect(RoleStyle.of(FxRole.rejected, m).opacity, lessThan(0.5));
        expect(RoleStyle.of(FxRole.faded, m).opacity, lessThan(0.5));
        expect(RoleStyle.of(FxRole.target, m).opacity, 1);
      }
    });

    test('pulsarea, plutirea și înclinarea doar cu mișcare', () {
      expect(RoleStyle.of(FxRole.hinted, full).pulse, isTrue);
      // mâna (P4) e ajutor, nu decor: rămâne vizibilă în toate modurile
      for (final m in [full, gentle, off]) {
        expect(RoleStyle.of(FxRole.modeled, m).hand, isTrue);
      }
      expect(RoleStyle.of(FxRole.reward, full).float, isTrue);
      for (final m in [gentle, off]) {
        expect(RoleStyle.of(FxRole.hinted, m).pulse, isFalse);
        expect(RoleStyle.of(FxRole.reward, m).float, isFalse);
        expect(RoleStyle.of(FxRole.dragged, m).tilt, 0);
      }
    });
  });

  testWidgets('atingerea: ținta răspunde, varianta estompată nu', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(host(box(FxRole.target, onTap: () => taps++)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('fx')));
    expect(taps, 1);
    await tester.pumpWidget(host(box(FxRole.rejected, onTap: () => taps++)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('fx')), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('reduce motion: niciun rol nu pornește animații', (tester) async {
    for (final role in FxRole.values) {
      await tester.pumpWidget(host(box(role), reduce: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: '$role');
    }
    // nici tranzițiile de rol (pop la corect, tremur la greșit)
    await tester.pumpWidget(host(box(FxRole.target), reduce: true));
    await tester.pump();
    for (final role in [FxRole.correct, FxRole.rejected]) {
      await tester.pumpWidget(host(box(role), reduce: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: '$role');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'full: recompensa plutește continuu; corectul face pop și se oprește',
    (tester) async {
      await tester.pumpWidget(host(box(FxRole.reward)));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(host(box(FxRole.target)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(box(FxRole.correct)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    },
  );
}
