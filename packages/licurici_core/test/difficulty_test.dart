import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  group('Difficulty — paritate cu difficulty.js', () {
    // [tier, optionCount, roundCount, numMax()] calculate cu formulele din prototipul JS.
    const reference = [
      [1, 2, 5, 13],
      [2, 3, 5, 21],
      [3, 3, 6, 29],
      [4, 4, 6, 37],
      [5, 4, 7, 45],
      [6, 5, 7, 53],
      [7, 5, 8, 61],
      [8, 5, 8, 69],
      [9, 5, 8, 77],
      [10, 5, 8, 85],
      [11, 5, 8, 93],
      [12, 5, 8, 100],
    ];

    for (final [tier, options, rounds, numMax] in reference) {
      test('tier $tier', () {
        final d = Difficulty(tier);
        expect(d.optionCount, options);
        expect(d.distractors, options - 1);
        expect(d.roundCount, rounds);
        expect(d.numMax(), numMax);
      });
    }

    test('tier foarte mare rămâne plafonat', () {
      final d = Difficulty(1000);
      expect(d.optionCount, 5);
      expect(d.roundCount, 8);
      expect(d.numMax(cap: 20), 20);
    });
  });

  group('Difficulty — surse de tier', () {
    test('joc liber: tier din clasă, +1 pentru mediu', () {
      expect(Difficulty.freePlay(Grade.gradinita).tier, 1);
      expect(Difficulty.freePlay(Grade.clasa4).tier, 5);
      expect(Difficulty.freePlay(Grade.clasa2, FreePlayLevel.mediu).tier, 4);
    });

    test('aventură: +1 tier la fiecare 4 niveluri, nemărginit', () {
      expect(Difficulty.adventure(1).tier, 1);
      expect(Difficulty.adventure(4).tier, 1);
      expect(Difficulty.adventure(5).tier, 2);
      expect(Difficulty.adventure(401).tier, 101);
      expect(() => Difficulty.adventure(0), throwsArgumentError);
    });

    test('easier nu coboară sub 1', () {
      expect(const Difficulty(1).easier().tier, 1);
      expect(const Difficulty(3).easier().tier, 2);
    });
  });

  group('Grade', () {
    test('parseCodes', () {
      expect(Grade.parseCodes('G12'), {Grade.gradinita, Grade.clasa1, Grade.clasa2});
      expect(() => Grade.parseCodes('9'), throwsArgumentError);
    });
  });
}
