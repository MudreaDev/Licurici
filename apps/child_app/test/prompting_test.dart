import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/features/games/choice/choice_game_screen.dart';
import 'package:licurici/features/therapy/trial_log.dart';
import 'package:licurici/shared/role_fx.dart';
import 'package:licurici/shared/voice.dart';
import 'package:licurici_core/licurici_core.dart';

/// Un joc de test: [rounds] runde identice, corectul pe poziția 1, 4 variante.
class FakeGame extends ChoiceGame {
  const FakeGame({this.stepId})
    : super(
        id: 'test',
        name: 'Test',
        emoji: '🧩',
        description: '',
        subject: Subject.forme,
        gradeCodes: 'G1234',
      );

  /// Cu treaptă = rundă generată pe modelul nou (strategie implicită: mult → puțin).
  final String? stepId;

  @override
  Lesson generate(GameContext ctx) => Lesson(
    title: name,
    rounds: [
      for (var i = 0; i < 4; i++)
        ChoiceRound(
          prompt: 'Găsește obiectul la fel.',
          visuals: const [EmojiVisual('🍎')],
          hint: 'Uită-te bine la model.',
          fixedChoices: true,
          choices: const [
            Choice(art: '🐶'),
            Choice(art: '🍎', correct: true),
            Choice(art: '🚗'),
            Choice(art: '🌷'),
          ],
          tag: stepId == null
              ? null
              : RoundTag(
                  generator: 'test',
                  version: 1,
                  seed: 42 + i,
                  stepId: stepId,
                  axes: const {'variante': 4, 'asemanare': 0},
                  difficulty: 900,
                  stimulusId: '🍎',
                  stimulusSet: 'fructe',
                ),
        ),
    ],
  );
}

Future<void> pumpGame(WidgetTester tester, GameSpec game) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {})),
      ],
      child: MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          size: Size(1280, 800),
        ),
        child: MaterialApp.router(
          theme: buildTheme(calm: false),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ChoiceGameScreen(game: game),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // pre-încărcarea ilustrațiilor e asincronă (reală)
  for (
    var i = 0;
    i < 100 && find.byKey(const ValueKey('choice-0')).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

FxRole roleOf(WidgetTester tester, int i) => tester
    .widget<RoleFx>(
      find.descendant(
        of: find.byKey(ValueKey('choice-$i')),
        matching: find.byType(RoleFx),
      ),
    )
    .role;

TrialLogState log(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ChoiceGameScreen)),
).read(trialLogProvider);

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  testWidgets(
    'treaptă nouă: mâna arată răspunsul (P4), apoi ajutorul se estompează',
    (tester) async {
      await pumpGame(tester, const FakeGame(stepId: 'POT1'));
      expect(find.byKey(const ValueKey('model-hand')), findsOneWidget);
      expect(roleOf(tester, 1), FxRole.modeled);

      // două reușite cu P4 → a treia rundă pornește cu P3 (pulsare, fără mână)
      for (var round = 0; round < 2; round++) {
        await tester.tap(find.byKey(const ValueKey('choice-1')));
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byKey(const ValueKey('model-hand')), findsNothing);
      expect(roleOf(tester, 1), FxRole.hinted);

      final trials = log(tester).trials;
      expect(trials, hasLength(2));
      expect(trials.first.stepId, 'POT1');
      expect(trials.first.promptLevel, PromptLevel.p4);
      expect(trials.first.independent, isFalse);
      expect(trials.first.seed, 42);
      expect(trials.first.axes, {'variante': 4.0, 'asemanare': 0.0});
      expect(trials.first.stimulusSet, 'fructe');
      expect(trials.first.sessionId, trials.last.sessionId);
      // o reușită cu model complet nu urcă rating-ul
      expect(log(tester).ratingOf('POT1').value, lessThanOrEqualTo(1000));
      await close(tester);
    },
  );

  testWidgets(
    'joc liber: fără ajutor la început; pauza aduce indiciul, greșelile îl cresc',
    (tester) async {
      await pumpGame(tester, const FakeGame());
      expect(roleOf(tester, 1), FxRole.target);
      expect(find.text('Uită-te bine la model.'), findsNothing);

      // P1 după 5 s fără răspuns: indiciul neutru
      await tester.pump(const Duration(milliseconds: 5300));
      expect(find.text('Uită-te bine la model.'), findsOneWidget);
      expect(roleOf(tester, 3), FxRole.target);

      // o greșeală → P2: rămâne un singur distractor activ, restul se estompează
      await tester.tap(find.byKey(const ValueKey('choice-0')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(roleOf(tester, 0), FxRole.rejected);
      expect(roleOf(tester, 2), FxRole.target);
      expect(roleOf(tester, 3), FxRole.faded);

      // varianta estompată nu se mai poate atinge
      await tester.tap(
        find.byKey(const ValueKey('choice-3')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(roleOf(tester, 3), FxRole.faded);

      await tester.tap(find.byKey(const ValueKey('choice-1')));
      await tester.pump(const Duration(milliseconds: 100));
      final t = log(tester).trials.single;
      expect(t.stepId, 'test');
      expect(t.correct, isFalse);
      expect(t.attempts, 2);
      expect(t.promptLevel, PromptLevel.p2);
      expect(t.latencyMs, greaterThanOrEqualTo(5000));
      expect(t.seed, isNull);
      expect(log(tester).ratings, isEmpty);
      await close(tester);
    },
  );

  testWidgets('răspuns independent: P0, din prima, rating-ul crește', (
    tester,
  ) async {
    await pumpGame(tester, const FakeGame());
    await tester.tap(find.byKey(const ValueKey('choice-1')));
    await tester.pump(const Duration(milliseconds: 100));
    final t = log(tester).trials.single;
    expect(t.independent, isTrue);
    expect(t.latencyMs, lessThan(1000));
    await close(tester);
  });
}
