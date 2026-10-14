import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/reaction/reaction_game_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/celebration.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'app_test.dart' show pumpUntil, closeApp;
import 'praise_finders.dart';

class _SeededPond extends PescarulGame {
  const _SeededPond();
  @override
  ReactionLevel generate(int level, {int? seed}) =>
      super.generate(level, seed: 17);
}

class _SeededFirefly extends PrindeLicuriciulGame {
  const _SeededFirefly();
  @override
  ReactionLevel generate(int level, {int? seed}) =>
      super.generate(level, seed: 17);
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  ReactionGame game, {
  Size size = const Size(960, 540),
  bool off = true,
  int initialLevel = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
  );
  for (var i = 1; i < initialLevel; i++) {
    container.read(reactionLevelProvider(game.id).notifier).advance();
  }
  final router = GoRouter(
    initialLocation: '/reactie/${game.id}',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Acasă')),
      ),
      GoRoute(
        path: '/reactie/:id',
        builder: (_, _) => ReactionGameScreen(game: game),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildTheme(calm: false),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: off),
          child: child!,
        ),
      ),
    ),
  );
  await pumpUntil(tester, find.text('Începem'));
  return container;
}

Future<void> _begin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Începem'));
  await tester.tap(find.text('Începem'));
  await tester.pump();
}

Future<void> _play(
  WidgetTester tester,
  ReactionLevel level, {
  bool tapFirst = false,
  bool tapNoGo = false,
  bool tapGo = false,
}) async {
  for (final stimulus in level.stimuli) {
    await tester.pump(Duration(milliseconds: stimulus.gapBeforeMs));
    final target = find.byKey(ValueKey('reaction-stimulus-${stimulus.index}'));
    expect(target, findsOneWidget);
    expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(64));
    if ((tapFirst && stimulus.index == 0) ||
        (tapNoGo && !stimulus.isGo) ||
        (tapGo && stimulus.isGo)) {
      await tester.tap(target);
      await tester.pump();
    }
    await tester.pump(Duration(milliseconds: stimulus.visibleMs));
  }
  await tester.pump();
}

