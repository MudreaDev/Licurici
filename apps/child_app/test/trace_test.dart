import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/trace/trace_screen.dart';
import 'package:licurici/shared/reward_finish.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;

Future<ProviderContainer> _open(WidgetTester tester, Size size, {TraceGame game = const TraceGame()}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/traseaza',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
      GoRoute(path: '/traseaza', builder: (_, _) => TraceScreen(game: game, seed: 3)),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildTheme(calm: false),
        routerConfig: router,
      ),
    ),
  );
  await settle(tester, 4);
  return container;
}

/// Trage degetul pe mijlocul drumului curent, în pași mici.
Future<void> _trace(WidgetTester tester, TracePath path) async {
  final field = find.byKey(const ValueKey('trace-field'));
  final box = tester.getRect(field);
  Offset at(int i) =>
      box.topLeft +
      Offset(path.points[i].x * box.width, path.points[i].y * box.height);
  final gesture = await tester.startGesture(at(0));
  for (var i = 1; i < path.points.length; i++) {
    await gesture.moveTo(at(i));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final game in const <TraceGame>[TraceGame(), DotsGame()]) {
  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('${game.id}: toate drumurile duc la final ($device)', (
      tester,
    ) async {
      final container = await _open(tester, devices[device]!, game: game);
      final level = game.generate(1, seed: 3);
      expect(find.byKey(const ValueKey('trace-traveler')), findsOneWidget);
      if (shots) {
        await expectLater(
          find.byType(TraceScreen),
          matchesGoldenFile(game.id == 'traseaza' ? 'shots/trasare-$device.png' : 'shots/${game.id}-$device.png'),
        );
      }
      for (final path in level.paths) {
        await _trace(tester, path);
        // Desenele din puncte își arată rezultatul 1,9 s (Trasează: 1,3 s).
        await settle(tester, 12);
      }
      expect(find.byType(RewardFinish), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials;
      expect(trials.where((t) => t.gameId == game.id), hasLength(level.paths.length));
      expect(trials.every((t) => t.correct), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
  }

  testWidgets('atingerea departe de personaj nu-l mută', (tester) async {
    await _open(tester, devices['tableta']!);
    final traveler = find.byKey(const ValueKey('trace-traveler'));
    final before = tester.getCenter(traveler);
    final level = const TraceGame().generate(1, seed: 3);
    final box = tester.getRect(find.byKey(const ValueKey('trace-field')));
    final end = level.paths.first.points.last;
    await tester.tapAt(box.topLeft + Offset(end.x * box.width, end.y * box.height));
    await settle(tester, 2);
    expect(tester.getCenter(traveler).dx, closeTo(before.dx, 8));
    expect(find.byType(RewardFinish), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
