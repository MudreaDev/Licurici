import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Lesson _lesson(GameSpec g, int tier, int seed) =>
    g.build(GameContext(difficulty: Difficulty(tier), grade: Grade.clasa1, random: Random(seed)));

void main() {
  group('Cum se simte? (EMO3)', () {
    const g = CumSeSimteGame();

    test('variantele: aceeași persoană, emoții diferite, una singură potrivită întâmplării', () {
      for (final tier in [1, 3, 6]) {
        for (var seed = 0; seed < 20; seed++) {
          for (final r in _lesson(g, tier, seed).rounds) {
            final faces = [for (final c in r.choices) FaceSpec.parse(c.art!)!];
            expect(faces.map((f) => f.look.code).toSet(), hasLength(1), reason: 'aceeași persoană');
            expect(faces.map((f) => f.emotion).toSet(), hasLength(faces.length), reason: 'emoții diferite');
            expect(r.choices.where((c) => c.correct), hasLength(1));
          }
        }
      }
    });

    test('la tier mare, expresiile sunt mai discrete (pragul de recunoaștere)', () {
      double intensity(int tier) => FaceSpec.parse(_lesson(g, tier, 1).rounds.first.choices.first.art!)!.intensity;
      expect(intensity(1), greaterThan(intensity(6)));
      expect(intensity(9), greaterThanOrEqualTo(0.6));
    });
  });

  group('Ajută-l pe Licurici (AUT1–2)', () {
    const g = AjutaLicuriciGame();

    test('răspunsul bun e pasul următor al rutinei; șirul arată pașii deja făcuți', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final r in _lesson(g, 2, seed).rounds) {
          final done = (r.visuals.single as PatternVisual).items;
          final right = r.choices.singleWhere((c) => c.correct).art!;
          final story = routineStories.firstWhere((s) => s.steps.any((x) => x.emoji == right) && s.steps.first.emoji == done.first);
          final k = done.length;
          expect([for (final s in story.steps.take(k)) s.emoji], done);
          expect(story.steps[k].emoji, right);
          expect(r.choices.map((c) => c.art).toSet(), hasLength(r.choices.length));
        }
      }
    });

    test('tier mic: greșelile din alte rutine; tier 4+: din aceeași rutină, unde se poate', () {
      int sameRoutineWrong(int tier) {
        var n = 0;
        for (var seed = 0; seed < 10; seed++) {
          for (final r in _lesson(g, tier, seed).rounds) {
            final done = (r.visuals.single as PatternVisual).items;
            final story = routineStories.firstWhere((s) => s.steps.first.emoji == done.first);
            n += r.choices.where((c) => !c.correct && story.steps.any((s) => s.emoji == c.art)).length;
          }
        }
        return n;
      }

      expect(sameRoutineWrong(5), greaterThan(sameRoutineWrong(1)));
    });
  });

  test('ambele sunt legate de treptele lor', () {
    expect(stepsForGame('cum-se-simte').map((s) => s.id), ['EMO3']);
    expect(stepsForGame('ajuta-l-pe-licurici').map((s) => s.id), ['AUT1', 'AUT2']);
  });
}