void main() {
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final game in const [_SeededPond(), _SeededFirefly()]) {
    testWidgets(
      '${game.id}: se deschide și un nivel fără mișcare ajunge la final',
      (tester) async {
        await _open(tester, game, size: const Size(640, 360));
        expect(find.text(game.name), findsOneWidget);
        expect(find.text('Da, atinge'), findsOneWidget);
        expect(
          find.text('Nu atinge'),
          game is PescarulGame ? findsOneWidget : findsNothing,
        );
        await _begin(tester);
        await _play(tester, game.generate(1));
        expect(findFinish(), findsOneWidget);
        expect(find.text('Încă o dată'), findsOneWidget);
        expect(find.text('Mai departe'), findsOneWidget);
        expect(
          tester
              .widget<ReactionFinish>(find.byType(ReactionFinish))
              .summary
              .hits,
          0,
        );
        expect(
          tester
              .widgetList<StarBurst>(find.byType(StarBurst))
              .every((b) => !b.enabled),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await closeApp(tester);
      },
    );
  }

  testWidgets(
    'prima atingere go este un singur hit, no-go este comisie, golul este numărat',
    (tester) async {
      const game = _SeededPond();
      await _open(tester, game);
      await _begin(tester);
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('reaction-field'))) +
            const Offset(8, 8),
      );
      await _play(tester, game.generate(1), tapFirst: true, tapNoGo: true);
      final result = tester
          .widget<ReactionFinish>(find.byType(ReactionFinish))
          .summary;
      expect(result.hits, 1);
      expect(
        result.commissions,
        game.generate(1).stimuli.where((s) => !s.isGo).length,
      );
      expect(result.offTargetTaps, 1);
      expect(result.reactionTimes, hasLength(1));
      expect(result.medianRtMs, greaterThanOrEqualTo(0));
      await closeApp(tester);
    },
  );

  testWidgets(
    'repetare și avansare păstrează nivelul separat pentru fiecare joc',
    (tester) async {
      const game = _SeededFirefly();
      final container = await _open(tester, game, initialLevel: 5);
      await _begin(tester);
      await _play(tester, game.generate(5));
      await tester.tap(find.text('Încă o dată'));
      await pumpUntil(tester, find.text('Începem'));
      expect(container.read(reactionLevelProvider(game.id)), 5);
      await _begin(tester);
      await _play(tester, game.generate(5));
      await tester.tap(find.text('Mai departe'));
      await pumpUntil(tester, find.text('Începem'));
      expect(container.read(reactionLevelProvider(game.id)), 4);
      await _begin(tester);
      await _play(tester, game.generate(4), tapGo: true);
      await tester.tap(find.text('Mai departe'));
      await pumpUntil(tester, find.text('Începem'));
      expect(container.read(reactionLevelProvider(game.id)), 6);
      expect(container.read(reactionLevelProvider('pescarul')), 1);
      await closeApp(tester);
    },
  );

  testWidgets(
    'pauza și trecerea în fundal opresc secvența; ieșirea anulează timerele',
    (tester) async {
      const game = _SeededPond();
      await _open(tester, game);
      await _begin(tester);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.tap(find.byTooltip('Pauză'));
      await tester.pump(const Duration(minutes: 2));
      expect(find.byType(ReactionFinish), findsNothing);
      await tester.tap(find.text('Continuă'));
      await tester.pump();
      expect(find.byKey(const ValueKey('reaction-stimulus-0')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Continuă'), findsOneWidget);
      await tester.tap(find.byTooltip('Acasă'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ReactionGameScreen), findsNothing);
      await closeApp(tester);
    },
  );

  testWidgets('ruta necunoscută redirecționează acasă', (tester) async {
    final container = ProviderContainer(
      overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    router.go('/reactie/inexistent');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(ReactionGameScreen), findsNothing);
    await closeApp(tester);
  });

  testWidgets('licuriciul zboară de la primul nivel, apoi se stinge dacă nu e prins', (
    tester,
  ) async {
    const game = _SeededFirefly();
    await _open(tester, game, off: false);
    await _begin(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final target = find.byKey(const ValueKey('reaction-stimulus-0'));
    await tester.pump(const Duration(milliseconds: 16));
    final start = tester.getCenter(target);
    await tester.pump(const Duration(milliseconds: 400));
    final later = tester.getCenter(target);
    expect(later.dx, isNot(start.dx));
    expect(later.dy, isNot(start.dy));
    // Spre final zboară în sus și se estompează.
    final visible = game.generate(1).stimuli.first.visibleMs;
    await tester.pump(Duration(milliseconds: visible - 16 - 400 - 100));
    final fading = tester
        .widgetList<Opacity>(
          find.descendant(of: target, matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity)
        .reduce((a, b) => a * b);
    expect(fading, lessThan(0.5));
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });

  testWidgets('drift și particule în modul complet; modul calm le oprește', (
    tester,
  ) async {
    const game = _SeededFirefly();
    final container = await _open(tester, game, off: false, initialLevel: 6);
    await _begin(tester);
    await tester.pump(const Duration(milliseconds: 1200));
    final target = find.byKey(const ValueKey('reaction-stimulus-0'));
    // Primul tic al animației doar îi fixează începutul; abia următoarele o mișcă.
    await tester.pump(const Duration(milliseconds: 16));
    final start = tester.getCenter(target);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getCenter(target).dx, isNot(start.dx));
    await tester.tap(target);
    await tester.pump();
    expect(find.byType(StarBurst), findsOneWidget);
    container.read(settingsProvider.notifier).toggleCalm();
    await tester.pump();
    expect(find.byType(StarBurst), findsNothing);
    await closeApp(tester);
  });
}
