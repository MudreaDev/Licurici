import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/sequence/simon_screen.dart';
import 'package:licurici/shared/celebration.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';
import 'praise_finders.dart';

class _Game extends SimonGame {
  final levels = <SequenceLevel>[];
  @override
  SequenceLevel generate(int level, {int? seed}) {
    final result = super.generate(level, seed: 17);
    levels.add(result);
    return result;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Game game, {
  int level = 1,
  Size size = const Size(960, 540),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SimonScreen(game: game, initialLevel: level),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
      child: MaterialApp.router(
        theme: buildTheme(calm: true),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.tap(find.text('Începem'));
  await tester.pump();
}

Future<void> _watch(WidgetTester tester, SequenceLevel level) async {
  expect(find.text('Privește'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 450));
  for (final index in level.sequence) {
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(ValueKey('simon-pad-$index')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.value, 'aprins');
    await tester.pump(Duration(milliseconds: level.axes.onMs));
    await tester.pump(Duration(milliseconds: level.axes.gapMs));
  }
  expect(find.textContaining('Rândul tău'), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('simon-pad-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('five correct sequences adapt and end with three stars', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game);
    for (var round = 0; round < 5; round++) {
      final level = game.levels.last;
      expect(level.level, round + 1);
      await _watch(tester, level);
      for (final index in level.expected) {
        await _tap(tester, index);
      }
      expect(findPraise(), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(findFinish(), findsOneWidget);
    expect(find.text('Încă o dată'), findsOneWidget);
    expect(find.text('Mai departe'), findsOneWidget);
    expect(find.byType(StarBurst), findsNothing);
    await tester.tap(find.text('Mai departe'));
    await tester.pump();
    expect(game.levels.last.level, 6);
    await _close(tester);
  });

  testWidgets('one replay only, then moves on adaptively', (tester) async {
    final game = _Game();
    await _open(tester, game, level: 4);
    final level = game.levels.last;
    await _watch(tester, level);
    await _tap(tester, (level.expected.first + 1) % level.pads.length);
    expect(find.text('Mai privim o dată'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await _watch(tester, level);
    await _tap(tester, (level.expected.first + 1) % level.pads.length);
    expect(find.text('Continuăm'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(game.levels.last.level, 3);
    expect(game.levels.length, 2);
    await _close(tester);
  });

  testWidgets('six pads fit small landscape, reverse order and locked taps', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game, level: 19, size: const Size(640, 360));
    final level = game.levels.last;
    await tester.tap(find.byKey(const ValueKey('simon-pad-0')));
    await _watch(tester, level);
    for (final pad in level.pads) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('simon-pad-${pad.index}')))
            .shortestSide,
        greaterThanOrEqualTo(96),
      );
    }
    for (final index in level.expected) {
      await _tap(tester, index);
    }
    expect(findPraise(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}
