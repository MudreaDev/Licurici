import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/track/track_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, shots;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('urmărește peștele: îl găsește pe al lui, apoi pierde unul; se înregistrează ($device)', (tester) async {
      tester.view.physicalSize = devices[device]!;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
      addTearDown(container.dispose);
      container.read(trackLevelProvider.notifier).setLevel(6);
      final router = GoRouter(
        initialLocation: '/s',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
          GoRoute(path: '/s', builder: (_, _) => const TrackScreen(seed: 4)),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
        ),
      );
      // Desenele peștilor se fac cu imagini adevărate (async real).
      for (var i = 0; i < 150 && find.byKey(const ValueKey('track-field')).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final field = find.byKey(const ValueKey('track-field'));
      expect(field, findsOneWidget);
      final level = const TrackGame().generate(6, seed: 4);
      expect(level.axes.fish, 3);

      Future<void> untilAnswer() async {
        // Arătarea + înotul, în pași mici (fizica merge pe cadre).
        final ms = TrackLevel.showMs + level.axes.swimMs + 300;
        for (var t = 0; t < ms; t += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      TrackFishPainter painter() =>
          tester.widget<CustomPaint>(find.descendant(of: field, matching: find.byType(CustomPaint))).painter! as TrackFishPainter;

      for (final (i, t) in level.trials.indexed) {
        // O atingere în timpul înotului se numără (fără efect).
        await tester.pump(const Duration(milliseconds: TrackLevel.showMs + 400));
        if (i == 0) await tester.tapAt(const Offset(5, 300));
        await untilAnswer();
        final sim = painter().sim;
        final h = tester.getSize(field).height;
        // Prima jumătate: peștele lui; apoi altul.
        final pick = i < 4 ? t.target : (t.target + 1) % t.fish.length;
        final f = sim.fish.firstWhere((f) => f.id == 'f$pick');
        await tester.tapAt(tester.getTopLeft(field) + Offset(f.pos.x * h, f.pos.y * h));
        if (i == 0 && shots) await expectLater(find.byType(TrackScreen), matchesGoldenFile('shots/urmareste-$device.png'));
        await tester.pump(const Duration(milliseconds: 2500));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RewardFinish), findsOneWidget);
      expect(tester.takeException(), isNull);
      final trials = container.read(sessionProvider)!.trials.where((t) => t.gameId == 'urmareste-pestele').toList();
      expect(trials.length, level.trials.length);
      expect(trials.where((t) => t.correct).length, 4);
      expect(trials.first.offTargetTaps, 1);
      expect(trials.first.stepId, 'ATN2b');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
