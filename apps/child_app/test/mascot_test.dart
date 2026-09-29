import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/shared/mascot.dart';
import 'package:licurici/shared/motion.dart';
import 'package:licurici/shared/rig/cutout_rig.dart';
import 'package:licurici/shared/rig/rig_data.dart';
import 'package:licurici/shared/rig/rig_pose.dart';

/// Capturi PNG: `flutter test --update-goldens --dart-define=SHOTS=true`.
const shots = bool.fromEnvironment('SHOTS');

const full = MotionPolicy(MotionLevel.full);
const gentle = MotionPolicy(MotionLevel.gentle);
const off = MotionPolicy(MotionLevel.off);

void main() {
  setUp(rootBundle.clear);

  group('RigPose (funcție pură)', () {
    final times = [for (var t = 0.0; t < RigPose.loop; t += 0.37) t];
    final reactions = [0.0, 0.1, 0.3, 0.5, 0.8, 0.99];

    test('off: poză statică în orice stare, la orice moment', () {
      for (final mood in MascotMood.values) {
        final ref = RigPose.of(mood: mood, t: 0, r: 0, motion: off);
        for (final t in times) {
          for (final r in reactions) {
            final p = RigPose.of(mood: mood, t: t, r: r, motion: off);
            expect(p.hover, 0, reason: '$mood t=$t r=$r');
            expect(p.wing, 0);
            expect(p.arm, 0);
            expect(p.tilt, 0);
            expect(p.squash, 0);
            expect(p.breath, 0);
            expect(p.sparkle, isNull);
            expect(p.glow, ref.glow);
            expect(p.blink, ref.blink);
          }
        }
      }
    });

    test('gentle: fără idle și fără mișcare, doar lumina reacționează', () {
      for (final t in times) {
        for (final r in reactions) {
          final p = RigPose.of(
            mood: MascotMood.happy,
            t: t,
            r: r,
            motion: gentle,
          );
          expect(p.hover, 0);
          expect(p.wing, 0);
          expect(p.arm, 0);
          expect(p.sparkle, isNull);
        }
      }
      final calm = RigPose.of(
        mood: MascotMood.happy,
        t: 0,
        r: 0,
        motion: gentle,
      );
      final lit = RigPose.of(
        mood: MascotMood.happy,
        t: 0,
        r: 0.5,
        motion: gentle,
      );
      expect(lit.glow, greaterThan(calm.glow));
    });

    test('full: idle se mișcă, bucla se reia fără salt', () {
      final hovers = {
        for (final t in times)
          RigPose.of(mood: MascotMood.idle, t: t, r: 0, motion: full).hover,
      };
      expect(hovers.length, greaterThan(10));
      for (final mood in MascotMood.values) {
        final a = RigPose.of(mood: mood, t: 0, r: 0, motion: full);
        final b = RigPose.of(mood: mood, t: RigPose.loop, r: 0, motion: full);
        expect(b.hover, closeTo(a.hover, 1e-6));
        expect(b.wing, closeTo(a.wing, 1e-6));
        expect(b.breath, closeTo(a.breath, 1e-6));
      }
    });

    test(
      'bucurie: sare, ridică bagheta, scântei; somn: ochi închiși, lumină slabă',
      () {
        final mid = RigPose.of(
          mood: MascotMood.happy,
          t: 0,
          r: 0.42,
          motion: full,
        );
        expect(mid.hover, lessThan(-100));
        expect(mid.arm, lessThan(-0.3));
        expect(mid.sparkle, 0.42);
        final sleep = RigPose.of(
          mood: MascotMood.sleep,
          t: 1,
          r: 0,
          motion: full,
        );
        expect(sleep.blink, 1);
        expect(sleep.glow, lessThan(0.6));
        expect(sleep.wingRest, lessThan(0));
      },
    );
  });

  group('rig.json + straturi', () {
    late LoadedRig rig;
    setUp(() async {
      rig = (await TestWidgetsFlutterBinding.ensureInitialized().runAsync(
        () => LoadedRig.load('licurici'),
      ))!;
    });

    test('are straturile, articulațiile și reperele', () {
      final d = rig.data;
      expect(d.frame, const Size(1024, 1024));
      expect(d.layers.keys, ['wing_left', 'wing_right', 'body', 'arm']);
      expect(rig.images.keys.toSet(), d.layers.keys.toSet());
      for (final l in ['wing_left', 'wing_right', 'arm']) {
        final layer = d.layers[l]!;
        expect(layer.pivot, isNotNull, reason: l);
        // articulația e lângă strat (rădăcina e la marginea lui, nu în gol)
        expect(
          layer.rect.inflate(40).contains(layer.pivot!),
          isTrue,
          reason: l,
        );
      }
      expect(d.anchors.eyes, hasLength(2));
      expect(d.anchors.lantern, isNotNull);
      expect(d.anchors.wandTip, isNotNull);
      expect(
        d.layers['arm']!.rect.inflate(1).contains(d.anchors.wandTip!),
        isTrue,
      );
    });

    Widget host(Widget child, {bool reduce = false}) => ProviderScope(
      overrides: [mascotRigProvider.overrideWith((ref) => rig)],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );

    testWidgets('reduce motion: niciun ticker nu rulează, nici la reacții', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Mascot(), reduce: true));
      await tester.pump();
      expect(find.byType(CutoutRig), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        host(const Mascot(mood: MascotMood.happy, reaction: 1), reduce: true),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('full: idle rulează; bucuria se termină și revine la idle', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Mascot()));
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        host(const Mascot(mood: MascotMood.happy, reaction: 1)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('capturi: stările mascotei', (tester) async {
      tester.view.physicalSize = const Size(1200, 340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget cell(MascotMood mood, double r) => SizedBox.square(
        dimension: 280,
        child: CustomPaint(
          painter: RigPainter(
            rig,
            RigPose.of(mood: mood, t: 1, r: r, motion: full),
          ),
        ),
      );
      await tester.pumpWidget(
        ColoredBox(
          color: const Color(0xFF2A2A48),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                cell(MascotMood.idle, 0),
                cell(MascotMood.happy, 0.4),
                cell(MascotMood.encourage, 0.3),
                cell(MascotMood.sleep, 0),
              ],
            ),
          ),
        ),
      );
      if (shots) {
        await expectLater(
          find.byType(Row),
          matchesGoldenFile('shots/mascota-stari.png'),
        );
      }
    });
  });
}
