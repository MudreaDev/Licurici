import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/fitts/fitts_screen.dart';
import 'package:licurici/features/games/number_line/number_line_screen.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

import 'layout_test.dart' show devices, loadFonts, settle, shots;
import 'praise_finders.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String device, Widget screen, [void Function(ProviderContainer)? setup]) async {
  tester.view.physicalSize = devices[device]!;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [voiceProvider.overrideWithValue(const SilentSpeaker())]);
  addTearDown(container.dispose);
  setup?.call(container);
  final router = GoRouter(
    initialLocation: '/j',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
      GoRoute(path: '/j', builder: (_, _) => screen),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router),
    ),
  );
  await settle(tester, 3);
  return container;
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  for (final (device, level) in [('telefon-mic', 7), ('tableta', 2)]) {
    testWidgets('linia numerelor: nivelul $level pe $device, jucat până la final', (tester) async {
      final c2 = await _pump(
        tester,
        device,
        const NumberLineScreen(seed: 4),
        (c) => c.read(numberLineLevelProvider.notifier).setLevel(level),
      );
      final lineMax = const NumberLineGame().axesFor(level).max;
      if (shots) await expectLater(find.byType(NumberLineScreen), matchesGoldenFile('shots/linia-numerelor-$device.png'));
      final line = find.byKey(const ValueKey('nl-line'));
      for (var i = 0; i < 12 && find.text('Încă o dată').evaluate().isEmpty; i++) {
        // Atinge exact locul numărului afișat (după poziția lui pe linie).
        final shown = int.parse(tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('nl-number')), matching: find.byType(Text))).data!);
        final r = tester.getRect(line);
        final pad = device == 'telefon-mic' ? 28.0 : 40.0;
        await tester.tapAt(Offset(r.left + pad + (r.width - pad * 2) * shown / lineMax, r.center.dy));
        await tester.pump(const Duration(milliseconds: 300));
        if (i == 0) expect(findPraise(), findsNothing); // lauda e doar în voce
        await settle(tester, 12);
      }
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = c2.read(sessionProvider)!.trials;
      expect(trials.where((t) => t.gameId == 'linia-numerelor'), isNotEmpty);
      expect(trials.where((t) => t.gameId == 'linia-numerelor').every((t) => t.correct), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }

  for (final device in ['telefon-mic', 'tableta']) {
    testWidgets('atinge rapid: toate bulele, pe $device', (tester) async {
      final container = await _pump(tester, device, const FittsScreen(seed: 2));
      if (shots) await expectLater(find.byType(FittsScreen), matchesGoldenFile('shots/atinge-rapid-$device.png'));
      final field = find.byKey(const ValueKey('fitts-field'));
      // O atingere pe lângă, pe colțul terenului: nu strică nimic.
      await tester.tapAt(tester.getTopLeft(field) + const Offset(2, 2));
      for (var i = 0; i <= FittsGame.count; i++) {
        final bubble = find.byWidgetPredicate((w) => w is Positioned && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value == 'fitts-target-$i');
        expect(bubble, findsOneWidget, reason: 'bula $i');
        await tester.tapAt(tester.getCenter(bubble));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await settle(tester, 3);
      expect(find.text('Încă o dată'), findsOneWidget);
      final trials = container.read(sessionProvider)!.trials.where((t) => t.gameId == 'atinge-rapid').toList();
      expect(trials, hasLength(FittsGame.count));
      expect(trials.every((t) => (t.difficulty ?? 0) > 0), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
