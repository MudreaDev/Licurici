import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/main.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici/shared/voice.dart';

/// Pornește aplicația fără voce și cu „reduce motion” (animații deterministe).
Future<void> pumpApp(WidgetTester tester, {SessionStore? store}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
        sessionStoreProvider.overrideWithValue(store ?? MemorySessionStore()),
      ],
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true, size: Size(1280, 900)),
        child: LicuriciApp(),
      ),
    ),
  );
  // Ecranul de pornire pre-încarcă resursele, apoi dispare.
  expect(find.text('Se pregătesc jocurile…'), findsOneWidget);
  await pumpUntil(tester, find.text('Atenție'));
  await tester.pump(
    const Duration(milliseconds: 600),
  ); // estomparea ecranului de pornire
  expect(find.text('Se pregătesc jocurile…'), findsNothing);
}

/// Avansează timpul până apare [finder] (maxim ~10 s de timp simulat).
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets, reason: 'nu a apărut: $finder');
}

/// Derulează lista ariilor până la [code] și o deschide (lista e leneșă și orizontală).
Future<void> openDomain(WidgetTester tester, String code) async {
  final card = find.byKey(ValueKey('domain-$code'));
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(card);
}

/// Închide aplicația și lasă timerele rămase (animații cu întârziere) să expire.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  // Cache-urile globale (asset-uri, SVG) păstrează promisiuni create în zona de timp simulat a
  // testului anterior; în testul următor ele nu s-ar mai finaliza. Pornim fiecare test curat.
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  testWidgets('ecranul principal: jocurile pe arii de dezvoltare, fără clase', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Grădiniță'), findsNothing); // clasa e doar la părinte
    expect(find.byKey(const ValueKey('domain-ATN')), findsOneWidget);
    expect(find.byKey(const ValueKey('domain-ATN')), findsOneWidget);

    // Atingerea unei arii deschide doar jocurile ei.
    await openDomain(tester, 'POT');
    await pumpUntil(tester, find.byKey(const ValueKey('game-culori')));
    expect(find.byKey(const ValueKey('game-forme')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-adunam')), findsNothing);
    await closeApp(tester);
  });

  testWidgets('un joc se poate juca până la final, iar greșelile nu blochează', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await pumpApp(tester, store: store);
    await openDomain(tester, 'POT');
    await pumpUntil(tester, find.byKey(const ValueKey('game-culori')));
    await tester.tap(find.byKey(const ValueKey('game-culori')));
    await pumpUntil(tester, find.byKey(const ValueKey('mood-skip')));
    await tester.tap(find.byKey(const ValueKey('mood-skip')));
    await pumpUntil(tester, find.byKey(const ValueKey('choice-0')));

    for (
      var round = 0;
      round < 10 && find.text('Încă o dată').evaluate().isEmpty;
      round++
    ) {
      // Atinge variantele pe rând: greșelile doar se estompează, deci ajungem la corect.
      for (var i = 0; i < 5 && find.text('Bravo!').evaluate().isEmpty; i++) {
        final option = find.byKey(ValueKey('choice-$i'));
        if (option.evaluate().isEmpty) break;
        await tester.tap(option, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('Bravo!'),
        findsWidgets,
        reason: 'runda $round nu s-a rezolvat',
      );
      await tester.pump(
        const Duration(milliseconds: 1500),
      ); // trecerea la runda următoare
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(find.text('Încă o dată'), findsOneWidget);
    await tester.tap(find.text('Acasă').last);
    await pumpUntil(tester, find.text('Atenție'));

    // „Gata pe azi” → dispoziția de final → sesiunea se salvează cu toate rundele jucate.
    await tester.tap(find.byKey(const ValueKey('finish-session')));
    await pumpUntil(tester, find.byKey(const ValueKey('mood-linistit')));
    await tester.tap(find.byKey(const ValueKey('mood-linistit')));
    await tester.pump(const Duration(milliseconds: 300));
    final saved = (await tester.runAsync(store.all))!;
    expect(saved, hasLength(1));
    final session = saved.single;
    expect(session.moodBefore, isNull); // a sărit peste întrebare
    expect(session.moodAfter, Mood.linistit);
    expect(session.trials, isNotEmpty);
    expect(
      session.trials.every((t) => t.gameId == 'culori' && t.stepId == 'POT5'),
      isTrue,
    );
    expect(
      session.trials.every((t) => t.latencyMs != null && t.targetId != null),
      isTrue,
    );
    // Raportul pentru părinte se poate calcula direct din ce s-a salvat.
    expect(SessionReport.from(session).parentSummary, isNotEmpty);
    expect(find.byKey(const ValueKey('finish-session')), findsNothing);
    await closeApp(tester);
  });

  testWidgets('fără răspuns: ținta pulsează, apoi mânuța o arată (P4)', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await pumpApp(tester, store: store);
    await openDomain(tester, 'POT');
    await pumpUntil(tester, find.byKey(const ValueKey('game-culori')));
    await tester.tap(find.byKey(const ValueKey('game-culori')));
    await pumpUntil(tester, find.byKey(const ValueKey('mood-skip')));
    await tester.tap(find.byKey(const ValueKey('mood-skip')));
    await pumpUntil(tester, find.byKey(const ValueKey('choice-0')));

    expect(find.byType(PointingHand), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // pulsează (P3)
    expect(find.byType(PointingHand), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // mânuța (P4)
    expect(find.byType(PointingHand), findsOneWidget);

    // Mânuța stă pe răspunsul corect: îl atingem.
    final correct = find.ancestor(
      of: find.byType(PointingHand),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('choice-'),
      ),
    );
    await tester.tap(correct.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Bravo!'), findsWidgets);
    expect(find.byType(PointingHand), findsNothing);
    await closeApp(tester);
  });

  testWidgets(
    'colțul părintelui: poarta pentru adulți, apoi rezumatul sesiunilor salvate',
    (tester) async {
      final store = MemorySessionStore();
      final demo = demoChildren().first.sessions.last;
      await tester.runAsync(
        () => store.save(
          SessionRecord.fromJson({...demo.toJson(), 'childId': localChildId}),
        ),
      );
      await pumpApp(tester, store: store);

      // Răspuns greșit → rămâne pe ecranul principal.
      await tester.tap(find.byKey(const ValueKey('parent-corner')));
      await pumpUntil(tester, find.text('Pentru adulți'));
      const words = {'șase': 6, 'șapte': 7, 'opt': 8, 'nouă': 9};
      int answer() {
        final q = tester
            .widgetList<Text>(find.textContaining('Cât fac'))
            .single
            .data!
            .replaceAll('?', '')
            .split(' ');
        return words[q[2]]! * words[q[4]]!;
      }

      final wrong = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('gate-') &&
            (w.key! as ValueKey<String>).value != 'gate-${answer()}',
      );
      await tester.tap(wrong.first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Atenție'), findsOneWidget);

      // Răspuns corect → rezumatul pentru părinte.
      await tester.tap(find.byKey(const ValueKey('parent-corner')));
      await pumpUntil(tester, find.text('Pentru adulți'));
      await tester.tap(find.byKey(ValueKey('gate-${answer()}')));
      await pumpUntil(tester, find.byKey(ValueKey('session-${demo.id}')));
      // Singura sesiune salvată → raportul fără comparație, exact cel calculat de core.
      expect(find.text(SessionReport.from(demo).parentSummary), findsOneWidget);
      expect(find.text('Detalii pentru specialist'), findsOneWidget);
      // Clasa a devenit „nivel de pornire”, doar aici.
      expect(
        find.byKey(const ValueKey('start-level-gradinita')),
        findsOneWidget,
      );
      await closeApp(tester);
    },
  );
}
