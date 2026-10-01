import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const simon = SimonGame();

  test('reproductibil din seed', () {
    expect(simon.generate(9, seed: 5).sequence, simon.generate(9, seed: 5).sequence);
  });

  test('axele cresc monoton, sunt sigure (≤ ~1,3 aprinderi/s) și se plafonează', () {
    SequenceAxes? prev;
    for (var level = 1; level <= 60; level++) {
      final a = simon.axesFor(level);
      expect(a.pads, inInclusiveRange(3, 6));
      expect(a.length, inInclusiveRange(2, 7));
      expect(a.onMs + a.gapMs, greaterThanOrEqualTo(750));
      if (prev != null) {
        expect(a.length, greaterThanOrEqualTo(prev.length));
        expect(a.pads, greaterThanOrEqualTo(prev.pads));
        expect(a.onMs, lessThanOrEqualTo(prev.onMs));
      }
      prev = a;
    }
    expect(simon.axesFor(400).toJson(), simon.axesFor(60).toJson());
  });

  test('secvențele folosesc doar felinarele de pe ecran; fără repetări imediate la span mic', () {
    for (var level = 1; level <= 30; level++) {
      for (var seed = 0; seed < 50; seed++) {
        final l = simon.generate(level, seed: seed);
        expect(l.sequence, hasLength(l.axes.length));
        expect(l.pads, hasLength(l.axes.pads));
        expect(l.sequence.every((i) => i >= 0 && i < l.axes.pads), isTrue);
        if (l.axes.length <= 4) {
          for (var i = 1; i < l.sequence.length; i++) {
            expect(l.sequence[i], isNot(l.sequence[i - 1]));
          }
        }
      }
    }
  });

  test('ordinea inversă de la nivelul 19', () {
    final l = simon.generate(20, seed: 1);
    expect(l.axes.reverse, isTrue);
    expect(l.expected, l.sequence.reversed.toList());
    expect(simon.generate(5, seed: 1).axes.reverse, isFalse);
  });

  test('scorul: prefix corect și nivelul următor', () {
    final l = simon.generate(10, seed: 2);
    expect(SequenceResult(l, l.expected).complete, isTrue);
    expect(SequenceResult(l, l.expected).suggestedNextLevel(10), 11);
    final wrongFirst = (l.expected.first + 1) % l.axes.pads;
    final early = SequenceResult(l, [wrongFirst]);
    expect(early.correctPrefix, 0);
    expect(early.suggestedNextLevel(10), 9);
    expect(SequenceResult(l, const []).suggestedNextLevel(1), 1);
  });
}
