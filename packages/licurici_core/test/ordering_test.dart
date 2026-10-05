import 'dart:io';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

String _openMoji(String emoji) => emoji.runes
    .where((cp) => cp != 0xFE0F)
    .map((cp) => cp.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

void main() {
  for (final game in orderGames) {
    group(game.id, () {
      test('pașii rămân în ordinea poveștii; cartonașele nu apar deja în ordine', () {
        for (var level = 1; level <= 12; level++) {
          for (var seed = 0; seed < 30; seed++) {
            final l = game.generate(level, seed: seed);
            expect(l.rounds, hasLength(game.roundsFor(level)));
            for (final r in l.rounds) {
              final positions = [for (final s in r.steps) r.story.steps.indexOf(s)];
              expect(positions, orderedEquals([...positions]..sort()));
              expect(r.steps.first, r.story.steps.first);
              if (!game.sentence) expect(r.steps.last, r.story.steps.last);
              expect(r.steps.length, lessThanOrEqualTo(game.stepsFor(level)));
              expect(r.shuffled.toSet(), {for (var i = 0; i < r.steps.length; i++) i});
              expect(r.shuffled, isNot(orderedEquals([for (var i = 0; i < r.steps.length; i++) i])));
              // Fără două poze la fel în aceeași rundă (ar fi ambiguu).
              expect(r.steps.map((s) => '${s.emoji}${s.scale}').toSet(), hasLength(r.steps.length));
            }
          }
        }
      });

      test('nivelul 1 = „întâi … apoi …”; crește până la 5 pași', () {
        expect(game.stepsFor(1), 2);
        expect(game.stepsFor(3), 3);
        expect(game.stepsFor(40), game.sentence ? 3 : 5);
      });

      test('toate pozele au SVG OpenMoji', () {
        for (final s in game.stories) {
          for (final step in s.steps) {
            expect(
              File('../game_content/art/openmoji/${_openMoji(step.emoji)}.svg').existsSync(),
              isTrue,
              reason: '${s.id}: ${step.emoji}',
            );
          }
        }
      });
    });
  }

  test('spune propoziția: cuvintele în ordinea propoziției; capcanele nu sunt în șir', () {
    const g = OrderGame.sentences;
    for (var level = 1; level <= 9; level++) {
      for (var seed = 0; seed < 30; seed++) {
        for (final r in g.generate(level, seed: seed).rounds) {
          expect(r.steps, r.story.steps.take(r.steps.length).toList());
          expect(r.distractors, hasLength(g.distractorsFor(level)));
          for (final d in r.distractors) {
            expect(r.steps.contains(d), isFalse);
          }
          expect(r.tray.toSet(), {for (var i = 0; i < r.steps.length + r.distractors.length; i++) i});
        }
      }
    }
    expect(orderSentence(sentenceStories[1].steps), 'Fetița mănâncă cu lingura.');
    expect(catalogEntry('spune-propozitia')!.domain, Domain.com);
  });

  test('mare și mic: același obiect, mărimi crescătoare', () {
    for (var seed = 0; seed < 30; seed++) {
      for (final r in OrderGame.sizes.generate(7, seed: seed).rounds) {
        expect(r.steps.map((s) => s.emoji).toSet(), hasLength(1));
        for (var i = 1; i < r.steps.length; i++) {
          expect(r.steps[i].scale, greaterThan(r.steps[i - 1].scale));
        }
      }
    }
    expect(catalogEntry('mare-mic')!.domain, Domain.cog);
  });

  test('înregistrarea și catalogul', () {
    final level = OrderGame.routine.generate(1, seed: 1);
    final res = OrderResult(level, [
      OrderAttempt(level.rounds[0]),
      OrderAttempt(level.rounds[1], wrongTaps: 2, firstWrong: 'b', expected: 'a', hinted: true),
    ]);
    expect(res.accuracy, 0.5);
    final rec = SessionRecorder(childId: 'c')..orderLevel(res);
    expect(rec.trials.first.stepId, 'AUT1');
    expect(rec.trials.last.promptLevel, PromptLevel.p3);
    expect(rec.trials.last.chosenId, 'b');
    expect(catalogEntry('pasii-rutinei')!.domain, Domain.aut);
    expect(catalogEntry('ce-urmeaza')!.domain, Domain.cog);
    expect(catalogEntry('ce-urmeaza')!.route, '/ordine/ce-urmeaza');
  });
}
