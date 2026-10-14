import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _build(ChoiceGame g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed)));

void main() {
  test('Cât de tare?: corectă e fața cea mai puternică; diferența scade cu tier-ul', () {
    expect(CatDeTareGame.gapFor(1), greaterThan(CatDeTareGame.gapFor(7)));
    expect(CatDeTareGame.gapFor(7), closeTo(0.1, 1e-9));
    for (var tier = 1; tier <= 8; tier++) {
      for (var seed = 0; seed < 20; seed++) {
        for (final r in _build(const CatDeTareGame(), tier, seed).rounds) {
          final faces = [for (final c in r.choices) (FaceSpec.parse(c.art!)!, c.correct)];
          // Aceeași persoană, aceeași emoție; doar intensitatea diferă.
          expect({for (final (f, _) in faces) f.look.code}, hasLength(1));
          expect({for (final (f, _) in faces) f.emotion}, hasLength(1));
          final best = faces.reduce((a, b) => a.$1.intensity >= b.$1.intensity ? a : b);
          expect(best.$2, isTrue);
          expect(faces.where((f) => f.$2), hasLength(1));
          if (tier < 3) expect([FaceEmotion.bucuros, FaceEmotion.trist], contains(faces.first.$1.emotion));
        }
      }
    }
  });

  test('Cine e prietenul?: prietenul e aceeași persoană (altă expresie); ceilalți seamănă tot mai mult', () {
    for (var tier = 1; tier <= 8; tier++) {
      for (var seed = 0; seed < 20; seed++) {
        for (final r in _build(const CineEPrietenulGame(), tier, seed).rounds) {
          final shown = FaceSpec.parse((r.visuals.single as EmojiVisual).emoji)!;
          final right = FaceSpec.parse(r.choices.singleWhere((c) => c.correct).art!)!;
          expect(right.look, shown.look);
          expect(right.emotion, isNot(shown.emotion), reason: 'altă expresie decât în poză');
          for (final c in r.choices.where((c) => !c.correct)) {
            final o = FaceSpec.parse(c.art!)!;
            expect(o.emotion, right.emotion, reason: 'toți au aceeași expresie');
            expect(o.look.differences(shown.look), greaterThanOrEqualTo(CineEPrietenulGame.minDifferencesFor(tier)));
          }
        }
      }
    }
    expect(CineEPrietenulGame.minDifferencesFor(1), greaterThan(CineEPrietenulGame.minDifferencesFor(7)));
  });

  test('ambele jocuri sunt în catalog, pe treapta EMO2', () {
    for (final id in ['cat-de-tare', 'cine-e-prietenul']) {
      expect(catalogEntry(id)!.domain, Domain.emo);
      expect(stepsForGame(id).map((s) => s.id), contains('EMO2'));
    }
  });
}
